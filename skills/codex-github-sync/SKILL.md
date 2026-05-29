---
name: codex-github-sync
description: Use when the user wants to compare, back up, restore, or synchronize Codex skills and the global AGENTS.md across multiple computers through GitHub repositories.
---

# Codex GitHub 同步

## Overview

Use this skill to keep Codex skills and the global `AGENTS.md` consistent across multiple computers through GitHub. The default behavior is conservative: compare first, report conflicts, and never delete local or remote files.

## What It Syncs

Default local Codex home detection order:

1. `$env:CODEX_HOME`
2. `F:\Codex\.codex`
3. `$HOME\.codex`

Default repositories:

| Local content | GitHub repo | Remote path |
| --- | --- | --- |
| `CODEX_HOME\skills\**` | `a798221115-byte/Codex-skill` | `skills/` |
| `CODEX_HOME\AGENTS.md` | `a798221115-byte/Codex-AGENTmd` | `AGENTS.md` |

Included:

- All directories under `CODEX_HOME\skills`, including `.system`.
- All files inside each skill directory.
- The global `CODEX_HOME\AGENTS.md`.

Excluded:

- `plugins/cache`
- `auth.json`
- `config.toml`
- `sessions`
- `cache`, `tmp`, `.tmp`
- runtime files, account credentials, and other Codex state
- generated Python caches such as `__pycache__` and `*.pyc`

## Script

Run the bundled script:

```powershell
powershell -ExecutionPolicy Bypass -File F:\Codex\.codex\skills\codex-github-sync\scripts\codex-sync.ps1 -Mode Status
```

Modes:

| Mode | Behavior |
| --- | --- |
| `Status` | Compare local and GitHub. Report same, local-only, remote-only, different, and conflicts. No writes. |
| `Backup` | Upload local-only files. Skip same files. Report different files as conflicts unless `-ForceLocal` is passed. |
| `Restore` | Download remote-only files. Skip same files. Report different files as conflicts unless `-ForceRemote` is passed. |

Examples:

```powershell
# Safe default: only inspect differences.
powershell -ExecutionPolicy Bypass -File F:\Codex\.codex\skills\codex-github-sync\scripts\codex-sync.ps1 -Mode Status

# Back up new local files to GitHub, but do not overwrite remote differences.
powershell -ExecutionPolicy Bypass -File F:\Codex\.codex\skills\codex-github-sync\scripts\codex-sync.ps1 -Mode Backup

# Restore missing files on a new computer, but do not overwrite local differences.
powershell -ExecutionPolicy Bypass -File F:\Codex\.codex\skills\codex-github-sync\scripts\codex-sync.ps1 -Mode Restore

# Explicitly let local win when backing up.
powershell -ExecutionPolicy Bypass -File F:\Codex\.codex\skills\codex-github-sync\scripts\codex-sync.ps1 -Mode Backup -ForceLocal

# Explicitly let GitHub win when restoring.
powershell -ExecutionPolicy Bypass -File F:\Codex\.codex\skills\codex-github-sync\scripts\codex-sync.ps1 -Mode Restore -ForceRemote
```

## Credentials

The script tries credentials in this order:

1. GitHub CLI: `gh auth status`, then `gh auth token`
2. Environment variables: `GITHUB_TOKEN`, then `GH_TOKEN`
3. Git Credential Manager token for `https://github.com`

If no credential is available, the script stops before writing anything.

## Conflict Policy

Default conflict policy: report only.

- `Backup` does not overwrite different remote files unless `-ForceLocal` is passed.
- `Restore` does not overwrite different local files unless `-ForceRemote` is passed.
- The script never deletes local files.
- The script never deletes remote files.
- Extra local files remain local unless backed up.
- Extra remote files remain remote unless restored.

## New Computer Flow

1. Install GitHub CLI or make sure Git Credential Manager is logged in.
2. Install or copy this `codex-github-sync` skill.
3. Run `Status` to inspect what will change.
4. Run `Restore` to create missing local files.
5. Use `-ForceRemote` only when you intentionally want GitHub to overwrite local differences.
6. Restart Codex so it can rediscover restored skills.

## Output Expectations

After running the script, summarize:

- Codex home used.
- Repositories used.
- Counts for same, local-only, remote-only, different/conflict, uploaded, restored, and skipped.
- Whether any conflicts require a follow-up command.

Do not claim synchronization is complete if conflicts remain.
