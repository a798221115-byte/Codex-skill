param(
  [ValidateSet("Status", "Backup", "Restore")]
  [string]$Mode = "Status",

  [string]$CodexHome,
  [string]$SkillsRepo = "a798221115-byte/Codex-skill",
  [string]$AgentRepo = "a798221115-byte/Codex-AGENTmd",
  [string]$Branch,

  [switch]$ForceLocal,
  [switch]$ForceRemote
)

$ErrorActionPreference = "Stop"

function Resolve-CodexHome {
  param([string]$Explicit)

  $candidates = @()
  if ($Explicit -and $Explicit.Trim().Length -gt 0) { $candidates += $Explicit }
  if ($env:CODEX_HOME -and $env:CODEX_HOME.Trim().Length -gt 0) { $candidates += $env:CODEX_HOME }
  $candidates += "F:\Codex\.codex"
  $candidates += (Join-Path $HOME ".codex")

  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }

  throw "Could not locate Codex home. Pass -CodexHome or set CODEX_HOME."
}

function ConvertTo-GitHubPath {
  param([string]$Path)
  return (($Path -replace "\\", "/").TrimStart("/"))
}

function ConvertTo-UriPath {
  param([string]$Path)
  return (($Path -split "/") | ForEach-Object { [System.Uri]::EscapeDataString($_) }) -join "/"
}

function Get-LocalBlobSha {
  param([string]$Path)

  $sha = (& git hash-object --no-filters -- $Path 2>$null)
  if ($LASTEXITCODE -ne 0 -or -not $sha) {
    throw "git hash-object failed for $Path. Install git or check the file path."
  }
  return ($sha | Select-Object -First 1).Trim()
}

function Get-GitHubToken {
  $gh = Get-Command gh -ErrorAction SilentlyContinue
  if ($gh) {
    & gh auth status *> $null
    if ($LASTEXITCODE -eq 0) {
      $token = (& gh auth token 2>$null | Select-Object -First 1)
      if ($LASTEXITCODE -eq 0 -and $token) {
        return [pscustomobject]@{ Source = "gh"; Token = $token.Trim() }
      }
    }
  }

  foreach ($name in @("GITHUB_TOKEN", "GH_TOKEN")) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ($value -and $value.Trim().Length -gt 0) {
      return [pscustomobject]@{ Source = $name; Token = $value.Trim() }
    }
  }

  $gcm = Get-Command git-credential-manager -ErrorAction SilentlyContinue
  if (-not $gcm) {
    $gcm = Get-Command "git credential-manager" -ErrorAction SilentlyContinue
  }

  $credentialText = $null
  try {
    $credentialText = "protocol=https`nhost=github.com`n`n" | git credential-manager get 2>$null | Out-String
  } catch {
    $credentialText = $null
  }

  if ($credentialText) {
    $passwordLine = ($credentialText -split "`r?`n") | Where-Object { $_ -like "password=*" } | Select-Object -First 1
    if ($passwordLine) {
      return [pscustomobject]@{ Source = "git-credential-manager"; Token = $passwordLine.Substring(9).Trim() }
    }
  }

  throw "No GitHub credential found. Run gh auth login, set GITHUB_TOKEN, or sign in with Git Credential Manager."
}

function New-GitHubHeaders {
  param([string]$Token)
  return @{
    Authorization = "Bearer $Token"
    Accept = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
    "User-Agent" = "codex-github-sync"
  }
}

function Invoke-GitHubJson {
  param(
    [ValidateSet("GET", "PUT")]
    [string]$Method,
    [string]$Uri,
    [hashtable]$Headers,
    [object]$Body = $null
  )

  if ($null -eq $Body) {
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -TimeoutSec 60
  }

  $json = $Body | ConvertTo-Json -Depth 10
  return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -Body $json -ContentType "application/json; charset=utf-8" -TimeoutSec 90
}

function Get-RepoInfo {
  param([string]$Repo, [hashtable]$Headers)
  return Invoke-GitHubJson -Method GET -Uri "https://api.github.com/repos/$Repo" -Headers $Headers
}

function Get-RemoteTreeMap {
  param(
    [string]$Repo,
    [string]$BranchName,
    [hashtable]$Headers,
    [string]$Prefix
  )

  $map = @{}
  try {
    $refPath = ConvertTo-UriPath "heads/$BranchName"
    $ref = Invoke-GitHubJson -Method GET -Uri "https://api.github.com/repos/$Repo/git/ref/$refPath" -Headers $Headers
    $commit = Invoke-GitHubJson -Method GET -Uri "https://api.github.com/repos/$Repo/git/commits/$($ref.object.sha)" -Headers $Headers
    $tree = Invoke-GitHubJson -Method GET -Uri "https://api.github.com/repos/$Repo/git/trees/$($commit.tree.sha)?recursive=1" -Headers $Headers
  } catch {
    if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
      return $map
    }
    throw
  }

  foreach ($entry in $tree.tree) {
    if ($entry.type -ne "blob") { continue }
    if ($Prefix -and -not $entry.path.StartsWith($Prefix)) { continue }
    $map[$entry.path] = [pscustomobject]@{
      Path = $entry.path
      Sha = $entry.sha
      Size = $entry.size
    }
  }

  return $map
}

