# コーディング規約・スタイルガイド

## 命名規則
- **クラス名**: PascalCase (例: `HealthRecord`)
- **メソッド名・変数名**: snake_case (例: `calculate_average_weight`)
- **定数**: SCREAMING_SNAKE_CASE (例: `MAX_RECORDS_PER_PAGE`)

## インデント
- 2スペース（タブ禁止）
- 1行100文字以内を目安

## モデルの記述順序
```ruby
class ModelName < ApplicationRecord
  # 1. アソシエーション
  belongs_to :user
  has_many :items

  # 2. バリデーション
  validates :column, presence: true

  # 3. スコープ
  scope :recent, -> { order(created_at: :desc) }

  # 4. インスタンスメソッド
  def instance_method
  end

  # 5. クラスメソッド
  def self.class_method
  end
end
```

## プロジェクト固有ルール

### 体調スコア（mood）
- **整数値1-5を使用（Enumは使わない）**
  - 1: とても悪い
  - 2: 悪い
  - 3: 普通
  - 4: 良い
  - 5: とても良い

### 削除方式
- **物理削除を採用**（論理削除は使わない）

### 認可
- HealthRecordは必ず`current_user.health_records`経由でアクセス
```ruby
# 正しい
@health_record = current_user.health_records.find(params[:id])

# 間違い（他人の記録にアクセス可能）
@health_record = HealthRecord.find(params[:id])
```

### バリデーション
- エラーメッセージは日本語
- カスタムバリデーションメソッド名: `validate_カラム名_チェック内容`

### 数値バリデーション範囲
- mood: 1-5（nil許可）
- weight: 0より大きい（nil許可）
- sleep_hours: 0以上（nil許可）
- exercise_minutes: 0以上（nil許可）
- steps: 0以上（nil許可）
- heart_rate: 0以上（nil許可）

## Git コミットメッセージ
- 日本語で記述
- フォーマット: `[種類] 簡潔な説明`

### 種類
- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメント
- `refactor`: リファクタリング

### 例
```bash
git commit -m "[feat] 体調スコアのグラフ表示を追加"
git commit -m "[fix] ダッシュボードの統計計算エラーを修正"
```

## CSSスタイリング規約

### カスタムCSSクラスの使用
Tailwindユーティリティクラスが動作しない場合は、`app/assets/stylesheets/application.css`にカスタムクラスを定義すること。

### プロジェクト固有CSSクラス
- `btn-primary` - プライマリボタン（グラデーション）
- `btn-secondary` - セカンダリボタン（ボーダー）
- `btn-action`, `btn-action-view`, `btn-action-edit`, `btn-action-delete` - テーブルアクションボタン
- `card` - Glassmorphismカード
- `input-field` - 入力フィールド
- `badge-mood-1`〜`badge-mood-5` - 体調バッジ
- `mono` - 数値表示用フォント（Inter）

### フォント規約
- **本文**: Outfit
- **数値**: Inter（`.mono`クラス）
  - 健康データの数値には必ず`.mono`クラスを適用すること
  - 0と8の視認性が高いクリーンな形状
  - 等幅数字設定でテーブル表示が揃う

### サービスクラス規約
- 命名: `XxxService`
- 外部API連携はサービスクラスに切り出す
- サービス固有の例外クラスを定義する
```ruby
class WeatherService
  class Error < StandardError; end
  class ApiError < Error; end
end
```
