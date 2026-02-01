# HealthForecast デザイン実装計画

## 概要

モックアップのデザイン（Organic × Futuristic Wellness）を既存のRailsアプリケーションに適用します。

**現在の状態:**
- Rails 7.1.6、Devise認証、HealthRecordモデル完成
- 基本的なCRUD機能実装済み
- Chartkickによる基本グラフ表示
- シンプルなTailwind CSSスタイル（Blue系）

**目標:**
- Emerald-Cyan-Amberグラデーション配色
- Glassmorphism + アニメーション
- モバイルファースト（44px tap targets, 56px inputs, inputmode）
- Chart.jsグラデーショングラフ
- レスポンシブナビゲーション（ハンバーガーメニュー）

---

## タスク一覧

### フェーズ1: デザイン基盤（優先度: 高）

**1-1. CSS基盤構築**
- ファイル: `app/assets/stylesheets/application.css`
- 作業内容:
  - CSS Custom Properties定義（`--color-primary: #10b981`等）
  - `.card`クラス（glassmorphism: 半透明背景 + backdrop-filter blur）
  - `.btn-primary`クラス（Emerald→Cyanグラデーション）
  - `.logo`クラス（グラデーションテキスト）
  - `.mono`クラス（Space Monoフォント）
  - Mood badge classes（`.badge-mood-1`〜`.badge-mood-5`）
  - `@keyframes fadeInUp`アニメーション定義
  - Mobile menu用スタイル（`.mobile-menu.active`）

**1-2. レイアウト変換**
- ファイル: `app/views/layouts/application.html.erb`
- 作業内容:
  - Google Fonts追加（Outfit + Space Mono）
  - Body背景：3色グラデーションメッシュ + radial overlay（::before）
  - ナビゲーションバー：
    - Glassmorphism適用
    - デスクトップ：横並びリンク
    - モバイル：ハンバーガーボタン（768px未満）
  - モバイルメニュー追加（`#mobileMenu`）
  - アラート通知のスタイル更新
  - フッター：glassmorphismカード化

**1-3. モバイルメニューJS**
- ファイル: `app/javascript/controllers/mobile_menu_controller.js`（新規作成）
- 作業内容:
  - Stimulusコントローラー作成
  - `toggle()`アクション実装
  - Turbo Drive対応

---

### フェーズ2: ダッシュボード変換（優先度: 高）

**2-1. 統計カード更新**
- ファイル: `app/views/home/index.html.erb`
- 作業内容:
  - 4枚のカードをglassmorphismデザインに
  - グリッド：`grid-cols-2 md:grid-cols-4`
  - アイコン背景グラデーション円
  - Space Monoフォントで数値表示
  - staggeredアニメーション（0.1s, 0.2s, 0.3s, 0.4s遅延）
  - カード内容：総記録数、最新体重、最新体調、平均睡眠

**2-2. Chart.js置き換え**
- ファイル: `app/views/home/index.html.erb`
- 作業内容:
  - Chartkickの`line_chart`/`column_chart`を削除
  - Chart.js用`<canvas>`要素追加
  - グラデーション塗りつぶし実装：
    - 体重グラフ：Emeraldグラデーション
    - 睡眠グラフ：Cyanグラデーション
    - 体調グラフ：Amberグラデーション（y軸1-5固定）
    - 運動グラフ：棒グラフ、Emerald-Cyanグラデーション
  - `turbo:load`イベントで初期化
  - 親div高さ固定（height: 250px）でcanvas無限拡大防止
  - `animation: { duration: 0 }`でパフォーマンス向上

**2-3. 最近の記録テーブル**
- ファイル: `app/views/home/index.html.erb`
- 作業内容:
  - モバイル：カードビュー（`md:hidden`）
  - デスクトップ：テーブルビュー（`hidden md:block`）
  - Mood値を絵文字+バッジで表示

---

### フェーズ3: フォーム変換（優先度: 高）

**3-1. フォーム入力最適化**
- ファイル: `app/views/health_records/_form.html.erb`
- 作業内容:
  - 全体をglassmorphismカードでラップ
  - 入力フィールド更新：
    - クラス：`.input-field`
    - `min-height: 56px`
    - `font-size: 16px`（iOS自動ズーム防止）
    - `inputmode`属性追加：
      - weight: `inputmode="decimal"`
      - sleep_hours: `inputmode="decimal"`
      - exercise_minutes, steps, heart_rate: `inputmode="numeric"`
  - テキストエリア（notes）：56px高さ

