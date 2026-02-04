# HealthForecast 設計ドキュメント

## 目次
1. [共通事項](#共通事項)
2. [機能仕様](#機能仕様)
3. [データベース設計](#データベース設計)
4. [API仕様](#API仕様)
5. [将来の拡張](#将来の拡張)

---

## 共通事項

### 命名規則
- **テーブル名**: 複数形、snake_case（例: `health_records`）
- **カラム名**: snake_case（例: `recorded_at`）
- **モデル名**: 単数形、PascalCase（例: `HealthRecord`）
- **コントローラー名**: 複数形、PascalCase + Controller（例: `HealthRecordsController`）

### フォント
| 用途 | フォント | CSSクラス | 備考 |
|------|----------|-----------|------|
| 本文 | Outfit | （デフォルト） | モダンで読みやすいサンセリフ |
| 数値 | Inter | `.mono` | 0と8の視認性が高い、等幅数字対応 |

**数値フォント（Inter）の適用ルール：**
- 健康データの数値（体重、血圧、心拍数、体温、睡眠時間等）には必ず`.mono`クラスを適用
- テーブル・カード内の数値表示に使用
- `font-feature-settings: 'tnum'`で等幅数字を有効化済み

### 標準カラム
全テーブルに以下のカラムが自動付与される：
- `id`: 主キー（integer、自動採番）
- `created_at`: 作成日時（datetime、NOT NULL）
- `updated_at`: 更新日時（datetime、NOT NULL）

### 削除方式
- **物理削除**を採用
- Userが削除されると、関連するHealthRecordも削除される（`dependent: :destroy`）

### 認証
- **Devise gem** を使用
- パスワード最小文字数: 6文字

---

## 機能仕様

### 1. ユーザー認証
- Devise gemによる標準的な認証機能
  - ユーザー登録
  - ログイン/ログアウト
  - パスワードリセット
  - Remember me機能

### 2. ダッシュボード
- **統計サマリー**: 総記録数、最新の体重・体調スコア
- **グラフ表示**（最近7日間のデータ）:
  - 体重の推移（折れ線グラフ）
  - 睡眠時間の推移（折れ線グラフ）
  - 体調スコアの推移（折れ線グラフ）
  - 運動時間の推移（棒グラフ）
- **最近の記録一覧**: 最新7件をテーブル表示

### 3. 健康記録管理
- **一覧表示**: 全記録を記録日降順で表示（天候情報含む）
- **詳細表示**: 個別記録の全データ表示（天候情報含む）
- **新規作成**: 健康データの入力（デフォルト記録日: 今日、天候自動取得）
- **編集**: 既存記録の修正（所有者のみ）
- **削除**: 物理削除（所有者のみ、確認ダイアログ付き）

### 4. 天候情報連携
- **地域設定**: 都道府県選択または郵便番号入力
- **天候自動取得**: 健康記録保存時にOpen-Meteo APIから取得
- **表示データ**: 気温、湿度、気圧、天気（アイコン+説明）
- **過去データ補完**: 92日以内の記録に天候データをバックフィル可能

### 5. 体調スコアのカラーコーディング
| スコア | 意味 | 色 |
|-------|------|-----|
| 5 | とても良い | 緑 |
| 4 | 良い | 青 |
| 3 | 普通 | 黄 |
| 2 | 悪い | オレンジ |
| 1 | とても悪い | 赤 |

---

## データベース設計

### ER図

```
┌──────────────────┐
│      users       │
├──────────────────┤
│ email            │
│ encrypted_       │
│  password        │
│ latitude         │
│ longitude        │
│ location_name    │
└──────────────────┘
       │ 1
       │
       │ has_many
       │ (dependent: :destroy)
       │
       ▼ *
┌──────────────────┐
│  health_records  │
├──────────────────┤
│ user_id (FK)     │
│ recorded_at      │
│ weight           │
│ sleep_hours      │
│ exercise_minutes │
│ mood             │
│ notes            │
│ steps            │
│ heart_rate       │
│ systolic_pressure│
│ diastolic_       │
│  pressure        │
│ body_temperature │
│ weather_         │
│  temperature     │
│ weather_humidity │
│ weather_pressure │
│ weather_code     │
│ weather_         │
│  description     │
└──────────────────┘
```

---

### テーブル定義

#### usersテーブル

| カラム名 | 型 | NULL | デフォルト | 制約 | 説明 |
|---------|-----|------|-----------|------|------|
| email | string | NO | "" | UNIQUE | メールアドレス |
| encrypted_password | string | NO | "" | - | 暗号化パスワード |
| reset_password_token | string | YES | NULL | UNIQUE | パスワードリセットトークン |
| reset_password_sent_at | datetime | YES | NULL | - | リセット送信日時 |
| remember_created_at | datetime | YES | NULL | - | Remember me作成日時 |
| latitude | decimal(10,7) | YES | NULL | - | 緯度（地域設定） |
| longitude | decimal(10,7) | YES | NULL | - | 経度（地域設定） |
| location_name | string | YES | NULL | - | 地域名（表示用） |

**インデックス**:
- `email` (UNIQUE)
- `reset_password_token` (UNIQUE)

**バリデーション**:
- email: 必須、メール形式、一意性
- password: 必須（新規作成時）、6文字以上

**メソッド**:
- `location_configured?`: 地域が設定済みかどうか
- `set_location_from_prefecture(code)`: 都道府県コードから地域設定
- `set_location_from_zipcode(zipcode)`: 郵便番号から地域設定

---

#### health_recordsテーブル

| カラム名 | 型 | NULL | デフォルト | 制約 | 説明 |
|---------|-----|------|-----------|------|------|
| user_id | integer | NO | - | FK | ユーザーID |
| recorded_at | date | NO | - | - | 記録日 |
| weight | decimal | YES | NULL | - | 体重（kg） |
| sleep_hours | decimal | YES | NULL | - | 睡眠時間（時間） |
| exercise_minutes | integer | YES | NULL | - | 運動時間（分） |
| mood | integer | YES | NULL | - | 体調スコア（1-5） |
| notes | text | YES | NULL | - | メモ |
| steps | integer | YES | NULL | - | 歩数 |
| heart_rate | integer | YES | NULL | - | 心拍数（bpm） |
| systolic_pressure | integer | YES | NULL | - | 収縮期血圧（mmHg） |
| diastolic_pressure | integer | YES | NULL | - | 拡張期血圧（mmHg） |
| body_temperature | decimal(4,1) | YES | NULL | - | 体温（℃） |
| weather_temperature | decimal(4,1) | YES | NULL | - | 天気: 気温（℃） |
| weather_humidity | integer | YES | NULL | - | 天気: 湿度（%） |
| weather_pressure | decimal(6,1) | YES | NULL | - | 天気: 気圧（hPa） |
| weather_code | integer | YES | NULL | - | 天気: WMOコード |
| weather_description | string | YES | NULL | - | 天気: 説明 |

**インデックス**:
- `user_id`

**外部キー**:
- `user_id` → `users.id`

**バリデーション**:
- `recorded_at`: 必須
- `mood`: 1-5の範囲（nilを許可）
- `weight`: 0より大きい数値（nilを許可）
- `sleep_hours`: 0以上の数値（nilを許可）
- `exercise_minutes`: 0以上の整数（nilを許可）
- `steps`: 0以上の整数（nilを許可）
- `heart_rate`: 0以上の整数（nilを許可）
- `systolic_pressure`: 0以上の整数（nilを許可）
- `diastolic_pressure`: 0以上の整数（nilを許可）
- `body_temperature`: 0以上の数値（nilを許可）

**体調スコア（mood）**:
※ Enumは使用せず、整数値1-5で管理

| 値 | 意味 |
|----|------|
| 1 | とても悪い |
| 2 | 悪い |
| 3 | 普通 |
| 4 | 良い |
| 5 | とても良い |

**スコープ**:
- `recent`: 記録日の降順でソート
- `for_user(user)`: 特定ユーザーの記録を取得

**メソッド**:
- `has_weather_data?`: 天候データが存在するか
- `weather_icon`: 天気コードに対応するアイコン絵文字
- `fetch_and_set_weather!`: 天候データを取得して設定

---

## API仕様

### ルーティング

| メソッド | パス | アクション | 用途 | 認証 |
|---------|------|----------|------|------|
| GET | / | home#index | ダッシュボード | 必須 |
| GET | /users/sign_in | devise/sessions#new | ログイン画面 | - |
| POST | /users/sign_in | devise/sessions#create | ログイン処理 | - |
| DELETE | /users/sign_out | devise/sessions#destroy | ログアウト | 必須 |
| GET | /users/sign_up | devise/registrations#new | 新規登録画面 | - |
| POST | /users | devise/registrations#create | 新規登録処理 | - |
| GET | /health_records | health_records#index | 記録一覧 | 必須 |
| GET | /health_records/new | health_records#new | 新規記録フォーム | 必須 |
| POST | /health_records | health_records#create | 新規記録作成 | 必須 |
| GET | /health_records/:id | health_records#show | 記録詳細 | 必須 |
| GET | /health_records/:id/edit | health_records#edit | 記録編集フォーム | 必須 |
| PATCH/PUT | /health_records/:id | health_records#update | 記録更新 | 必須 |
| DELETE | /health_records/:id | health_records#destroy | 記録削除 | 必須 |
| GET | /settings | settings#show | 設定画面 | 必須 |
| PATCH | /settings | settings#update | 地域設定更新 | 必須 |
| POST | /settings/search_zipcode | settings#search_zipcode | 郵便番号検索 | 必須 |
| POST | /settings/backfill_weather | settings#backfill_weather | 過去天候データ取得 | 必須 |

### アクセス制御
- 全ページで認証必須（`authenticate_user!`）
- HealthRecordは所有者のみアクセス可能（`current_user.health_records.find`）

### Strong Parameters
```ruby
health_record_params:
  - recorded_at
  - weight
  - sleep_hours
  - exercise_minutes
  - mood
  - notes
  - steps
  - heart_rate
```

---

## 将来の拡張

### フェーズ2: PWA化・天候連携（完了）
- ✅ Service Worker
- ✅ プッシュ通知
- ✅ 天候情報連携（Open-Meteo API）
- ✅ 地域設定機能

### フェーズ3: AI機能
- Claude API連携
- 天候データと体調の相関分析
- 体調予測（天気予報連携）
- パーソナライズされたアドバイス

### フェーズ4: HealthKit連携
- iOSアプリ開発
- Apple HealthKitからのデータ自動取得
- Apple Watchデータ同期

### 追加検討機能
- データエクスポート（CSV、PDF）
- 月次/年次レポート
- 目標設定
- リマインダー
- データ共有（家族、医師）
- 気圧変化アラート

---

## 外部API仕様

### Open-Meteo API（天候データ）
- **エンドポイント**: `https://api.open-meteo.com/v1/forecast`
- **認証**: 不要（無料）
- **制限**: 10,000リクエスト/日
- **取得データ**: 気温、湿度、気圧、天気コード
- **過去データ**: 92日前まで取得可能

### Zipcloud API（郵便番号検索）
- **エンドポイント**: `https://zipcloud.ibsnet.co.jp/api/search`
- **認証**: 不要（無料）
- **用途**: 郵便番号から住所・緯度経度を取得

---

**更新日**: 2026-02-04
**バージョン**: 1.1.0 (天候連携)
