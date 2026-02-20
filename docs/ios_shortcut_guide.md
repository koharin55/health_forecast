# iOSショートカット連携ガイド

PreCareのAPIを使って、iOSの「ショートカット」アプリからヘルスケアデータを自動送信する方法を説明します。

## 前提条件

- iOS 16以降（iOS 26推奨）
- PreCareアカウント（APIトークン生成済み）
- iPhoneの「ヘルスケア」アプリにデータが記録されていること

## APIトークンの取得

1. PreCareにログイン
2. マイページ → 「API連携」セクションを開く
3. 「トークンを生成」をタップ
4. 表示されたトークンをコピー（**このトークンは一度しか表示されません**）

## サンプルショートカットのインポート

管理者がiCloudリンクを用意している場合は、リンクからショートカットをインポートできます。
インポート時に以下の質問に回答してください:

1. **APIトークン**: マイページで生成したトークン
2. **サーバーURL**: PreCareのURL（デフォルト値が設定されている場合はそのままでOK）

## 手動でショートカットを作成する

### Step 1: 新規ショートカット作成

「ショートカット」アプリを開き、右上の「+」から新しいショートカットを作成します。

### Step 2: ヘルスケアデータの取得

「ヘルスケアサンプルを検索」アクションを6回追加し、それぞれ以下のように設定します:

| 種類 | グループ化 | ソート順 | 制限 |
|------|-----------|---------|------|
| 体重 | なし | 開始日（新しい順） | 1件 |
| 歩数 | なし | 開始日（新しい順） | 1件 |
| 心拍数 | なし | 開始日（新しい順） | 1件 |
| 最高血圧 | なし | 開始日（新しい順） | 1件 |
| 最低血圧 | なし | 開始日（新しい順） | 1件 |
| 体温 | なし | 開始日（新しい順） | 1件 |

> **ヒント**: 各アクションの出力（マジック変数）をタップ → 「名前を変更」でわかりやすい名前を付けると、後の手順で識別しやすくなります。

### Step 3: 手入力データのアクション追加

「入力を要求」アクションを2つ追加します:

- **体調スコア**: プロンプト「今日の体調は？(1:とても悪い〜5:とても良い)」、入力タイプ「数字」
- **メモ**: プロンプト「メモ（任意）」、入力タイプ「テキスト」

### Step 4: APIリクエストの送信

「URLの内容を取得」アクションを追加し、以下のように設定します:

- **URL**: `https://your-domain.com/api/v1/health_records`
- **方法**: POST
- **ヘッダー**:
  - `Authorization`: `Bearer あなたのAPIトークン`
- **本文**: JSON

JSONのキーと値:

| キー | 値（マジック変数） |
|------|------------------|
| `health_record[recorded_at]` | 現在の日付（yyyy-MM-dd形式） |
| `health_record[weight]` | 体重データの値 |
| `health_record[steps]` | 歩数データの値 |
| `health_record[heart_rate]` | 心拍数データの値 |
| `health_record[systolic_pressure]` | 最高血圧データの値 |
| `health_record[diastolic_pressure]` | 最低血圧データの値 |
| `health_record[body_temperature]` | 体温データの値 |
| `health_record[mood]` | 体調スコア入力の値 |
| `health_record[notes]` | メモ入力の値 |

### Step 5: 通知の表示

「通知を表示」アクションを追加し、送信完了を確認できるようにします。

### Step 6: オートメーション設定（任意）

毎日自動で実行するには、「オートメーション」タブで:

1. 「+」→「時刻」を選択
2. 実行時刻を設定（例: 毎日 22:00）
3. 「すぐに実行」を選択
4. 作成したショートカットを選択

> **注意**: 「入力を要求」アクションを含む場合、自動実行時にはプロンプトが表示されます。完全自動化したい場合はStep 3を省略してください。

## APIリファレンス

### エンドポイント

```
POST /api/v1/health_records
```

### 認証

Bearer Token認証:

```
Authorization: Bearer <APIトークン>
```

### パラメータ

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| `health_record[recorded_at]` | date | **必須** | 記録日（yyyy-MM-dd形式） |
| `health_record[weight]` | decimal | 任意 | 体重（kg） |
| `health_record[mood]` | integer | 任意 | 体調スコア（1-5） |
| `health_record[sleep_hours]` | decimal | 任意 | 睡眠時間 |
| `health_record[exercise_minutes]` | integer | 任意 | 運動時間（分） |
| `health_record[steps]` | integer | 任意 | 歩数 |
| `health_record[heart_rate]` | integer | 任意 | 心拍数（bpm） |
| `health_record[systolic_pressure]` | integer | 任意 | 最高血圧（mmHg） |
| `health_record[diastolic_pressure]` | integer | 任意 | 最低血圧（mmHg） |
| `health_record[body_temperature]` | decimal | 任意 | 体温 |
| `health_record[notes]` | text | 任意 | メモ |

### curlコマンド例

```bash
curl -X POST https://your-domain.com/api/v1/health_records \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "health_record": {
      "recorded_at": "2026-02-20",
      "weight": 65.5,
      "mood": 4,
      "steps": 8000,
      "heart_rate": 72,
      "systolic_pressure": 120,
      "diastolic_pressure": 80,
      "body_temperature": 36.5,
      "notes": "今日は調子が良い"
    }
  }'
```

### レスポンス例

**成功時 (201 Created)**:
```json
{
  "status": "success",
  "health_record": {
    "id": 1,
    "recorded_at": "2026-02-20",
    "weight": "65.5",
    "mood": 4,
    ...
  }
}
```

**エラー時 (422 Unprocessable Entity)**:
```json
{
  "status": "error",
  "errors": ["記録日を入力してください"]
}
```

## トラブルシューティング

| エラー | 原因 | 対処法 |
|--------|------|--------|
| 401 Unauthorized | APIトークンが無効 | マイページでトークンを確認・再生成 |
| 422 Unprocessable Entity | バリデーションエラー | recorded_atの日付形式やmoodの範囲を確認 |
| ヘルスケアデータ取得不可 | アクセス権限が未許可 | 設定 → プライバシー → ヘルスケア → ショートカットで許可 |
| 同日の重複送信 | — | 同じ日付の記録は自動的に更新されるため問題なし |
