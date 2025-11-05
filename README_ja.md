# 🛠️ find_and_extract.sh 日本語 README

`find_and_extract.sh` は、オンプレ／クラウドが混在する運用環境で、STG 向けの設定値を安全に PRD 向けへ変換し、必要に応じてロールバックできるよう設計された Bash スクリプトです。ここでは英語 README の内容を補完しつつ、日本語で最新版の仕様を整理しています。

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
- **想定 OS**: RHEL / CentOS 系（ローカル実行）
- **作業ディレクトリ**: `/tmp/<ユーザー>/find_and_extract/`（自動作成・パーミッション 700）
- **主な成果物**: スキャン結果、差分プレビュー、本番適用ログ、ロールバック用メタデータ

---

## ✨ 主な特長

- サブコマンドでライフサイクルを一括管理:
  - `scan` 🧭 STG / PRD の痕跡を棚卸し
  - `transform` 🔄 置換内容をプレビュー＆適用（バックアップ込み）
  - `rollback` ⏪ バックアップから復元
- `/etc/profile` の自動整備 🧼:
  - STG 用 IP・ホスト名・`stg` トークンを PRD 向けへ置換
  - `http_proxy` / `https_proxy` / `HTTP_PROXY` / `HTTPS_PROXY` を固定ゲートウェイ `http://172.16.162.6:3128/` で追記（未定義時）
- Treasure Data (td-agent) リポジトリ生成 📦:
  - CentOS 6 ⇒ v3 URL、RHEL 7 ⇒ v4 URL、RHEL 9 ⇒ v4 URL を自動判定
  - GPG キーを S3 配布版へ切り替え、`repodata/repomd.xml` に疎通チェック
- 実用的なデフォルト 🙌:
  - `*.save` や `YYYYMMDD` を含むファイル名を除外（エディタ一時ファイル対策）
  - `--apply` 時は必ず確認プロンプトとバックアップを実施

---

## 📂 リポジトリ構成

| パス | 説明 |
|------|------|
| `find_and_extract.sh` | CLI 本体（`scan` / `transform` / `rollback`）。 |
| `CHANGELOG.md` / `CHANGELOG_ja.md` | リリースノート（英語 / 日本語）。 |
| `docs/FIND_AND_EXTRACT_TOOL.md` | 詳細な運用ガイド（日本語）。 |
| `docs/PROJECT_SPEC_SH.md` | シェル版仕様・安全対策のまとめ。 |
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

1. 対象ディレクトリへの読み取り権限を確認する。
2. `/tmp` に十分な空き容量があるか確かめる。
3. Bash 4 以上が利用可能か確認し、`curl` がある場合は疎通確認にも利用。
4. `--apply` 実行時は、同ディレクトリに `*.bak_<timestamp>` バックアップが作成されることを周知しておく。

---

## 🧪 コマンドリファレンス

| サブコマンド | 想定シナリオ | 主な出力 |
|--------------|--------------|----------|
| `scan` | STG / PRD の痕跡を棚卸し（読み取り専用）。 | `<host>_<timestamp>_{current_infra,new_infra_stg,new_infra_prd,other,mixed}.log` |
| `transform` | STG 値を PRD に置換。既定はドライラン。 | `*_transform_preview.log`, `*_transform.log` |
| `rollback` | 変換ログをもとに復元。`--file` で絞り込み可。 | 復元 / 失敗件数のサマリー |

### 主なオプション

- `-v, --verbose` : 詳細進捗を出力（スキップ理由など）。
- `--skip-backup-files` : `*.bak`, `*.old`, `*~`, `.swp` 等を除外。
- `--dry-run` / `--apply` : `transform` 実行モードを指定。
- `--file <path>` : `rollback` で対象を限定。
- `--deletelogs` : `/tmp/<ユーザー>/find_and_extract/` 配下のログを削除。

---

## 🔧 transform ワークフロー

