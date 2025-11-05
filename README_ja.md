# find_and_extract.sh 日本語 README

`find_and_extract.sh` は、オンプレ／クラウド混在環境で運用される Web システムの STG 設定値を安全に PRD 向けへ変換し、必要に応じてロールバックできるよう開発された Bash スクリプトです。英語版 README と CHANGELOG を補完する目的で、最新仕様を日本語で詳細にまとめています。

---

## 1. 前提条件と配布形態

- **対応 OS / Shell**: RHEL・CentOS 系で Bash 4 以上が利用可能であること。
- **配布方法**: `repo/` ディレクトリ内の `find_and_extract.sh` を対象サーバにコピーし、ローカルで実行します（外部依存は `curl` のみ。未インストールでも実行は可能ですが、td-agent リポジトリの疎通確認がスキップされます）。
- **作業ディレクトリ**: 実行ユーザー毎に `/tmp/<ユーザー名>/find_and_extract/` を自動作成し、パーミッション 700 で管理します。ドライランの差分や本番適用結果、警告ログもここに保存されます。

---

## 2. 同梱ファイル

| ファイル | 概要 |
|----------|------|
| `find_and_extract.sh` | CLI 本体。`scan` / `transform` / `rollback` の 3 サブコマンドを提供。 |
| `CHANGELOG.md` / `CHANGELOG_ja.md` | 変更履歴の英語版 / 日本語版。 |
| `docs/FIND_AND_EXTRACT_TOOL.md` | 運用ガイド（日本語、詳細版）。 |
| `docs/PROJECT_SPEC_SH.md` | シェル版の仕様書（要件と安全対策の概要）。 |
| `schemas/` | CLI オプションや出力 JSON のスキーマ。 |
| `generate_td_agent_conf.sh` | td-agent 設定ファイル生成用スクリプト。 |

---

## 3. クイックスタート

```bash
./find_and_extract.sh scan /etc
./find_and_extract.sh transform --dry-run /var
./find_and_extract.sh transform --apply /var
./find_and_extract.sh rollback --file /etc/hosts \
    /tmp/$USER/find_and_extract/$(hostname)_<timestamp>_transform.log
```

実行前に以下を確認してください。

1. 対象ディレクトリに読み取り権限がある。
2. 実行ユーザーが `/tmp` 配下に 700 ディレクトリを作成できる。
3. `transform --apply` を実行する場合は、バックアップ（`*_YYYYMMDD_HHMM.bak`）が生成されるため十分なディスク容量がある。

---

## 4. サブコマンド詳細

| コマンド | 想定シナリオ | 代表的な出力 |
|----------|--------------|--------------|
| `scan` | STG 定義・PRD 定義・混在ファイルの棚卸し。読み取り専用。 | `<host>_<timestamp>_{current_infra,new_infra_stg,new_infra_prd,other,mixed}.log` |
| `transform` | STG 用の設定を PRD 向けに置換。標準はドライラン。`--apply` で実際の書き換えとバックアップを実施。 | `*_transform_preview.log`（ドライラン） / `*_transform.log`（適用結果） |
| `rollback` | `transform` で記録したバックアップログをもとにファイルを復旧。`--file` で対象を絞り込み可能。 | 成功 / 失敗件数のサマリー（標準出力） |

### 代表的なオプション

- `-v/--verbose` : 詳細ログを出力（スキップ対象の理由などを明示）。
- `--skip-backup-files` : `*.bak`, `*.old`, `*~`, `.swp` などバックアップ／編集履歴を想定したファイルを除外。
- `--dry-run`（既定） / `--apply` : `transform` モードの実行方式を指定。
- `--file <path>` : `rollback` で特定ファイルのみ復旧する際に使用。
- `--deletelogs` : `/tmp/<ユーザー>/find_and_extract/` 配下のログ一式を削除。

---

## 5. `transform` モードでの処理フロー

1. **事前検証**
   - 対象が `/var` の場合、`/var/www/com/ipet-ins/<system>/fuel/app/config/newproduction/` の存在と構成ファイルをチェック。不足があれば警告ログに記載。
   - Fuel の設定以外を不要に触らないよう、保護対象（`/etc/nginx/nginx.conf`, `/etc/httpd/httpd.conf` など）を除外。

2. **対象ファイルの絞り込み**
   - `scan` と同じロジックでファイルを列挙し、バイナリ・バックアップ風ファイルに加え、`*.save` や `YYYYMMDD`（8 桁の年月日）を含むファイル名を自動で除外。エディタの一時ファイルや日付付きバックアップを誤更新しないよう配慮しています。

