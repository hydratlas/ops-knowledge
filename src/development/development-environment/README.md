# 開発環境

開発作業に必要な基本的なツールのインストール手順をまとめたドキュメントです。Git等の必須ツールのインストール方法を、主要なOS（Debian系、RHEL系、Windows）ごとに記載しています。

## システムグローバル
### Debian系
```bash
sudo apt-get install -y git
```

### RHEL系
```bash
sudo dnf install -y git
```

### Windows
```powershell
winget install -e --id Git.Git
$env:Path = [System.Environment]::GetEnvironmentVariable( `
  'Path', [System.EnvironmentVariableTarget]::Machine) # インストール直後にGitをすぐ使えるように、システムレベルのPath環境変数を現在のPowerShellセッションに反映
```
