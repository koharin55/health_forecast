# HealthForecast フロントエンドモック

このディレクトリには、HealthForecastアプリケーションのフロントエンドモックが含まれています。

**デザインテーマ**: Organic × Futuristic Wellness
モバイルファーストの入力体験を重視し、未来的でありながら温かみのあるデザインを実現しています。

## 📁 ファイル一覧

| ファイル名 | 説明 |
|-----------|------|
| `dashboard.html` | ダッシュボード（統計サマリー、グラフ表示、最近の記録） |
| `health_records.html` | 健康記録一覧（全記録のテーブル表示、ページネーション） |
| `new_record.html` | 新規記録作成フォーム |
| `detail.html` | 記録詳細表示 |
| `login.html` | ログインページ |
| `signup.html` | 新規登録ページ |

## ✨ デザインハイライト（v2.0）

このモックアップの特徴的なデザイン要素：

- **🎨 独自カラーパレット**: Emerald-Cyan-Amberのグラデーション配色
- **✍️ カスタムフォント**: Outfit（本文） + Space Mono（数値）
- **🌈 Glassmorphism**: 半透明背景 + backdrop-filter blur
- **📱 モバイル最適化**: 44px最小タップ領域、56px入力高さ、inputmode属性
- **🍔 ハンバーガーメニュー**: 768px未満で自動表示
- **🎭 アニメーション**: fadeInUpで段階的表示（0.1s遅延）
- **📊 グラデーショングラフ**: Chart.jsで視覚的魅力向上

## 🎨 デザイン仕様