function Get-LocalSyncMap {
  param([string]$Root)

  $map = @{}
  $skillsRoot = Join-Path $Root "skills"
  if (Test-Path -LiteralPath $skillsRoot) {
    $skillDirs = Get-ChildItem -LiteralPath $skillsRoot -Force -Directory
    foreach ($skillDir in $skillDirs) {
      $files = Get-ChildItem -LiteralPath $skillDir.FullName -Force -Recurse -File
      foreach ($file in $files) {
        if (Test-ExcludedSkillFile -SkillsRoot $skillsRoot -FilePath $file.FullName) { continue }
        $relative = $file.FullName.Substring($skillsRoot.Length).TrimStart("\", "/")
        $remotePath = "skills/" + (ConvertTo-GitHubPath $relative)
        $map[$remotePath] = [pscustomobject]@{
          Kind = "Skill"
          Repo = $SkillsRepo
          RemotePath = $remotePath
          LocalPath = $file.FullName
          Sha = Get-LocalBlobSha -Path $file.FullName
        }
      }
    }
  }

  $agentsPath = Join-Path $Root "AGENTS.md"
  if (Test-Path -LiteralPath $agentsPath) {
    $map["AGENTS.md"] = [pscustomobject]@{
      Kind = "AGENTS"
      Repo = $AgentRepo
      RemotePath = "AGENTS.md"
      LocalPath = $agentsPath
      Sha = Get-LocalBlobSha -Path $agentsPath
    }
  }

  return $map
}

function Test-ExcludedSkillFile {
  param(
    [string]$SkillsRoot,
    [string]$FilePath
  )

  $relative = $FilePath.Substring($SkillsRoot.Length).TrimStart("\", "/")
  $normalized = ConvertTo-GitHubPath $relative
  if ($normalized -match "(^|/)__pycache__/") { return $true }
  if ($normalized -match "\.pyc$") { return $true }
  if ($normalized -match "(^|/)\.DS_Store$") { return $true }
  if ($normalized -match "(^|/)Thumbs\.db$") { return $true }
  return $false
}

function Get-RemoteContentBytes {
  param(
    [string]$Repo,
    [string]$Path,
    [string]$BranchName,
    [hashtable]$Headers
  )

  $encoded = ConvertTo-UriPath $Path
  $content = Invoke-GitHubJson -Method GET -Uri "https://api.github.com/repos/$Repo/contents/$encoded`?ref=$BranchName" -Headers $Headers
  return [Convert]::FromBase64String(($content.content -replace "\s", ""))
}

function Set-GitHubFile {
  param(
    [string]$Repo,
    [string]$Path,
    [string]$BranchName,
    [string]$LocalPath,
    [string]$ExistingSha,
    [hashtable]$Headers,
    [string]$Message
  )

  $encoded = ConvertTo-UriPath $Path
  $bytes = [System.IO.File]::ReadAllBytes($LocalPath)
  $body = @{
    message = $Message
    content = [Convert]::ToBase64String($bytes)
    branch = $BranchName
  }
  if ($ExistingSha) { $body.sha = $ExistingSha }

  $response = Invoke-GitHubJson -Method PUT -Uri "https://api.github.com/repos/$Repo/contents/$encoded" -Headers $Headers -Body $body
  return $response.commit.sha
}

function Set-LocalFileFromGitHub {
  param(
    [string]$Repo,
    [string]$RemotePath,
    [string]$LocalPath,
    [string]$BranchName,
    [hashtable]$Headers
  )

  $bytes = Get-RemoteContentBytes -Repo $Repo -Path $RemotePath -BranchName $BranchName -Headers $Headers
  $directory = Split-Path -Parent $LocalPath
  if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  [System.IO.File]::WriteAllBytes($LocalPath, $bytes)
}

function New-Result {
  param(
    [string]$Area,
    [string]$Path,
    [string]$State,
    [string]$Action,
    [string]$Detail = ""
  )

  return [pscustomobject]@{
    Area = $Area
    Path = $Path
    State = $State
    Action = $Action
    Detail = $Detail
  }
}

$resolvedCodexHome = Resolve-CodexHome -Explicit $CodexHome
$credential = Get-GitHubToken
$headers = New-GitHubHeaders -Token $credential.Token

$skillsRepoInfo = Get-RepoInfo -Repo $SkillsRepo -Headers $headers
$agentRepoInfo = Get-RepoInfo -Repo $AgentRepo -Headers $headers
$skillsBranch = if ($Branch) { $Branch } else { $skillsRepoInfo.default_branch }
$agentBranch = if ($Branch) { $Branch } else { $agentRepoInfo.default_branch }

Write-Output "Mode: $Mode"
Write-Output "CodexHome: $resolvedCodexHome"
Write-Output "Credential: $($credential.Source)"
Write-Output "SkillsRepo: $SkillsRepo@$skillsBranch"
Write-Output "AgentRepo: $AgentRepo@$agentBranch"

$localMap = Get-LocalSyncMap -Root $resolvedCodexHome
$remoteSkillsMap = Get-RemoteTreeMap -Repo $SkillsRepo -BranchName $skillsBranch -Headers $headers -Prefix "skills/"
$remoteAgentMap = Get-RemoteTreeMap -Repo $AgentRepo -BranchName $agentBranch -Headers $headers -Prefix ""

$remoteMap = @{}
foreach ($key in $remoteSkillsMap.Keys) { $remoteMap[$key] = $remoteSkillsMap[$key] }
if ($remoteAgentMap.ContainsKey("AGENTS.md")) { $remoteMap["AGENTS.md"] = $remoteAgentMap["AGENTS.md"] }

$allPaths = @($localMap.Keys + $remoteMap.Keys) | Sort-Object -Unique
$results = New-Object System.Collections.Generic.List[object]

foreach ($path in $allPaths) {
  $hasLocal = $localMap.ContainsKey($path)
  $hasRemote = $remoteMap.ContainsKey($path)
  $area = if ($path -eq "AGENTS.md") { "AGENTS" } else { "Skill" }
  $repo = if ($area -eq "AGENTS") { $AgentRepo } else { $SkillsRepo }
  $branchName = if ($area -eq "AGENTS") { $agentBranch } else { $skillsBranch }

  if ($hasLocal -and $hasRemote) {
    if ($localMap[$path].Sha -eq $remoteMap[$path].Sha) {
      $results.Add((New-Result -Area $area -Path $path -State "Same" -Action "Skip"))
      continue
    }

    if ($Mode -eq "Backup" -and $ForceLocal) {
      $commit = Set-GitHubFile -Repo $repo -Path $path -BranchName $branchName -LocalPath $localMap[$path].LocalPath -ExistingSha $remoteMap[$path].Sha -Headers $headers -Message "Sync $path from Codex"
      $results.Add((New-Result -Area $area -Path $path -State "Different" -Action "Uploaded" -Detail $commit))
    } elseif ($Mode -eq "Restore" -and $ForceRemote) {
      Set-LocalFileFromGitHub -Repo $repo -RemotePath $path -LocalPath $localMap[$path].LocalPath -BranchName $branchName -Headers $headers
      $results.Add((New-Result -Area $area -Path $path -State "Different" -Action "Restored"))
    } else {
      $results.Add((New-Result -Area $area -Path $path -State "Different" -Action "Conflict" -Detail "Use -ForceLocal for Backup or -ForceRemote for Restore."))
    }
    continue
  }

  if ($hasLocal -and -not $hasRemote) {
    if ($Mode -eq "Backup") {
      $commit = Set-GitHubFile -Repo $repo -Path $path -BranchName $branchName -LocalPath $localMap[$path].LocalPath -ExistingSha $null -Headers $headers -Message "Sync $path from Codex"
      $results.Add((New-Result -Area $area -Path $path -State "LocalOnly" -Action "CreatedRemote" -Detail $commit))
    } else {
      $results.Add((New-Result -Area $area -Path $path -State "LocalOnly" -Action "ReportOnly"))
    }
    continue
  }

  if (-not $hasLocal -and $hasRemote) {
    if ($Mode -eq "Restore") {
      $localPath = if ($area -eq "AGENTS") {
        Join-Path $resolvedCodexHome "AGENTS.md"
      } else {
        Join-Path (Join-Path $resolvedCodexHome "skills") ($path.Substring("skills/".Length) -replace "/", "\")
      }
      Set-LocalFileFromGitHub -Repo $repo -RemotePath $path -LocalPath $localPath -BranchName $branchName -Headers $headers
      $results.Add((New-Result -Area $area -Path $path -State "RemoteOnly" -Action "CreatedLocal"))
    } else {
      $results.Add((New-Result -Area $area -Path $path -State "RemoteOnly" -Action "ReportOnly"))
    }
  }
}

$results | Sort-Object Area, Path | Format-Table -AutoSize

$summary = $results | Group-Object Action | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }
Write-Output ("Summary: " + ($summary -join "; "))

$conflicts = @($results | Where-Object { $_.Action -eq "Conflict" })
if ($conflicts.Count -gt 0) {
  Write-Output "Conflicts remain: $($conflicts.Count)"
  if ($Mode -ne "Status") {
    exit 2
  }
}
