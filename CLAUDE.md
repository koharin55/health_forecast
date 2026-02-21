# PreCare 開発ガイド

健康管理アプリ「PreCare」の開発を効率化するためのコマンドリファレンスとプロジェクト固有のルールをまとめたドキュメント。

---

## 目次

0. [ワークフロー](#ワークフロー)
1. [クイックスタート](#クイックスタート)
2. [よく使うコマンド](#よく使うコマンド)
3. [プロジェクト固有ルール](#プロジェクト固有ルール)
4. [コーディング規約](#コーディング規約)
5. [トラブルシューティング](#トラブルシューティング)

---

# Role
あなたは熟練したRuby on Railsエンジニアです。
SOLID原則、Rails Way、およびTDD（テスト駆動開発）に従い、保守性が高く安全なコードを書きます。

## ワークフロー
あなたは、以下のステップを実行します。

## Step 1: タスク受付と準備
1.  ユーザーから **GitHub Issue 番号**を受け付けたらフロー開始です。`/create-gh-branch` カスタムコマンドを実行し、Issueの取得とブランチを作成します。
2.  Issueの内容を把握し、関連するコードを調査します。調査時にはSerenaMCPの解析結果を利用してください。

## Step 2: 実装計画の策定と承認
1.  分析結果に基づき、実装計画を策定します。
2.  計画をユーザーに提示し、承認を得ます。**承認なしに次へ進んではいけません。**

## Step 3: 実装・レビュー・修正サイクル
1.  承認された計画に基づき、実装を行います。
2.  実装完了後、** `rails-reviewer` サブエージェントを呼び出し、コードレビューを実行させます。**
3.  実装内容とレビュー結果をユーザーに報告します。
4.  **【ユーザー承認】**: 報告書を提示し、承認を求めます。
    -   `yes`: コミットして完了。
    -   `fix`: 指摘に基づき修正し、再度レビューからやり直す。

# Rules
以下のルールは、あなたの行動を規定する最優先事項およびガイドラインです。

## 重要・最優先事項 (CRITICAL)
- **ユーザー承認は絶対**: いかなる作業も、ユーザーの明示的な承認なしに進めてはいけません。
- **品質の担保**: コミット前には必ずテスト(`rspec`)を実行し、全てパスすることを確認してください。
- **効率と透明性**: 作業に行き詰まった場合、同じ方法で3回以上試行することはやめてください。
- **SerenaMCP必須**: コードベースの調査・分析には必ずSerenaMCPを使用すること。`Read`ツールでソースファイル全体を読み込むことは禁止。

## SerenaMCP 使用ガイド
コード解析は必ず以下のツールを使用してください。

| ツール | 用途 | 使用例 |
|--------|------|--------|
| `find_symbol` | クラス・メソッドの検索、シンボルの定義取得 | 特定メソッドの実装を確認したいとき |
| `get_symbols_overview` | ファイル内のシンボル一覧を取得 | ファイル構造を把握したいとき |
| `find_referencing_symbols` | シンボルの参照箇所を検索 | メソッドがどこから呼ばれているか調べるとき |
| `search_for_pattern` | 正規表現でコード検索 | 特定パターンの使用箇所を探すとき |

### 禁止事項
- ❌ `Read`ツールでソースファイル(.rb)全体を読み込む
- ❌ 目的なくファイル内容を取得する
- ❌ SerenaMCPで取得可能な情報を他の方法で取得する

## 基本理念 (PHILOSOPHY)
- **大きな変更より段階的な進捗**: テストを通過する小さな変更を積み重ねる。
- **シンプルさが意味すること**: クラスやメソッドは単一責任を持つ（Single Responsibility）。

## 技術・実装ガイドライン
- **実装プロセス (TDD)**: Red -> Green -> Refactor のサイクルを厳守する。
- **アーキテクチャ**: Fat Model, Skinny Controller を心がける。
- **完了の定義**:
    - [ ] テストが通っている
    - [ ] RuboCopのエラーがない
    - [ ] Railsアプリが正常に動作する

## クイックスタート

```bash
# 初回セットアップ
bundle install
rails db:create db:migrate

# 開発サーバー起動（Tailwind CSS自動コンパイル付き）
bin/dev

# ブラウザで http://localhost:3000 にアクセス
```

---

## よく使うコマンド

### サーバー起動

```bash
# Tailwind CSS自動コンパイル付き（推奨）
bin/dev

# 通常起動
rails s

# ポート指定
rails s -p 3001

# サーバー停止（バックグラウンド起動時）
kill -9 $(cat tmp/pids/server.pid)
```

### データベース

```bash
# マイグレーション実行
rails db:migrate

# ロールバック
rails db:rollback

# データベースリセット（開発時）
rails db:reset

# コンソール起動
rails c

# サンドボックスモード（変更を保存しない）
rails c --sandbox
```

### ジェネレーター

```bash
# モデル生成
rails g model HealthRecord user:references recorded_at:date weight:decimal

# コントローラー生成
rails g controller Home index

# マイグレーション生成
rails g migration AddColumnToHealthRecords column_name:type

# 取り消し
rails destroy model ModelName
```

### Devise

```bash
# Devise初期化
rails g devise:install

# Userモデル生成
rails g devise User

# ビューのカスタマイズ
rails g devise:views
```

### ルーティング

```bash
# ルート一覧
rails routes

# 特定のコントローラーのみ
rails routes -c health_records

# 特定のパスを検索
rails routes -g health_record
```

### アセット

```bash
# Tailwind CSSビルド
rails tailwindcss:build

# Tailwind CSS監視モード
rails tailwindcss:watch

# 本番用プリコンパイル
RAILS_ENV=production rails assets:precompile
```

### その他

```bash
# Railsタスク一覧
rails -T

# スキーマダンプ
rails db:schema:dump

# 秘密鍵生成
rails secret

# Credentials編集
EDITOR="vim" rails credentials:edit
```

---

## プロジェクト固有ルール

### データ設計

#### 体調スコア（mood）
**必ず整数値1-5を使用。Enum化しない。**

| 値 | 意味 | 用途 |
|----|------|------|
| 1 | very_bad | とても悪い |
| 2 | bad | 悪い |
| 3 | normal | 普通 |
| 4 | good | 良い |
| 5 | very_good | とても良い |

```ruby
# 正しい使い方
health_record.mood = 5

# 間違った使い方（Enumは使わない）
# health_record.mood = :very_good
```

#### 削除方式
- **物理削除**を採用（論理削除は使わない）
- Userが削除されると、関連するHealthRecordも削除される

```ruby
# User削除時の挙動
user.destroy  # → 関連するhealth_recordsも全削除
```

#### 記録日のデフォルト値
- 新規作成時は「今日」をデフォルトに設定

```ruby
# コントローラーで設定
@health_record = current_user.health_records.new(recorded_at: Date.today)
```

### バリデーション
- エラーメッセージは日本語で記述
- 例: `presence: { message: 'を入力してください' }`

#### カスタムバリデーション
- メソッド名: validate_カラム名_チェック内容
- 例: `validate_published_at_presence`

#### 必須項目
- `recorded_at`: 必須（アプリケーションレベル）

#### 数値範囲
- `mood`: 1-5の範囲（nilを許可）
- `weight`: 0より大きい数値（nilを許可）
- `sleep_hours`: 0以上（nilを許可）
- `exercise_minutes`: 0以上（nilを許可）
- `steps`: 0以上（nilを許可）
- `heart_rate`: 0以上（nilを許可）
- `systolic_pressure`: 0以上（nilを許可）
- `diastolic_pressure`: 0以上（nilを許可）
- `body_temperature`: 0以上（nilを許可）

### サービスクラス

#### 命名規則
- クラス名: `XxxService`（例: `WeatherService`, `ZipcodeService`）
- 配置: `app/services/`

#### 外部API連携
- 外部APIとの通信はサービスクラスに切り出す
- サービス固有の例外クラスを定義する

```ruby
class WeatherService
  class Error < StandardError; end
  class ApiError < Error; end
  class TimeoutError < Error; end
end
```

#### 現在のサービスクラス
- `WeatherService`: Open-Meteo APIから天候データを取得
- `ZipcodeService`: Zipcloud APIから郵便番号→住所変換
- `AiReportService`: Gemini APIで週次ヘルスレポートを生成
- `HealthRecordImportService`: CSVインポート処理
- `HealthRecordExportService`: CSVエクスポート処理

### 認証・認可

#### 認証
- 全コントローラーで `authenticate_user!` を設定
- ApplicationControllerに `before_action :authenticate_user!`

#### 認可
- HealthRecordは所有者のみアクセス可能

```ruby
# 正しいスコープ
@health_record = current_user.health_records.find(params[:id])

# 間違ったスコープ（他人の記録にアクセス可能になる）
# @health_record = HealthRecord.find(params[:id])
```

---

## コーディング規約

### 命名規則

```ruby
# クラス名: PascalCase
class HealthRecord < ApplicationRecord

# メソッド名・変数名: snake_case
def calculate_average_weight
  total_weight = 0
end

# 定数: SCREAMING_SNAKE_CASE
MAX_RECORDS_PER_PAGE = 50
```

### モデルの記述順序

```ruby
class HealthRecord < ApplicationRecord
  # 1. アソシエーション
  belongs_to :user

  # 2. バリデーション
  validates :recorded_at, presence: true
  validates :mood, inclusion: { in: 1..5, allow_nil: true }

  # 3. スコープ
  scope :recent, -> { order(recorded_at: :desc) }

  # 4. インスタンスメソッド
  def mood_text
    # ...
  end

  # 5. クラスメソッド
  def self.average_mood
    # ...
  end
end
```

### インデント
- 2スペース（タブ禁止）
- 1行100文字以内を目安

### CSSスタイリング
- Tailwindユーティリティクラスが動作しない場合は`application.css`にカスタムクラスを定義
- プロジェクト固有クラスを優先使用:
  - `btn-primary`, `btn-secondary` - ボタン
  - `btn-action-*` - テーブルアクションボタン
  - `card` - Glassmorphismカード
  - `input-field` - 入力フィールド
  - `badge-mood-*` - 体調バッジ
  - `mono` - 数値表示用フォント

### フォント
- **本文**: Outfit（メインフォント）
- **数値**: Inter（`.mono`クラスを使用）
  - 0と8の視認性が高くクリーンな形状
  - 等幅数字（tnum）設定でテーブル表示が揃う
  - 健康データの数値表示に必ず使用すること

```erb
<%# 数値表示の例 %>
<span class="mono"><%= record.weight %></span>
```

### Git コミットメッセージ
- コミットは日本語で記述

```bash
# フォーマット
[種類] 簡潔な説明

# 種類
# feat: 新機能
# fix: バグ修正
# docs: ドキュメント
# refactor: リファクタリング

# 例
git commit -m "[feat] 体調スコアのグラフ表示を追加"
git commit -m "[fix] ダッシュボードの統計計算エラーを修正"
```

---

## テスト規約
- テストは必ず書く（RSpec）

### テストの構成順序
1. 正常系（有効なケース）
2. 異常系（無効なケース）
3. 境界値（制限値付近のケース）

### ファクトリ
- デフォルトは最小限の有効な状態
- バリエーションはtraitで定義

## トラブルシューティング

### サーバーが起動しない

```bash
# ポート3000が使用中
lsof -ti:3000 | xargs kill -9

# 別ポートで起動
rails s -p 3001

# Springの問題
spring stop
```

### マイグレーションエラー

```bash
# 状態確認
rails db:migrate:status

# 特定バージョンまで戻す
rails db:migrate:down VERSION=20260131044741

# 開発環境のリセット（データ全削除）
rails db:reset
```

### Tailwind CSSが反映されない

```bash
# 再ビルド
rails tailwindcss:build

# bin/devで起動（自動コンパイル）
bin/dev
```

### Gemインストール失敗

```bash
# Bundlerバージョン確認
bundle -v

# Gemfile.lock削除して再インストール
rm Gemfile.lock
bundle install
```

### Deviseエラー

```bash
# ルート確認
rails routes | grep devise

# ビュー生成（カスタマイズ時）
rails g devise:views

# secret_key_base未設定エラー
EDITOR="vim" rails credentials:edit
```

### データベースロック（SQLite）

```bash
# サーバー停止
# Ctrl + C

# コンソール終了
# exit

# データベースリセット
rails db:migrate:redo
```

### Renderデプロイ失敗

```bash
# exit code 126 → bin/配下の実行権限が欠落
# 原因: git操作（改行コード正規化等）で権限が644に変わることがある
chmod +x bin/*
git add bin/
git commit -m "[fix] bin/配下の実行権限を復元"

# テスト環境のマイグレーション未実行
# rspec実行時に「Migrations are pending」エラーが出る場合
RAILS_ENV=test rails db:migrate
```

### Git: 改行コード・ファイル権限のトラブル

```bash
# bin/配下の改行コード正規化時の注意点
# git rm --cached → git add で正規化すると実行権限(755→644)が外れる場合がある
# 必ず正規化後に権限を確認すること
ls -la bin/
chmod +x bin/*  # 必要に応じて権限を復元
```

---

## 環境変数

### 開発環境
```bash
# config/credentials.yml.enc を使用
EDITOR="vim" rails credentials:edit
```

### 本番環境
```bash
export SECRET_KEY_BASE=$(rails secret)
export RAILS_ENV=production
```

---

**最終更新**: 2026-02-21
**バージョン**: 1.2.0
