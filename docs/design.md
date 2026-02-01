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
- **一覧表示**: 全記録を記録日降順で表示
- **詳細表示**: 個別記録の全データ表示
- **新規作成**: 健康データの入力（デフォルト記録日: 今日）
- **編集**: 既存記録の修正（所有者のみ）
- **削除**: 物理削除（所有者のみ、確認ダイアログ付き）

### 4. 体調スコアのカラーコーディング
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
┌──────────────┐
│    users     │
├──────────────┤
│ email        │
│ encrypted_   │
│  password    │
└──────────────┘
       │ 1
       │
       │ has_many
       │ (dependent: :destroy)
       │
       ▼ *
┌──────────────┐
│health_records│
├──────────────┤
│ user_id (FK) │
│ recorded_at  │
│ weight       │
│ sleep_hours  │
│ exercise_    │
│  minutes     │
│ mood         │
│ notes        │
│ steps        │
│ heart_rate   │
└──────────────┘
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

**インデックス**:
- `email` (UNIQUE)
- `reset_password_token` (UNIQUE)

**バリデーション**:
- email: 必須、メール形式、一意性
- password: 必須（新規作成時）、6文字以上

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

**Enum定義（mood）**:
| 値 | 定数名 | 意味 |
|----|--------|------|
| 1 | very_bad | とても悪い |
| 2 | bad | 悪い |
| 3 | normal | 普通 |
| 4 | good | 良い |
| 5 | very_good | とても良い |

**スコープ**:
- `recent`: 記録日の降順でソート
- `for_user(user)`: 特定ユーザーの記録を取得

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

### フェーズ2: PWA化
- Service Worker
- オフライン対応
- プッシュ通知

### フェーズ3: AI機能
- Claude API連携
- 体調予測
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

---

**更新日**: 2026-01-31
**バージョン**: 1.0.0 (MVP)
