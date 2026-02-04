# Rails コーディング規約 (レビュー基準)

## C-01: コントローラ (Controller)
- **Thin Controller**：アクションは、リクエストの受け付け、パラメータの検証、レスポンスの返却のみに集中すること。**ビジネスロジックは、モデルまたはサービスクラスに委譲**すること。
- **リダイレクト**: URLはハードコードせず、常に`*_path`ヘルパーまたは`url_for`ヘルパーを使用すること。
- **Strong Parameters**: パラメータ受け取り時は、必ず`params.require(:model).permit(...)`を使用し、セキュリティを確保すること。

## M-01: モデル (Model)
- **Fat Model**：ビジネスロジック、複雑なバリデーション、DBクエリはモデル層に記述すること。
- **N+1の回避**: データ取得の際は、`includes` や `eager_load` を使用し、N+1クエリを発生させないこと。
- **スコープ**: クエリを再利用可能にするため、可能な限りクラスメソッドではなく `scope` を使用すること。

## S-01: サービスクラス (Service)
- **単一責任**: 1つのサービスクラスは1つの責務のみを持つこと。
- **命名規則**: `XxxService`（例: `WeatherService`, `ZipcodeService`）
- **外部API連携**: 外部APIとの通信はサービスクラスに切り出すこと。
- **エラーハンドリング**: サービス固有の例外クラスを定義し、適切にエラーを伝播すること。
```ruby
class WeatherService
  class Error < StandardError; end
  class ApiError < Error; end
  class TimeoutError < Error; end
end
```

## T-01: テスト (RSpec)
- テストは実装ではなく**振る舞い**をテストすること。
- テストコードは明確なテスト名を持ち、期待されるシナリオを説明すること。
- 外部APIはWebMockでスタブ化すること。

## CSS-01: スタイリング
- **カスタムクラス優先**: Tailwindユーティリティクラスが動作しない場合は、`application.css`にカスタムクラスを定義すること。
- **プロジェクト固有クラス**: `btn-primary`, `btn-secondary`, `btn-action-*`, `card`等のカスタムクラスを使用すること。
- **数値フォント**: 健康データの数値表示には必ず`.mono`クラスを適用すること（Interフォント、視認性重視）。