# タスク完了時のチェックリスト

## コード変更後の確認事項

### 1. 構文チェック
```bash
# Rubyファイルの構文確認
ruby -c app/path/to/file.rb
```

### 2. マイグレーション
```bash
# 新しいマイグレーションがある場合
rails db:migrate

# 状態確認
rails db:migrate:status
```

### 3. 動作確認
```bash
# 開発サーバー起動
bin/dev

# ブラウザで http://localhost:3000 にアクセス
```

### 4. テスト
```bash
# 全テスト実行
bundle exec rspec

# 特定ファイルのテスト
bundle exec rspec spec/services/weather_service_spec.rb

# 特定行のテスト
bundle exec rspec spec/models/user_spec.rb:42
```

### 5. 外部APIテスト
外部APIを使用する場合は、WebMockでスタブ化すること：
```ruby
stub_request(:get, /api.open-meteo.com/)
  .to_return(status: 200, body: response_json)
```

## コミット前の確認

### 必須確認項目
- [ ] コードがプロジェクトのスタイルガイドに従っている
- [ ] 体調スコア（mood）は整数1-5で実装されている（Enumではない）
- [ ] HealthRecordのアクセスは`current_user.health_records`経由
- [ ] エラーメッセージは日本語
- [ ] 物理削除のみ使用

### コミット
```bash
# 変更確認
git status
git diff

# コミット（日本語で記述）
git add <files>
git commit -m "[種類] 説明"
```

## 新機能追加時の追加確認

### ルーティング
```bash
rails routes -c controller_name
```

### ビュー
- Tailwind CSSクラスが正しく適用されているか
- レスポンシブデザインが考慮されているか

### セキュリティ
- Strong Parametersが設定されているか
- 認可チェック（`current_user.health_records`経由）が実装されているか
