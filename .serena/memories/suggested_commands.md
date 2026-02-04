# 推奨コマンド一覧

## 開発サーバー
```bash
# 開発サーバー起動（Tailwind CSS自動コンパイル付き、推奨）
bin/dev

# 通常起動
rails s

# ポート指定
rails s -p 3001

# サーバー停止（バックグラウンド起動時）
kill -9 $(cat tmp/pids/server.pid)
```

## データベース
```bash
# マイグレーション実行
rails db:migrate

# ロールバック
rails db:rollback

# データベースリセット（開発時）
rails db:reset

# マイグレーション状態確認
rails db:migrate:status
```

## コンソール
```bash
# Railsコンソール起動
rails c

# サンドボックスモード（変更を保存しない）
rails c --sandbox
```

## ジェネレーター
```bash
# モデル生成
rails g model ModelName column:type

# マイグレーション生成
rails g migration AddColumnToTable column:type

# コントローラー生成
rails g controller ControllerName action
```

## ルーティング
```bash
# ルート一覧
rails routes

# 特定コントローラーのルート
rails routes -c health_records
```

## アセット
```bash
# Tailwind CSSビルド
rails tailwindcss:build

# Tailwind CSS監視モード
rails tailwindcss:watch
```

## システムユーティリティ (Linux)
```bash
# ファイル検索
find . -name "*.rb"

# テキスト検索
grep -r "pattern" .

# ディレクトリ一覧
ls -la

# ポート確認
lsof -ti:3000
```

## テスト
```bash
# 全テスト実行
bundle exec rspec

# 特定ファイルのテスト
bundle exec rspec spec/services/weather_service_spec.rb

# フォーマット指定（進捗表示）
bundle exec rspec --format progress

# 失敗したテストのみ再実行
bundle exec rspec --only-failures
```

## トラブルシューティング
```bash
# ポート3000が使用中
lsof -ti:3000 | xargs kill -9

# Springの問題
spring stop

# データベースロック解消
rails db:migrate:redo
```
