$ErrorActionPreference = "Stop"

$bundleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceRoot = Join-Path $bundleRoot "skills"

if (-not (Test-Path -LiteralPath $sourceRoot)) {
  throw "未找到 skills 源目录：$sourceRoot"
}

if ($env:CODEX_HOME -and $env:CODEX_HOME.Trim().Length -gt 0) {
  $codexHome = $env:CODEX_HOME
} else {
  $codexHome = Join-Path $HOME ".codex"
}

$targetRoot = Join-Path $codexHome "skills"
New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null

Get-ChildItem -LiteralPath $sourceRoot -Directory | ForEach-Object {
  $target = Join-Path $targetRoot $_.Name
  Copy-Item -LiteralPath $_.FullName -Destination $targetRoot -Recurse -Force
  Write-Output "已同步 skill：$($_.Name) -> $target"
}

Write-Output "完成。Codex skills 目录：$targetRoot"
Write-Output "如果 Codex 已经打开，建议重启 Codex 以重新发现新 skill。"
