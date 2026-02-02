# Rust & Cargo
## ユーザーグローバルでの設定
### インストール
```bash
mise use -g -y rust &&
"$(mise which rustc)" --version
```

### シェル補完のインストール（bashの場合）
```bash
mkdir -p "$HOME/.local/share/bash-completion/completions" &&
tee "$HOME/.local/share/bash-completion/completions/mise-rustup" <<- EOS > /dev/null &&
if hash rustup 2>/dev/null; then
  eval "\$(rustup completions bash)"
fi
EOS
. "$HOME/.local/share/bash-completion/completions/mise-rustup"
CREATE_COMPLETION () {
  tee "$HOME/.local/share/bash-completion/completions/$1" <<- EOS > /dev/null
  if hash rustup 2>/dev/null && hash $1 2>/dev/null; then
    eval "\$(rustup completions bash $1)"
  fi
EOS
}
CREATE_COMPLETION "mise-cargo" &&
CREATE_COMPLETION "mise-rustc" &&
CREATE_COMPLETION "mise-rustfmt"
```

### シェル補完のアンインストール（bashの場合）
```bash
DELETE_COMPLETION () {
  if [ -e "$HOME/.local/share/bash-completion/completions/$1" ]; then
    rm "$HOME/.local/share/bash-completion/completions/$1"
  fi
}
DELETE_COMPLETION "mise-rustup" &&
DELETE_COMPLETION "mise-cargo" &&
DELETE_COMPLETION "mise-rustc" &&
DELETE_COMPLETION "mise-rustfmt"
```

### アンインストール
```bash
mise uninstall rust &&
perl -pi -e "s/^rust = \".+\"\\n//mg" ~/.config/mise/config.toml
```
