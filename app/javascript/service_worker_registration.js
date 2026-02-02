// Service Worker Registration with Turbo Drive integration
const SW_PATH = '/service-worker.js';

// Service Workerの登録
async function registerServiceWorker() {
  if (!('serviceWorker' in navigator)) {
    console.log('[SW Registration] Service Workers not supported');
    return null;
  }

  try {
    const registration = await navigator.serviceWorker.register(SW_PATH, {
      scope: '/'
    });

    console.log('[SW Registration] Service Worker registered:', registration.scope);

    // アップデートのチェック
    registration.addEventListener('updatefound', () => {
      const newWorker = registration.installing;
      console.log('[SW Registration] New Service Worker installing...');

      newWorker.addEventListener('statechange', () => {
        if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
          // 新しいバージョンが利用可能
          console.log('[SW Registration] New version available');
          showUpdateNotification();
        }
      });
    });

    return registration;
  } catch (error) {
    console.error('[SW Registration] Registration failed:', error);
    return null;
  }
}

// 更新通知を表示
function showUpdateNotification() {
  // Turboイベントを発火して、UIに通知を表示することも可能
  const event = new CustomEvent('sw:update-available');
  window.dispatchEvent(event);
}

// Turbo Driveとの統合
// Turboのナビゲーション時にService Workerのキャッシュを適切に扱う
function setupTurboIntegration() {
  // 初回のみService Worker状態をログ出力
  let logged = false;
  document.addEventListener('turbo:load', () => {
    if (!logged && navigator.serviceWorker?.controller) {
      console.log('[SW Registration] Page controlled by Service Worker');
      logged = true;
    }
  });

  // Turboのフェッチリクエスト前の処理
  document.addEventListener('turbo:before-fetch-request', (event) => {
    // 認証が必要なリクエストにはキャッシュを使わないようにヘッダーを追加
    const fetchOptions = event.detail.fetchOptions;
    if (fetchOptions && fetchOptions.headers) {
      // Turboのリクエストであることを示すヘッダーは既に設定されている
      // Service Worker側でこれを判断材料に使う
    }
  });

  // オフライン状態の検知
  window.addEventListener('online', () => {
    console.log('[SW Registration] Back online');
    document.body.classList.remove('offline');
  });

  window.addEventListener('offline', () => {
    console.log('[SW Registration] Gone offline');
    document.body.classList.add('offline');
  });

  // 初期状態を設定
  if (!navigator.onLine) {
    document.body.classList.add('offline');
  }
}

// 初期化
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    registerServiceWorker();
    setupTurboIntegration();
  });
} else {
  registerServiceWorker();
  setupTurboIntegration();
}

// グローバルにエクスポート（Stimulusコントローラーから利用可能に）
window.HealthForecastSW = {
  register: registerServiceWorker,

  // Service Worker登録を取得
  async getRegistration() {
    if (!('serviceWorker' in navigator)) return null;
    return navigator.serviceWorker.ready;
  },

  // Push通知の購読状態を取得
  async getPushSubscription() {
    const registration = await this.getRegistration();
    if (!registration) return null;
    return registration.pushManager.getSubscription();
  },

  // Push通知を購読
  async subscribeToPush(vapidPublicKey) {
    const registration = await this.getRegistration();
    if (!registration) {
      throw new Error('Service Worker not registered');
    }

    const subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(vapidPublicKey)
    });

    return subscription;
  },

  // Push通知の購読を解除
  async unsubscribeFromPush() {
    const subscription = await this.getPushSubscription();
    if (subscription) {
      await subscription.unsubscribe();
    }
    return true;
  }
};

// VAPID公開鍵をUint8Arrayに変換
function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - base64String.length % 4) % 4);
  const base64 = (base64String + padding)
    .replace(/-/g, '+')
    .replace(/_/g, '/');

  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);

  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}
