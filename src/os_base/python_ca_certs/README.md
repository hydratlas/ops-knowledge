# python_ca_certs

Ansible Python インタープリターが CA 証明書にアクセスできることを保証するロールである。

## 概要

カスタムビルドの Python（OpenSSL をスタティックリンク）では、コンパイル時に埋め込まれた CA 証明書パス（例: `~/.local/openssl-3.5.5/ssl/cert.pem`）が実際にはファイルシステム上に存在しない場合がある。このロールは Python の `ssl.get_default_verify_paths()` で期待される CA 証明書パスを検出し、システムの CA バンドルへのシンボリックリンクとして冪等に張り直す。

EOLディストリビューションではシステムバンドル自体が古い場合があるため、必要に応じて`os_base/system_ca_certs`ロールを**本ロールの前に**適用してシステムバンドルを更新しておくこと。

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

- 対象となる Python インタープリターは Ansible がモジュール実行に使っているもの（`ansible_facts.python.executable` が指すもの）のみである。同一ホスト上に別ビルドの Python が存在しても本ロールは触らない
- 既存のsymlinkが正しいシステムバンドルを指している場合は何もしない（冪等）
- 既存のsymlinkが異なるパスを指していたり通常ファイルが存在する場合は強制的にシステムバンドルへのsymlinkに置き換える（`force: true`）
- Pythonの期待パスがシステムバンドル自身と一致する場合（標準のシステムPythonなど）は処理をスキップし、システムバンドルを誤って自己参照のsymlinkで上書きしない