1. **事前チェック**
   - `/var` 配下が対象なら、`fuel/app/config/newproduction/` の有無と必須ファイルを検証し、欠損をワーニングログへ出力。
   - `/etc/nginx/nginx.conf` や `/etc/httpd/httpd.conf` など保護対象は最初から除外。

2. **対象ファイルの抽出**
   - `scan` の仕組みでファイルを列挙しつつ、以下を除外:
     - バイナリ／10 MiB を超えるファイル
     - バックアップファイル（`--skip-backup-files` 時）
     - `*.save` および 8 桁日付 (`YYYYMMDD`) を含むファイル名

3. **変換処理**
   - 組み込み AWK で IP／ホスト名／トークンの置換を実施。
   - `/etc/profile` では STG トークンを PRD 化し、固定プロキシを追記（既存値は尊重）。
   - `/etc/yum.repos.d/td.repo` は OS メジャーバージョンで URL を切り替え、S3 配布の GPG キーへ更新。`curl --head` で `repodata/repomd.xml` の疎通を確認し、結果を標準出力に表示。

4. **ドライラン**
   - `As-Is / To-Be` の整形 diff を標準出力と `*_transform_preview.log` に記録。

5. **本適用 (`--apply`)**
   - 変換対象件数を表示し、`yes` / `y` 以外の入力は無効としてキャンセル。
   - 反映前に `*.bak_<timestamp>` を生成し、パーミッション・所有者・グループを元に戻してから新しい内容を書き込み。結果を `*_transform.log` に追記。

---

## 🛡️ 安全策と除外ルール

- 変更しないファイル: nginx / Apache 設定など重要ファイルをハードコードで保護。
- 変換対象外となる条件:
  - バイナリ判定されたファイル、10 MiB 超のファイル
  - バックアップ風ファイル（`--skip-backup-files` 指定時）
  - `*.save`、`YYYYMMDD` を含むファイル名
- 割り込み対策:
  - 1 回目の `Ctrl+C` で一時ファイルを削除しメッセージ表示。
  - 2 回目で強制終了（追加メッセージを出力）。
- td-agent リポジトリ生成時は `curl` を用いた疎通チェック結果を必ず通知。

---

## 🗃️ ログと生成物

| ファイル | 役割 |
|----------|------|
| `<host>_<timestamp>_current_infra.log` 等 | カテゴリ別スキャン結果。 |
| `<host>_<timestamp>_warnings.log` | 構成不足・疎通エラーの警告。 |
| `<host>_<timestamp>_transform_preview.log` | ドライラン差分の記録。 |
| `<host>_<timestamp>_transform.log` | 本適用で変更したファイルとバックアップ情報。 |
| `*_YYYYMMDD_HHMM.bak` | `--apply` 実行時に作成されるバックアップ。 |

`--deletelogs` オプションで `/tmp/<ユーザー>/find_and_extract/` 配下のログを一括削除できます。

---

## 📚 関連ドキュメント

- 📝 運用ガイド (JP): [`docs/FIND_AND_EXTRACT_TOOL.md`](docs/FIND_AND_EXTRACT_TOOL.md)
- 📘 シェル版仕様: [`docs/PROJECT_SPEC_SH.md`](docs/PROJECT_SPEC_SH.md)
- 🧰 td-agent helper: [`generate_td_agent_conf.sh`](generate_td_agent_conf.sh)
- 📦 JSON スキーマ: [`schemas/`](schemas/)

---

## 🌐 ローカライズと変更履歴

- 英語版 changelog: [`CHANGELOG.md`](CHANGELOG.md)
- 日本語版 changelog: [`CHANGELOG_ja.md`](CHANGELOG_ja.md)
- 英語 README: [`README.md`](README.md)

**最新版 (v3.6.3.0 / 2025-11-05)** では以下を実装:

- `/etc/profile` のプロキシを固定値に統一し、STG トークンを確実に PRD 化。
- Treasure Data リポジトリの URL 切り替えと疎通チェックを自動化。
- 編集途中のファイルを誤って変換しないための除外ルールを追加。

どうぞご活用ください！🚀
