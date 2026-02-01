# HealthForecast フロントエンドモック

このディレクトリには、HealthForecastアプリケーションのフロントエンドモックが含まれています。

## 📁 ファイル一覧

| ファイル名 | 説明 |
|-----------|------|
| `dashboard.html` | ダッシュボード（統計サマリー、グラフ表示、最近の記録） |
| `health_records.html` | 健康記録一覧（全記録のテーブル表示、ページネーション） |
| `new_record.html` | 新規記録作成フォーム |
| `detail.html` | 記録詳細表示 |
| `login.html` | ログインページ |
| `signup.html` | 新規登録ページ |

## 🎨 デザイン仕様

### カラーパレット
- **プライマリカラー**: Blue (#2563EB)
- **背景**: Gray-50 (#F9FAFB)
- **テキスト**: Gray-900 (#111827)

### 体調スコアのカラーコーディング
| スコア | 意味 | カラー | 絵文字 |
|--------|------|--------|--------|
| 5 | とても良い | 緑 (Green) | 😄 |
| 4 | 良い | 青 (Blue) | 😊 |
| 3 | 普通 | 黄 (Yellow) | 😐 |
| 2 | 悪い | オレンジ (Orange) | 😕 |
| 1 | とても悪い | 赤 (Red) | 😞 |

### フォント
- システムフォントスタック（Tailwind CSSデフォルト）

## 🛠 技術スタック

- **HTML5**: セマンティックマークアップ
- **Tailwind CSS 3**: ユーティリティファーストCSSフレームワーク（CDN経由）
- **Chart.js 4**: グラフ描画ライブラリ（ダッシュボードのみ）

## 🚀 使い方

### ブラウザで直接開く

```bash
# ダッシュボードを開く
open mockup/dashboard.html

# または
firefox mockup/dashboard.html
google-chrome mockup/dashboard.html
```

### ローカルサーバーで開く（推奨）

```bash
# Pythonの場合
cd mockup
python3 -m http.server 8000

# Node.jsの場合（npx使用）
cd mockup
npx serve

# ブラウザで http://localhost:8000/dashboard.html にアクセス
```

## 📊 ダッシュボードのグラフ

`dashboard.html`には以下の4つのグラフが含まれています：

1. **体重の推移** - 折れ線グラフ
2. **睡眠時間の推移** - 折れ線グラフ
3. **体調スコアの推移** - 折れ線グラフ
4. **運動時間の推移** - 棒グラフ

グラフデータはサンプルデータ（最近7日間）が表示されます。

## 🎯 主な機能

### ナビゲーション
- ダッシュボード
- 記録一覧
- 新規記録ボタン
- ログアウトリンク

### レスポンシブデザイン
- モバイル、タブレット、デスクトップに対応
- グリッドレイアウトで自動調整
- テーブルは横スクロール対応

### インタラクティブ要素
- ホバーエフェクト
- フォーカス状態のハイライト
- 体調スコア選択UI（ラジオボタンのカスタムデザイン）

## 📝 フォームフィールド

### 新規記録フォーム（`new_record.html`）

| フィールド名 | タイプ | 必須 | 備考 |
|------------|--------|------|------|
| recorded_at | date | ✅ | 記録日（デフォルト: 今日） |
| weight | number | - | 体重（kg、小数点第1位まで） |
| sleep_hours | number | - | 睡眠時間（時間、0.5単位） |
| exercise_minutes | number | - | 運動時間（分） |
| steps | number | - | 歩数 |
| heart_rate | number | - | 心拍数（bpm） |
| mood | radio | - | 体調スコア（1-5） |
| notes | textarea | - | メモ |

## 🔐 認証ページ

### ログイン（`login.html`）
- メールアドレス
- パスワード
- Remember me チェックボックス
- パスワードリセットリンク

### 新規登録（`signup.html`）
- メールアドレス
- パスワード（6文字以上）
- パスワード確認
- 利用規約同意チェックボックス

## 🎨 カスタマイズ方法

### 色の変更
Tailwind CSSのクラスを変更することで簡単にカスタマイズ可能：

```html
<!-- プライマリカラーを変更 -->
<button class="bg-blue-600 hover:bg-blue-700">
  ↓
<button class="bg-purple-600 hover:bg-purple-700">
```

### グラフデータの変更
`dashboard.html`内のJavaScriptセクションでデータを編集：

```javascript
datasets: [{
  label: '体重 (kg)',
  data: [67.0, 66.8, 66.5, 66.2, 66.0, 65.8, 65.5], // ← ここを変更
  // ...
}]
```

## 📱 レスポンシブブレークポイント

- **sm**: 640px以上
- **md**: 768px以上
- **lg**: 1024px以上
- **xl**: 1280px以上

## 🔗 ページ間リンク

現在のモックはすべて静的HTMLのため、ページ間のリンクは相対パスで設定されています。

```
dashboard.html ←→ health_records.html ←→ detail.html
       ↓                    ↓
  new_record.html      new_record.html
       ↓
  login.html ←→ signup.html
```

## ⚠️ 注意事項

1. **JavaScriptの動作**: 削除ボタンやフォーム送信は実際には動作しません（モックアップのため）
2. **データ永続化**: データは保存されません
3. **認証機能**: ログイン/ログアウトは見た目のみです

## 🚧 今後の実装

実際のRailsアプリケーションに組み込む際は：

1. HTMLをERBテンプレートに変換
2. Chart.jsの初期化をTurboと互換性を持たせる
3. フォームにCSRFトークンを追加
4. データをサーバーサイドから動的に取得
5. Tailwind CSSをRails統合版に変更

---

**作成日**: 2026-02-01
**バージョン**: 1.0.0
