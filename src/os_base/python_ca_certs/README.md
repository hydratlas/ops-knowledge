# python_ca_certs

Ansible Python インタープリターが CA 証明書にアクセスできることを保証するロールである。

## 概要

カスタムビルドの Python（OpenSSL をスタティックリンク）では、コンパイル時に埋め込まれた CA 証明書パス（例: `~/.local/openssl-3.5.5/ssl/cert.pem`）が実際にはファイルシステム上に存在しない場合がある。このロールは Python の `ssl.get_default_verify_paths()` で期待される CA 証明書パスを検出し、ファイルが存在しなければシステムの CA バンドルへのシンボリックリンクを自動作成する。

対応するシステム CA バンドルパスは以下である。

| ディストリビューション | パス |
|------------------------|------|
| Debian / Ubuntu | `/etc/ssl/certs/ca-certificates.crt` |
| RHEL / CentOS | `/etc/pki/tls/certs/ca-bundle.crt` |

## 使用例

```yaml
- hosts: legacy
  become: true
  gather_facts: false
  roles:
    - role: os_base/python_ca_certs
```

## 動作条件

- CA 証明書パスが既に存在する場合は何もしない（冪等）
- システム Python を使用しているホストでは通常 CA ファイルが存在するため、影響なし