**3-2. 体調セレクター変換**
- ファイル: `app/views/health_records/_form.html.erb`
- 作業内容:
  - `select`ドロップダウンを削除
  - ラジオボタングリッドに置き換え
  - グリッド：`grid-cols-2 md:grid-cols-5`
  - 各オプション：100px高さ（モバイル）、絵文字 + テキスト
  - 絵文字：😞(1), 😕(2), 😐(3), 😊(4), 😄(5)
  - 隠しradio input + 視覚的label

**3-3. ボタンレイアウト**
- ファイル: `app/views/health_records/_form.html.erb`
- 作業内容:
  - モバイル：縦並び、保存ボタン上部
  - デスクトップ：横並び、保存ボタン右側
  - 保存ボタン：`.btn-primary`グラデーション
  - キャンセルボタン：ボーダースタイル

**3-4. ヘルパーメソッド**
- ファイル: `app/helpers/health_records_helper.rb`
- 作業内容:
  - `mood_emoji(score)`: スコア→絵文字
  - `mood_text(score)`: スコア→日本語テキスト
  - `mood_badge_class(score)`: スコア→CSSクラス

---

### フェーズ4: 記録一覧・詳細（優先度: 中）

**4-1. 記録一覧のレスポンシブ化**
- ファイル: `app/views/health_records/index.html.erb`
- 作業内容:
  - モバイル：カードビュー（各記録をカード表示、2x2グリッド）
  - デスクトップ：テーブルビュー（既存構造）
  - Moodバッジをグラデーション化
  - Glassmorphismカード適用

**4-2. 記録詳細ページ**
- ファイル: `app/views/health_records/show.html.erb`
- 作業内容:
  - Glassmorphismカードレイアウト
  - メトリクスカードグリッド
  - Space Monoで数値表示
  - Moodグラデーションバッジ

---

### フェーズ5: 認証ページ（優先度: 中）

**5-1. Deviseビュー生成**
- コマンド: `rails g devise:views`

**5-2. ログインページ**
- ファイル: `app/views/devise/sessions/new.html.erb`
- 作業内容:
  - 中央配置レイアウト + グラデーション背景
  - Glassmorphismカード
  - 大きなグラデーションロゴ
  - 56px入力フィールド
  - グラデーション送信ボタン

**5-3. 新規登録ページ**
- ファイル: `app/views/devise/registrations/new.html.erb`
- 作業内容: ログインと同様のデザイン

---

### フェーズ6: テストデータ・検証（優先度: 低）

**6-1. シードデータ作成**
- ファイル: `db/seeds.rb`
- 作業内容:
  - テストユーザー作成（`test@example.com` / `password`）
  - 30日分のHealthRecord作成
  - ランダムデータ（体重減少トレンド、睡眠・運動・体調変動）

**6-2. 動作確認**
- デスクトップブラウザ確認（Chrome/Firefox）
- モバイルDevTools確認（iPhone 14 Pro 393x852）
- 実機確認（推奨）
- Turbo Drive動作確認（ページ遷移時のChart.js再描画）

---

## 重要ファイル一覧

### 変更するファイル（11ファイル）

1. `app/assets/stylesheets/application.css` - デザインシステム全体
2. `app/views/layouts/application.html.erb` - レイアウト・ナビゲーション
3. `app/views/home/index.html.erb` - ダッシュボード
4. `app/views/health_records/_form.html.erb` - フォーム
5. `app/views/health_records/new.html.erb` - 新規作成
6. `app/views/health_records/edit.html.erb` - 編集
7. `app/views/health_records/index.html.erb` - 一覧
8. `app/views/health_records/show.html.erb` - 詳細
9. `app/helpers/health_records_helper.rb` - ヘルパー
10. `db/seeds.rb` - テストデータ
11. Deviseビュー（`rails g devise:views`後）

### 新規作成ファイル（1ファイル）

1. `app/javascript/controllers/mobile_menu_controller.js` - モバイルメニュー

### 変更しないファイル

