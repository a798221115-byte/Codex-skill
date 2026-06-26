# Codex Custom Skills Sync Pack

这个仓库只同步你自己创建的 Codex skills，不同步 Codex 系统 skill、插件缓存或运行时文件。

## 目录结构

```text
codex-skills/
  skills/
    ai-ui-design-standards/
      SKILL.md
      agents/openai.yaml
      references/source-summary.md
    codex-github-sync/
      SKILL.md
      agents/openai.yaml
      scripts/codex-sync.ps1
    dreamina-cli/
      SKILL.md
    guizang-ppt-skill/
      SKILL.md
      assets/
      references/
      scripts/
    hatch-pet/
      SKILL.md
      agents/
      references/
      scripts/
    impeccable/
      SKILL.md
      agents/
      reference/
      scripts/
    knowledge-base-collection/
      SKILL.md
      agents/openai.yaml
    qiaomu-anything-to-notebooklm/
      SKILL.md
      feishu-read-mcp/
      scripts/
    pm-render-retouch/
      SKILL.md
      agents/openai.yaml
    ui-ux-pro-max/
      SKILL.md
      data
      scripts
  install.ps1
```

## 首次安装到本机 Codex

在仓库根目录运行：

```powershell
.\install.ps1
```

如果 PowerShell 执行策略拦截：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

脚本会把 `skills/` 下面的自定义 skill 复制到本机 Codex skills 目录：

- 如果设置了 `CODEX_HOME`，使用 `$env:CODEX_HOME\skills`
- 否则使用 `$HOME\.codex\skills`

脚本不会删除文件，只会创建目录并复制/覆盖同名 skill。

## Git 同步工作流

### 当前电脑：提交修改

```powershell
git status
git add .
git commit -m "Update Codex skills"
git push
```

### 新电脑：拉取并安装

```powershell
git clone <你的仓库地址> codex-skills
cd codex-skills
.\install.ps1
```

如果已经 clone 过：

```powershell
cd codex-skills
git pull
.\install.ps1
```

## 注意

不要把整个 `.codex` 目录提交进 Git。只维护本仓库中的 `skills/` 目录。
