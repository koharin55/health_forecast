# HealthForecast プロジェクト概要

## 目的
健康データ（体調、体重、睡眠時間、運動時間、歩数、心拍数、血圧、体温など）を記録・管理するWebアプリケーション。

## 技術スタック
- **言語**: Ruby 3.2.0
- **フレームワーク**: Rails 7.1.6
- **データベース**: SQLite3
- **認証**: Devise
- **フロントエンド**: 
  - Tailwind CSS（スタイリング）
  - Hotwire (Turbo + Stimulus)
  - Importmap（JavaScript管理）
- **グラフ表示**: Chartkick + Groupdate

## データモデル
### User
- Deviseによる認証
- has_many :health_records
- 地域設定カラム:
  - latitude (decimal): 緯度
  - longitude (decimal): 経度
  - location_name (string): 地域名

### HealthRecord
- belongs_to :user
- 主なカラム:
  - recorded_at (date): 記録日
  - weight (decimal): 体重
  - sleep_hours (decimal): 睡眠時間
  - exercise_minutes (integer): 運動時間
  - mood (integer): 体調スコア（1-5）
  - steps (integer): 歩数
  - heart_rate (integer): 心拍数
  - systolic_pressure (integer): 収縮期血圧
  - diastolic_pressure (integer): 拡張期血圧
  - body_temperature (decimal): 体温
  - notes (text): メモ
- 天候カラム（自動取得）:
  - weather_temperature (decimal): 気温
  - weather_humidity (integer): 湿度
  - weather_pressure (decimal): 気圧
  - weather_code (integer): WMO天気コード
  - weather_description (string): 天気説明

## ルーティング構造
- `/users/sign_in` - ログイン（未認証時のルート）
- `/` - ダッシュボード（認証済みルート）
- `/health_records` - 記録一覧（CRUD）
- `/settings` - 設定（地域設定、天候バックフィル）

## サービスクラス
- `WeatherService` - Open-Meteo APIから天候データ取得
- `ZipcodeService` - 郵便番号から住所・緯度経度取得

## ファイル構造
```
app/
├── controllers/
│   ├── application_controller.rb
│   ├── home_controller.rb           # ダッシュボード
│   ├── health_records_controller.rb # 記録CRUD
│   └── settings_controller.rb       # 設定（地域・天候）
├── models/
│   ├── user.rb
│   └── health_record.rb
├── services/
│   ├── weather_service.rb           # 天候API連携
│   └── zipcode_service.rb           # 郵便番号検索
└── views/
    ├── home/
    ├── health_records/
    ├── settings/
    └── shared/
        └── _weather_card.html.erb   # 天気表示パーシャル
```