- Models（User, HealthRecord） - バリデーション・アソシエーション完成済み
- Controllers（Home, HealthRecords） - 認可ロジック正しい
- Routes - 適切に設定済み
- Database schema - 変更不要

---

## 技術的決定事項

### Chart.js実装方法
**決定: インラインスクリプト + turbo:load**
- 理由: モックアップと同じパターン、実装が速い、デバッグしやすい
- 将来的にStimulusコントローラー化も可能

### CSS管理方法
**決定: application.css + CSS Custom Properties**
- 理由: Glassmorphism、アニメーション、カスタムクラスに必要
- Tailwind CDN使用のため、tailwind.config.js不要

### モバイルメニュー
**決定: Stimulusコントローラー**
- 理由: Turbo Drive互換性、Rails慣習、状態管理が明確

### Mood入力UI
**決定: ラジオボタングリッド（selectから変更）**
- 理由: モバイルUX大幅向上、視認性、大きなタップ領域

### レスポンシブテーブル
**決定: HTML二重化（モバイルカード + デスクトップテーブル）**
- 理由: 構造が明確、メンテナンス性、アクセシビリティ

---

## 実装順序（推奨）

### Day 1: 基盤構築
1. CSS基盤（application.css）
2. レイアウト変換（グラデーション背景、ナビ）
3. モバイルメニューJS

### Day 2: ダッシュボード
4. 統計カード更新
5. Chart.js実装

### Day 3: フォーム
6. 入力フィールド最適化
7. 体調セレクター変換
8. ヘルパーメソッド

### Day 4: 一覧・詳細
9. 記録一覧レスポンシブ化
10. 詳細ページ更新

### Day 5: 認証
11. Deviseビュー生成・カスタマイズ

### Day 6: 検証
12. シードデータ、動作確認

---

## 検証方法

### 1. デスクトップ確認
```bash
bin/dev
# http://localhost:3000 にアクセス
```
- [ ] ナビゲーション表示
- [ ] ダッシュボードグラフ描画
- [ ] フォーム入力・送信
- [ ] 記録一覧・詳細表示

### 2. モバイルDevTools確認
- [ ] Chrome DevTools → iPhone 14 Pro（393x852）
- [ ] ハンバーガーメニュー動作
- [ ] 体調セレクターグリッド（2列）
- [ ] 統計カード（2列）
- [ ] 記録カードビュー
- [ ] タップ領域サイズ（44px以上）

### 3. 実機確認（推奨）
```bash
# PCのIPアドレス確認
ifconfig  # macOS/Linux
ipconfig  # Windows

# スマホから http://[PCのIP]:3000 にアクセス
```
- [ ] inputmode属性によるキーボード表示
- [ ] タッチ操作の快適さ
- [ ] パフォーマンス（アニメーション、blur）

### 4. Turbo Drive確認
- [ ] ページ遷移後のChart.js再描画
- [ ] モバイルメニュー状態リセット
- [ ] アニメーション再実行

### 5. シードデータでグラフ確認
```bash
rails db:seed
# ログイン: test@example.com / password
```
- [ ] 30日分のデータでグラフ表示
- [ ] グラデーション塗りつぶし確認

---

## 注意事項

### モバイル最適化
- 入力フィールド: `font-size: 16px`（iOS自動ズーム防止）
- タップ領域: 最小44x44px
- inputmode属性: 適切なキーボード表示

### パフォーマンス
- Chart.js: `animation: { duration: 0 }`でパフォーマンス向上
- backdrop-filter: Safari用プレフィックス（`-webkit-backdrop-filter`）

### Turbo Drive互換性
- Chart.js: `turbo:load`イベントで初期化
- 既存Chart.jsインスタンス破棄してから再作成

### アクセシビリティ
- ラジオボタン: 隠しinput + 視覚的label
- sr-onlyクラスでスクリーンリーダー対応
- キーボードナビゲーション確認

---

## 完成イメージ

- **ダッシュボード**: グラデーション背景、glassmorphismカード、Chart.jsグラフ、モバイルカードビュー
- **フォーム**: 大きなタップ領域、2列体調セレクター、適切なキーボード
- **ナビゲーション**: デスクトップ横並び、モバイルハンバーガー
- **全体**: Emerald-Cyan-Amber配色、Outfit+Space Monoフォント、滑らかなアニメーション
