# 構成管理ツール
## Linux（Bash + mise + uv）
### Terraformのインストール
```bash
mise use terraform
```

### Ansibleのインストール
```bash
uv init &&
uv python pin 3.13 &&
uv add ansible
```

## Windows（Git Bash）
### Terraformのインストール
```bash
winget install -e --id Hashicorp.Terraform
```

### uvのインストール
```bash
winget install -e --id astral-sh.uv
```

### Ansibleのインストール
```bash
uv init &&
uv python pin 3.13 &&
uv add ansible
```

### Ansibleの再インストール
`pyproject.toml`にもとづいて再インストールします。
```bash
uv sync
```
