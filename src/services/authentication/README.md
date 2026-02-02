# 認証
## 関連した補助コマンド
### ユーザーリストを出力
`/etc/shadow`および`/etc/passwd`から読み取った、ユーザー名、ハッシュ化されたパスワード、UID、GID、ホームディレクトリ、およびログインシェルをコロン区切りテキストで出力します。
```bash
sudo awk -F: '
BEGIN {
    format = "%s:%s:%s:%s:%s:%s\n"
}
FNR==NR {
    shadow[$1] = $2
    next
}
{
    username = $1
    uid      = $3
    gid      = $4
    homedir  = $6
    shell    = $7
    passhash = (username in shadow) ? shadow[username] : "!"
    if (shell != "/usr/sbin/nologin" && shell != "/usr/usr/sbin/nologin" && shell != "/bin/false" && shell != "/bin/sync") {
        printf(format, username, passhash, uid, gid, homedir, shell)
    }
}' /etc/shadow /etc/passwd
```

### ユーザーリストからユーザーを復元（未テスト）
```bash
while IFS=':' read -r username passhash uid gid homedir shell; do
    echo "Processing user '$username' (UID: $uid, GID: $gid)"
    
    # 同名のユーザーがすでに存在する場合はスキップ
    if id "$username" &>/dev/null; then
        echo "Warning: User '$username' already exists. Skipping." >&2
        continue
    fi

    # 同じUIDがすでに存在する場合もスキップ
    if getent passwd "$uid" &>/dev/null; then
        echo "Warning: UID '$uid' already exists. Skipping user '$username'." >&2
        continue
    fi
    
    # 指定のGIDが存在しない場合は、ユーザー名をグループ名として作成する
    if ! getent group "$gid" > /dev/null; then
        echo "Group with GID '$gid' does not exist. Creating group '$username'."
        sudo groupadd -g "$gid" "$username"
    fi

    # ホームディレクトリがすでに存在する場合は、所有権を変更する
    if sudo test -d "$homedir"; then
        sudo chown "$uid:$gid" "$homedir"
    fi

    # ユーザー作成
    sudo useradd \
      --password "$passhash" \
      --uid "$uid" \
      --gid "$gid" \
      --home-dir "$homedir" \
      --create-home \
      --shell "$shell" \
      "$username"
    echo "User '$username' created."
done < "user_info.tsv"
```

### 各ユーザーのauthorized_keysリストを出力
```bash
while IFS=: read -r user _ _ _ _ homedir _; do
    authorized_keys=$( sudo test -f "$homedir/.ssh/authorized_keys" && sudo cat "$homedir/.ssh/authorized_keys" || echo "" );
    if [[ -n "$authorized_keys" ]]; then
        jq -n --arg user "$user" --arg key "$key" \
          '{username: $user, authorized_keys: $key}';
    fi
done < /etc/passwd | jq -s '.'
```

### 各ユーザーのauthorized_keysリストから復元（未テスト）
```bash
jq -c '.[]' authorized_keys.json | while IFS= read -r record; do
    username=$(echo "$record" | jq -r '.username');
    keys=$(echo "$record" | jq -r '.authorized_keys');

    # 対象ユーザーのホームディレクトリ取得（/etc/passwd より）
    homedir=$(getent passwd "$username" | cut -d: -f6);
    if sudo test ! -d "$homedir"; then
        echo "Warning: User '$username' does not exist on this system. Skipping." >&2;
        continue;
    fi

    ssh_dir="$homedir/.ssh";
    auth_file="$ssh_dir/authorized_keys";

    # .sshディレクトリが無ければ作成し、適切な所有権・パーミッションを設定
    if sudo test ! -d "$ssh_dir"; then
        sudo mkdir -p "$ssh_dir";
        sudo chown "$username":"$(id -gn "$username")" "$ssh_dir";
        sudo chmod 700 "$ssh_dir";
    fi

    # authorized_keysをJSONから取得した内容で上書き
    # 複数行の内容も保持するようにprintfで出力
    printf "%s\n" "$keys" | sudo tee "$auth_file" > /dev/null;
    sudo chown "$username":"$(id -gn "$username")" "$auth_file";
    sudo chmod 600 "$auth_file";

    echo "Restored authorized_keys for user: $username";
```