### カラーパレット
- **プライマリカラー**: Emerald (#10b981) - 健康・成長を象徴
- **セカンダリカラー**: Cyan (#06b6d4) - 清潔さ・未来感
- **アクセントカラー**: Amber (#f59e0b) - 活力・ポジティブ
- **背景**: 3色グラデーションメッシュ（Emerald-Cyan-Amber）
- **テキスト**: Slate-900 (#0f172a) / Slate-600 (#475569)

### フォントシステム
- **メインフォント**: [Outfit](https://fonts.google.com/specimen/Outfit) - モダンで読みやすい幾何学フォント
- **データ表示用**: [Space Mono](https://fonts.google.com/specimen/Space+Mono) - 等幅フォントで数値の視認性が高い
- **ウェイト**:
  - Outfit: 300 (Light), 400 (Regular), 500 (Medium), 600 (Semibold), 700 (Bold), 800 (Extrabold)
  - Space Mono: 400 (Regular), 700 (Bold)

### 体調スコアのカラーコーディング
| スコア | 意味 | カラー | 絵文字 |
|--------|------|--------|--------|
| 5 | とても良い | Emerald グラデーション | 😄 |
| 4 | 良い | Blue グラデーション | 😊 |
| 3 | 普通 | Slate グラデーション | 😐 |
| 2 | 悪い | Orange グラデーション | 😕 |
| 1 | とても悪い | Red グラデーション | 😞 |

### デザイン要素
- **Glassmorphism**: 半透明背景 + backdrop-filter blur効果
- **グラデーション**: 各ボタン・カードに方向性グラデーション適用
- **アニメーション**: fadeInUpエフェクトで段階的に表示（0.1s遅延）
- **シャドウ**: ソフトで大きめの影で浮遊感を演出

## 🛠 技術スタック

- **HTML5**: セマンティックマークアップ
- **Tailwind CSS 3**: ユーティリティファーストCSSフレームワーム（CDN経由）
- **Chart.js 4**: グラフ描画ライブラリ（ダッシュボードのみ、グラデーション塗りつぶし対応）
- **Google Fonts**: Outfit + Space Mono
- **CSS Custom Properties**: カラーテーマの一元管理
- **CSS Animations**: keyframesによる滑らかなページ遷移

## 📱 モバイルファースト設計

このモックアップはスマートフォンでの入力・閲覧を最優先に設計されています。

### タッチターゲット仕様
- **最小タップ領域**: 44×44px（Appleヒューマンインターフェイスガイドライン準拠）
- **入力フィールド高さ**: 56px（誤タップ防止）
- **体調選択ボタン**: モバイル時100px高さ（選択しやすさ重視）

### モバイルUI最適化
- **ハンバーガーメニュー**: 768px未満で自動切り替え
- **カードビューテーブル**: モバイルでは横スクロールの代わりにカード表示
- **2カラムレイアウト**: 統計カード・体調選択を2列配置
- **フォントサイズ**: 最小16px（iOSの自動ズーム防止）
- **inputmode属性**: 数値入力時に適切なキーボード表示（numeric, decimal）

### レスポンシブグリッド
```css
/* モバイル: 2カラム */
grid-template-columns: repeat(2, 1fr)

/* タブレット以上: 4カラム */
@media (min-width: 768px) {
  grid-template-columns: repeat(4, 1fr)
}
```

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

### モバイル表示の確認

**Chrome DevTools使用**:
1. F12キーでDevToolsを開く
2. デバイスツールバーアイコンをクリック（Ctrl+Shift+M）
3. デバイスを「iPhone 14 Pro」などに設定
4. ハンバーガーメニュー、カードビュー、タップ領域を確認

**実機確認（推奨）**:
1. ローカルサーバーを起動
2. スマホを同じWi-Fiに接続
3. PCのIPアドレスを確認（`ipconfig` / `ifconfig`）
4. スマホブラウザで `http://[PCのIP]:8000/dashboard.html` にアクセス

## ⚙️ JavaScript機能

### モバイルメニュートグル
`dashboard.html`、`health_records.html`、`detail.html`に実装：

```javascript
function toggleMobileMenu() {
  const menu = document.getElementById('mobileMenu');
  menu.classList.toggle('active');
}
```

- ハンバーガーアイコンクリックでメニュー開閉
- `active`クラスでスライドイン/アウト
- メニュー外クリックでも閉じる（今後実装予定）

### Chart.js初期化
各グラフで`createLinearGradient()`を使用してグラデーション塗りつぶし：

```javascript
const ctx = document.getElementById('weightChart').getContext('2d');
const gradient = ctx.createLinearGradient(0, 0, 0, 200);
gradient.addColorStop(0, 'rgba(16, 185, 129, 0.3)');
gradient.addColorStop(1, 'rgba(16, 185, 129, 0)');
```

## 📊 ダッシュボードのグラフ

`dashboard.html`には以下の4つのグラフが含まれています：

1. **体重の推移** - 折れ線グラフ（Emerald グラデーション塗りつぶし）
2. **睡眠時間の推移** - 折れ線グラフ（Cyan グラデーション塗りつぶし）
3. **体調スコアの推移** - 折れ線グラフ（Amber グラデーション塗りつぶし）
4. **運動時間の推移** - 棒グラフ（Emerald-Cyan グラデーション）

### グラフ実装の工夫
- **グラデーション塗りつぶし**: `createLinearGradient()`で視覚的魅力向上
- **無限拡大問題の解決**: canvas要素にheight属性を設定せず、親divで高さ制御
- **アニメーション無効化**: `animation: { duration: 0 }`でパフォーマンス向上
- **レスポンシブ対応**: `responsive: true`で画面幅に追従

グラフデータはサンプルデータ（最近7日間）が表示されます。

## 🎯 主な機能

### ナビゲーション
- **デスクトップ**: 横並びナビゲーションバー
- **モバイル**: ハンバーガーメニュー（768px未満で自動切り替え）
  - ダッシュボード
  - 記録一覧
  - 新規記録ボタン
  - ログアウトリンク
- **メニュー制御**: JavaScriptによるトグル機能

### レスポンシブデザイン
- **モバイルファースト**: スマホでの入力体験を最優先
- **ブレークポイント**: 768px（モバイル/デスクトップ境界）
- **適応的レイアウト**:
  - 統計カード: モバイル2列 → デスクトップ4列
  - 記録テーブル: モバイルでカード表示 → デスクトップで表形式
  - 体調選択: モバイル2列 → デスクトップ5列

### インタラクティブ要素
- **ホバーエフェクト**: transformによる上昇 + シャドウ拡大
- **フォーカス状態**: Emeraldカラーのring効果
- **アニメーション**: ページロード時の段階的フェードイン（fadeInUp）
- **体調スコア選択UI**: 大きくタップしやすいボタンデザイン

## 📝 フォームフィールド

### 新規記録フォーム（`new_record.html`）

| フィールド名 | タイプ | 必須 | inputmode | モバイル最適化 |
|------------|--------|------|-----------|--------------|
| recorded_at | date | ✅ | - | 56px高さ、16pxフォント |
| weight | number | - | decimal | 小数点キーボード表示 |
| sleep_hours | number | - | decimal | 小数点キーボード表示 |
| exercise_minutes | number | - | numeric | 数値キーボード表示 |
| steps | number | - | numeric | 数値キーボード表示 |
| heart_rate | number | - | numeric | 数値キーボード表示 |
| mood | radio | - | - | 100px高さボタン（モバイル） |
| notes | textarea | - | - | 56px高さ、自動拡張 |

### モバイル入力最適化
- **inputmode属性**: iOS/Androidで適切なキーボード表示
  - `numeric`: 整数入力（歩数、運動時間、心拍数）
  - `decimal`: 小数入力（体重、睡眠時間）
- **フィールド高さ**: 56px（誤タップ防止）
- **フォントサイズ**: 16px（iOSの自動ズーム回避）
- **保存ボタン配置**: モバイルで最上部（親指で押しやすい）

## 🔐 認証ページ

### ログイン（`login.html`）
- グラデーション背景 + Glassmorphismカード
- 大きなHealthForecastロゴ（グラデーション文字）
- メールアドレス入力
- パスワード入力
- Remember me チェックボックス
- パスワードリセットリンク
- 新規登録へのリンク

### 新規登録（`signup.html`）
- ログインと統一されたデザイン
- メールアドレス入力
- パスワード入力（6文字以上）
- パスワード確認入力
- 利用規約・プライバシーポリシー同意チェックボックス
- ログインへのリンク

### 認証ページのデザイン特徴
- **中央配置レイアウト**: 画面中央に配置、視線誘導
- **Glassmorphismカード**: 半透明白背景 + 20pxぼかし
- **グラデーションロゴ**: Emerald → Cyan の135度グラデーション
- **入力フィールド**: フォーカス時にEmeraldリング表示
- **送信ボタン**: グラデーション背景 + ホバー時の浮上効果

## 🎨 カスタマイズ方法

### 色の変更
CSS Custom Propertiesで一元管理されているため、各ファイルの`:root`セクションで変更可能：

```css
:root {
  --color-primary: #10b981;    /* Emerald */
  --color-secondary: #06b6d4;  /* Cyan */
  --color-accent: #f59e0b;     /* Amber */
}
```

または、Tailwind CSSのクラスを直接変更：

```html
<!-- プライマリカラーを変更 -->
<button class="bg-emerald-600 hover:bg-emerald-700">
  ↓
<button class="bg-purple-600 hover:bg-purple-700">
```

### グラフデータの変更
`dashboard.html`内のJavaScriptセクションでデータを編集：

```javascript
datasets: [{
  label: '体重 (kg)',
  data: [67.0, 66.8, 66.5, 66.2, 66.0, 65.8, 65.5], // ← ここを変更
  backgroundColor: gradient, // グラデーション塗りつぶし
  // ...
}]
```

### アニメーション速度の調整
各ファイルの`@keyframes fadeInUp`セクションで調整：

```css
@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(40px); /* 開始位置 */
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
```

## 📱 レスポンシブブレークポイント

### Tailwind標準ブレークポイント
- **sm**: 640px以上
- **md**: 768px以上（主要な切り替えポイント）
- **lg**: 1024px以上
- **xl**: 1280px以上

### 主なレイアウト変更（768px境界）

#### ナビゲーション
- **モバイル（〜767px）**: ハンバーガーメニュー
- **デスクトップ（768px〜）**: 横並びナビバー

#### 統計カード
- **モバイル**: `grid-cols-2`（2列）
- **デスクトップ**: `md:grid-cols-4`（4列）

#### 記録テーブル
- **モバイル**: カードビュー（縦積み）
- **デスクトップ**: `<table>`形式

#### 体調選択
- **モバイル**: `grid-cols-2`（2列、大きいボタン）
- **デスクトップ**: `md:grid-cols-5`（5列、横一列）

#### ボタン配置
- **モバイル**: 保存ボタンを上部配置（親指リーチ）
- **デスクトップ**: 保存ボタンを右側配置（従来の配置）

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

1. **ERB変換**: HTMLをERBテンプレートに変換
2. **アセット統合**:
   - Google FontsをRailsアセットパイプラインに統合
   - CSS Custom Propertiesを`application.css`に移行
   - JavaScriptをStimulusコントローラーに変換
3. **Chart.js対応**: Turbo Drive対応（`turbo:load`イベントで初期化）
4. **フォーム**:
   - CSRFトークン追加
   - `form_with`ヘルパー使用
   - Strong Parametersで許可リスト設定
5. **データバインディング**: サーバーサイドデータを動的に表示
6. **Tailwind CSS**:
   - `tailwindcss-rails` gem使用
   - `tailwind.config.js`でカスタムカラー定義
7. **モバイルテスト**: 実機でタップ領域・キーボード表示を検証
8. **パフォーマンス**:
   - 画像最適化（WebP形式）
   - フォントサブセット化
   - CSS/JS minify

## 🎯 デザイン原則

### 1. モバイルファースト
スマートフォンでの健康データ入力が主要ユースケース。全てのUI要素をタッチ操作に最適化。

### 2. 視認性重視
- 大きなフォントサイズ（16px以上）
- 高コントラスト配色
- 適切な余白（padding/margin）

### 3. 入力の簡易性
- 最小限のタップ数
- 適切なキーボード表示（inputmode）
- 大きなタップ領域（44px以上）

### 4. 美しさと機能性の両立
- Glassmorphismで軽やかさ
- グラデーションで視線誘導
- アニメーションで心地よいフィードバック

### 5. 一貫性
- 全ページで統一されたカラーパレット
- 共通のコンポーネントデザイン
- 予測可能なナビゲーション

## 📚 参考リソース

- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [Chart.js Documentation](https://www.chartjs.org/docs/)
- [Google Fonts - Outfit](https://fonts.google.com/specimen/Outfit)
- [Google Fonts - Space Mono](https://fonts.google.com/specimen/Space+Mono)
- [Apple Human Interface Guidelines - Touch Targets](https://developer.apple.com/design/human-interface-guidelines/inputs)

---

**作成日**: 2026-02-01
**最終更新**: 2026-02-01
**バージョン**: 2.0.0 - モバイルファースト＆新デザインシステム対応