3. **変換処理**
   - AWK を用いて STG → PRD 置換を実施。変換が発生したファイルのみ一時ファイルへ出力し、`diff -u` で差分を保存。
   - **`/etc/profile` の特例**: STG 用 IP（第 3 オクテット 170〜179, 173 → 162）や `Hostname=xxx-stg` といったトークンを PRD 表記へ変換します。同時に `http_proxy` / `https_proxy` / `HTTP_PROXY` / `HTTPS_PROXY` が存在しなければ `http://172.16.162.6:3128/` を輸出する `export` 行を追記します。
   - **`/etc/yum.repos.d/td.repo` の再生成**: OS のメジャーバージョンを判定し、以下の URL を選択します。
     - CentOS 6 系: `https://td-agent-package-browser.herokuapp.com/3/redhat/6/x86_64`
     - RHEL / CentOS 7 系: `https://td-agent-package-browser.herokuapp.com/4/redhat/7/x86_64`
     - RHEL 9 系: `https://td-agent-package-browser.herokuapp.com/4/redhat/9/x86_64`
     - それ以外: 7 系相当（運用の標準 OS が RHEL7 であるため）
     書き換え前に `repodata/repomd.xml` への HEAD リクエストで疎通確認を行い、結果を標準出力に通知します。GPG キーは `https://s3.amazonaws.com/packages.treasuredata.com/GPG-KEY-td-agent` に更新済みです。

4. **ドライラン**
   - `As-Is / To-Be` 形式で差分を標準出力に表示し、`*_transform_preview.log` に保存。適用候補が無い場合は「変更対象のファイルは見つかりませんでした。」と表示されます。

5. **本適用 (`--apply`)**
   - 変換対象数を表示し、`yes` / `y` で承認。その他（`no`, `maybe` 等）の入力は不正として扱い、メッセージを表示したうえでキャンセルします。
   - 適用時は `*.bak_<timestamp>` のバックアップを作成し、元のパーミッション・所有者・グループを復元してから差分を反映。結果は `*_transform.log` にタブ区切りで記録され、`rollback` の入力として利用できます。

---

## 6. `rollback` の手順

1. `/tmp/<ユーザー>/find_and_extract/<host>_<timestamp>_transform.log` を特定。
2. `./find_and_extract.sh rollback [--file <path>] <transform-log>` を実行。
3. 復元対象が見つからない場合やバックアップが破損している場合はエラーとしてカウントされます。処理結果は「復元: X 件 / 失敗: Y 件」の形で表示されます。

---

## 7. ログと一時ファイル

- すべてのログは `/tmp/<ユーザー>/find_and_extract/` に集約され、ディレクトリ作成時に 700 パーミッションを付与します。
- 主なログ種別:
  - `*_current_infra.log`, `*_new_infra_stg.log`, `*_new_infra_prd.log`, `*_other.log`, `*_mixed.log`
  - `*_warnings.log`（構成不足や疎通失敗の警告）
  - `*_transform_preview.log`（ドライラン差分）
  - `*_transform.log`（本適用結果）
- `--deletelogs` オプションで上記ログをまとめて削除可能です。

---

## 8. よくある質問 (FAQ)

**Q. `/etc/profile` に既に PRD 向けのプロキシ設定がある場合はどうなりますか？**  
A. 既存の `export http_proxy=...` 等が見つかった場合は追記をスキップし、重複定義は行いません。

**Q. Treasure Data リポジトリの疎通に失敗したらどうなりますか？**  
A. 失敗時は `TD_REPO_LAST_FAILURE=1` となり、メッセージを標準出力に表示します。ファイル自体は生成しますが、警告を確認のうえ手動で再試行することを推奨します。

**Q. 独自形式のバックアップファイルを除外したい場合は？**  
A. `--skip-backup-files` を指定すると既定のバックアップ判定が有効になります。追加で除外したい場合は `should_skip_file_for_processing()` のロジックをカスタマイズしてください（日本語ガイドおよびソース参照）。

---

## 9. 参考ドキュメント

- 詳細な操作手順: `docs/FIND_AND_EXTRACT_TOOL.md`
- 仕様と安全対策まとめ: `docs/PROJECT_SPEC_SH.md`
- 変更履歴（英語版 / 日本語版）: `CHANGELOG.md`, `CHANGELOG_ja.md`

これらを併用することで、STG → PRD 移行の標準化と安全なロールバックが実現できます。

