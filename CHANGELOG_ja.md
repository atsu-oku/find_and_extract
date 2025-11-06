# find_and_extract.sh 更新履歴（日本語版）

本書は `find_and_extract.sh` の変更内容を日本語でまとめたものです。同梱の `CHANGELOG.md` と同じ内容を和訳し、最新版の挙動に合わせた補足を含みます。

## v3.6.4.0 - 2025-11-06

- td-agent リポジトリ適用後に `CentOS-*` リポジトリを `https://vault.centos.org` 固定・`$releasever` を取得したメジャーバージョンへ置換・`$basearch` を `x86_64` に固定し、全 `.repo` ファイルの `http://` を `https://` へ統一しました。
- `yum-config-manager` / `dnf config-manager` で `remi-safe`, `remi-php*`, `zabbix`, `zabbix-non-supported` を無効化し、`yum install td-agent --disablerepo=* --enablerepo=treasuredata` を実行（出力は `/tmp/<user>/find_and_extract/td-agent-install.log` に保存）するようにしました。
- ドライラン時にも CentOS 系および一般 `.repo` の書き換え差分を検出し、プレビュー ログで事前確認できるようになりました。

## v3.6.3.0 – 2025-11-05

- `/etc/profile` の変換時に STG 向けトークン（IP / ホスト名 / `stg` 文字列）を PRD 向けへ必ず置換し、プロキシ変数 `http_proxy` / `https_proxy` / `HTTP_PROXY` / `HTTPS_PROXY` を固定値 `http://172.16.162.6:3128/` で追記するようになりました。
- 編集対象から `*.save` やファイル名に 8 桁の日付（例: `20251105`）を含むものを自動で除外し、エディタの一時ファイルを誤って変換しないようにしました。
- Treasure Data (`td-agent`) リポジトリの生成は OS のメジャーバージョンに応じた URL（CentOS6 → `/3/redhat/6/`, RHEL7-9 → `/4/redhat/{7,8,9}/`）を選択し、`https://packages.treasuredata.com/GPG-KEY-td-agent` から GPG キーを取得します。`repodata/repomd.xml` に対する疎通確認も追加されました。

## v3.6.1.0 – 2025-11-04

- `fuel/app/config/newstaging/` を正規の STG データとみなし、直接編集せず、`transform --apply` 実行時に必要であれば `newproduction/` へコピーしてから PRD 置換を行うフローに変更しました。
- `record_transform_failure` を用いた警告・失敗の統一的な記録方式を導入し、同じ欠損を何度も報告しないようバリデーションを整理しました。
- 詳細ログやドキュメントを新しい挙動に合わせて更新しました。

## v3.6.0.0 – 2025-11-04

- `/var/www/com/ipet-ins/<system>/fuel/app/config/` 配下の `newproduction/` および `newstaging/` を検証し、不足があれば警告ログへ出力する仕組みを追加しました。

## v3.5.1.0 – 2025-10-30

- ログ内で検出する STG/PRD マーカーを再分類し、サマリーメッセージも最新の粒度に合わせて刷新しました。

## v3.5.0.0 – 2025-10-30

- バックアップファイル名を `*_YYYYMMDD_HHMM.bak` に統一し、混在定義のログとバックアップファイル検出ロジックを拡張しました。

## それ以前のリリース

- **3.4.x**: ホスト名／IP の検出範囲拡大、コメント行の扱い改善、STG キーワード整備。
- **3.3.0.0**: `transform` サブコマンドを追加（ドライラン既定・確認プロンプト・自動バックアップ）。
- **3.2.x**: 現行基盤検出（IP/ホスト名パターン）の拡充と AWS 除外ロジックの調整。
- **3.1.x**: コメント整備、ローカライズ対応、Rollback 機構の基盤整備。
- **3.0.x 以前**: 公開初期版およびフォーマット修正など。
