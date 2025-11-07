# 🛠️ find_and_extract.sh 日本語 README

`find_and_extract.sh` は、オンプレ／クラウドが混在する運用環境で STG 向けの設定値を安全に PRD 向けへ変換し、必要に応じてロールバックできるよう設計された Bash スクリプトです。本書は最新版の仕様と運用ポイントを日本語で整理したものです。英語版 README は [`README_EN.md`](README_EN.md) を参照してください。

---

## 🧭 目次

1. [概要](#概要)
2. [✨ 主な特長](#-主な特長)
3. [📂 リポジトリ構成](#-リポジトリ構成)
4. [🚀 クイックスタート](#-クイックスタート)
5. [🧪 コマンドリファレンス](#-コマンドリファレンス)
6. [🔧 transform ワークフロー](#-transform-ワークフロー)
7. [🛡️ 安全策と除外ルール](#-安全策と除外ルール)
8. [🗃️ ログと生成物](#-ログと生成物)
9. [📚 関連ドキュメント](#-関連ドキュメント)
10. [🌐 ローカライズと変更履歴](#-ローカライズと変更履歴)

---

## 概要

- **対象シェル**: Bash 4.0 以上
- **対応 OS**: RHEL / CentOS 系（ローカル実行）
- **作業ディレクトリ**: `/tmp/<ユーザー>/find_and_extract/` を自動作成（パーミッション 700）
- **生成物**: スキャン・差分・適用ログ・ロールバックメタデータなど

---

## ✨ 主な特長

- ライフサイクルを 3 サブコマンドで完結:
  - `scan` 🧭 STG / PRD の痕跡を棚卸し（読み取り専用）
  - `transform` 🔄 置換内容をプレビュー＆適用。確認プロンプトとバックアップを標準装備
  - `rollback` ⏪ バックアップファイルから復元
- `/etc/profile` の自動整備 🧼:
  - STG 用 IP・ホスト名・`stg` トークンを PRD 向けへ変換
  - `http_proxy` / `https_proxy` / `HTTP_PROXY` / `HTTPS_PROXY` を `http://172.16.162.6:3128/` に統一して追記（既存値があれば保持）
- Treasure Data (td-agent) リポジトリ生成 📦:
  - RHEL/CentOS 6 ⇒ まず `https://packages.treasuredata.com/4/redhat/6/x86_64` を採用し、`yum update td-agent` が失敗した場合にのみ `/3/redhat/6/` へフォールバック
  - RHEL/CentOS 7 ⇒ `https://packages.treasuredata.com/4/redhat/7/x86_64`
  - RHEL/CentOS 8 ⇒ `https://packages.treasuredata.com/4/redhat/8/x86_64`
  - RHEL 9 ⇒ `https://packages.treasuredata.com/4/redhat/9/x86_64`
  - GPG キーを `https://packages.treasuredata.com/GPG-KEY-td-agent` から取得し、`repodata/repomd.xml` の疎通を `curl --write-out '%{http_code}'` で確認
  - CentOS リポジトリ (`/etc/yum.repos.d/CentOS-*`) を vault.centos.org / 固定バージョン / x86_64 に書き換え、全 `.repo` の `http://` を `https://` へ統一
  - `yum-config-manager` / `dnf config-manager` で `remi-safe`, `remi-php*`, `zabbix`, `zabbix-non-supported` を無効化
  - 403 応答時は `/etc/profile` の読み込みと FW ホワイトリスト確認を促す警告を出力
  - `yum update td-agent --disablerepo=* --enablerepo=treasuredata` を試行し、ログを `/tmp/<user>/find_and_extract/td-agent-update.log` に保存（RHEL6 では失敗時に td-agent 3 リポジトリへ切替えて再試行）。未インストール時は `yum install td-agent --disablerepo=* --enablerepo=treasuredata` を実行し、結果を `/tmp/<user>/find_and_extract/td-agent-install.log` に記録
- 編集途中ファイルを誤変換しない配慮 🙌:
  - `*.save` や `YYYYMMDD` を含むファイル名を除外
  - バイナリ／10 MiB 超／バックアップ風のファイルもスキップ

---

## 📂 リポジトリ構成

| パス | 説明 |
|------|------|
| `find_and_extract.sh` | CLI 本体（`scan` / `transform` / `rollback`）。 |
| `CHANGELOG.md` / `CHANGELOG_ja.md` | リリースノート（英語／日本語）。 |
| `docs/FIND_AND_EXTRACT_TOOL.md` | 詳細な運用ガイド（日本語）。 |
| `docs/PROJECT_SPEC_SH.md` | シェル版仕様と安全対策。 |
| `schemas/` | CLI 入力・出力の JSON スキーマ。 |
| `generate_td_agent_conf.sh` | td-agent 設定ファイル生成ヘルパー。 |

---

## 🚀 クイックスタート

```bash
./find_and_extract.sh scan /etc
./find_and_extract.sh transform --dry-run /var
./find_and_extract.sh transform --apply /var
./find_and_extract.sh rollback --file /etc/hosts     /tmp/$USER/find_and_extract/$(hostname)_<timestamp>_transform.log
```

実行前チェック ✅:

1. 対象ディレクトリの読み取り権限と `/tmp` の空き容量を確認。
2. Bash 4 以上が利用可能か（`curl` があれば疎通確認にも活用）。
3. `--apply` 実行時に `*.bak_<timestamp>` が同ディレクトリへ作成される点を共有。

---

## 🧪 コマンドリファレンス

| サブコマンド | 想定シナリオ | 主な出力 |
|--------------|--------------|----------|
| `scan` | STG/PRD の痕跡を棚卸し（読み取り専用）。 | `<host>_<timestamp>_{current_infra,new_infra_stg,new_infra_prd,other,mixed}.log` |
| `transform` | STG 値を PRD 向けに置換。既定はドライラン。 | `*_transform_preview.log`, `*_transform.log` |
| `rollback` | 変換ログをもとに復元。`--file` で対象を限定。 | 復元 / 失敗件数のサマリー |

### 主なオプション

- `-v, --verbose` : 詳細進捗（スキップ理由など）を出力。
- `--skip-backup-files` : `*.bak`, `*.old`, `*~`, `.swp` 等を除外。
- `--dry-run` / `--apply` : `transform` の実行モード。
- `--file <path>` : `rollback` の対象を限定。
- `--deletelogs` : `/tmp/<ユーザー>/find_and_extract/` のログを削除。

---

## 🔧 transform ワークフロー

1. **事前チェック** – `/var` 配下の場合、`fuel/app/config/newproduction/` の必須ファイルを確認し、不足は警告ログへ記録。保護対象（nginx / Apache 設定など）は最初から除外。
2. **対象ファイル抽出** – `scan` と同様に列挙し、バイナリ／大容量、バックアップ、`*.save`、`YYYYMMDD` を含むファイル名を除外。
3. **変換処理** – AWK で IP・ホスト名・トークンを置換。`/etc/profile` は固定プロキシを追記しつつ STG トークンを PRD 化。`/etc/yum.repos.d/td.repo` は OS 判定で URL と GPG キーを更新し疎通確認を実施（RHEL6 は td-agent 4→3 のフォールバックを搭載）。適用後は CentOS リポジトリ (`CentOS-*`) の mirrorlist/baseurl/arch を vault 固定化し、全 `.repo` の `http://` → `https://` を行ったうえで、`remi-safe`, `remi-php*`, `zabbix`, `zabbix-non-supported` を無効化。最後に `yum update td-agent --disablerepo=* --enablerepo=treasuredata` を実行し、失敗時（RHEL6 のみ）は td-agent 3 リポジトリに書き換えて再実行、未導入であれば `yum install td-agent ...` を追加実行します。`--skip-backup-files` 指定時はリポジトリ書き換えでもバックアップと思しき `.repo` を除外します。
4. **ドライラン** – `As-Is / To-Be` の整形 diff を標準出力と `*_transform_preview.log` に記録。
5. **本適用 (`--apply`)** – 対象件数を提示し、`yes` / `y` 以外はキャンセル。`*.bak_<timestamp>` を生成し、権限・所有者・グループを復元したうえで適用。結果は `*_transform.log` へ保存。
   - `/var/www/com/ipet-ins/<system>/fuel/app/config/` を扱う場合、`newstaging/` に不足ファイルがあっても警告を残したままコピーは実行でき、プロンプトで `yes` を選択すれば `newproduction/` に複製します。

---

## 🛡️ 安全策と除外ルール

- nginx / Apache 設定などの重要ファイルは常に除外。
- 1 回目の `Ctrl+C` で一時ファイルを削除し、メッセージを表示。2 回目の割り込みで強制終了。
- td-agent リポジトリ生成では `curl` の結果を表示し、疎通可否を明示。

---

## 🗃️ ログと生成物

| ファイル | 役割 |
|----------|------|
| `<host>_<timestamp>_current_infra.log` など | スキャン結果（カテゴリ別）。 |
| `<host>_<timestamp>_warnings.log` | 構成不足や疎通失敗の警告。 |
| `<host>_<timestamp>_transform_preview.log` | ドライラン差分。 |
| `<host>_<timestamp>_transform.log` | 本適用結果とバックアップ情報。 |
| `*_YYYYMMDD_HHMM.bak` | `--apply` 時に生成されるバックアップ。 |

`--deletelogs` で `/tmp/<ユーザー>/find_and_extract/` 配下のログを一括削除できます。

---

## 📚 関連ドキュメント

- 📝 運用ガイド (JP): [`docs/FIND_AND_EXTRACT_TOOL.md`](docs/FIND_AND_EXTRACT_TOOL.md)
- 📘 シェル版仕様: [`docs/PROJECT_SPEC_SH.md`](docs/PROJECT_SPEC_SH.md)
- 🧰 td-agent helper: [`generate_td_agent_conf.sh`](generate_td_agent_conf.sh)
- 📦 JSON スキーマ: [`schemas/`](schemas/)

英語版 README は [`README_EN.md`](README_EN.md) です。

---

## 🌐 ローカライズと変更履歴

- 英語 changelog: [`CHANGELOG.md`](CHANGELOG.md)
- 日本語 changelog: [`CHANGELOG_ja.md`](CHANGELOG_ja.md)
- 英語 README: [`README_EN.md`](README_EN.md)

**最新版 (v3.6.4.0 / 2025-11-06)** の主な更新:

- Treasure Data リポジトリ URL と GPG キーを `packages.treasuredata.com` 系へ統一し、403 応答時の警告を強化
- CentOS 系リポジトリ (`CentOS-*`, `.repo`) の mirrorlist/baseurl/basearch を vault 固定化し、`http://` → `https://` に統一
- `remi-safe`, `remi-php*`, `zabbix`, `zabbix-non-supported` のリポジトリを自動無効化し、`yum update td-agent --disablerepo=* --enablerepo=treasuredata`（必要に応じて td-agent 3 へフォールバック＆インストール）を実行
- 編集途中ファイルを対象外とする除外ルールの追加

運用自動化にぜひご活用ください！🚀
