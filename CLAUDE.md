# HealthForecast 開発ガイド

開発を効率化するためのコマンドリファレンスとプロジェクト固有のルールをまとめたドキュメント。

---

## 目次

1. [クイックスタート](#クイックスタート)
2. [よく使うコマンド](#よく使うコマンド)
3. [プロジェクト固有ルール](#プロジェクト固有ルール)
4. [コーディング規約](#コーディング規約)
5. [トラブルシューティング](#トラブルシューティング)

---

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

#### 必須項目
- `recorded_at`: 必須（アプリケーションレベル）

#### 数値範囲
- `mood`: 1-5の範囲（nilを許可）
- `weight`: 0より大きい数値（nilを許可）
- `sleep_hours`: 0以上（nilを許可）
- `exercise_minutes`: 0以上（nilを許可）
- `steps`: 0以上（nilを許可）
- `heart_rate`: 0以上（nilを許可）

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

### Git コミットメッセージ

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

**最終更新**: 2026-01-31
**バージョン**: 1.0.0
