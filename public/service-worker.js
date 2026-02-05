// PreCare Service Worker
const CACHE_VERSION = 'v1';
const STATIC_CACHE_NAME = `precare-static-${CACHE_VERSION}`;
const DYNAMIC_CACHE_NAME = `precare-dynamic-${CACHE_VERSION}`;

// 静的アセット（Cache First戦略）
const STATIC_ASSETS = [
  '/offline.html',
  '/manifest.json',
  '/icons/icon-192x192.png',
  '/icons/icon-512x512.png'
];

// キャッシュするCDNドメイン
const CDN_DOMAINS = [
  'cdn.jsdelivr.net',
  'fonts.googleapis.com',
  'fonts.gstatic.com'
];

// Install: 静的アセットをキャッシュ
self.addEventListener('install', (event) => {
  console.log('[SW] Installing Service Worker...');
  event.waitUntil(
    caches.open(STATIC_CACHE_NAME)
      .then((cache) => {
        console.log('[SW] Caching static assets');
        return cache.addAll(STATIC_ASSETS);
      })
      .then(() => self.skipWaiting())
  );
});

// Activate: 古いキャッシュを削除
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating Service Worker...');
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames
            .filter((cacheName) => {
              return (cacheName.startsWith('precare-') || cacheName.startsWith('healthforecast-')) &&
                     cacheName !== STATIC_CACHE_NAME &&
                     cacheName !== DYNAMIC_CACHE_NAME;
            })
            .map((cacheName) => {
              console.log('[SW] Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            })
        );
      })
      .then(() => self.clients.claim())
  );
});

// Fetch: リクエストに応じたキャッシュ戦略
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // POSTリクエストや認証が必要なAPIはキャッシュしない
  if (request.method !== 'GET') {
    return;
  }

  // API リクエスト: Network Only（認証必須）
  if (url.pathname.startsWith('/api/') ||
      url.pathname.startsWith('/users/') ||
      url.pathname.startsWith('/health_records')) {
    event.respondWith(networkOnly(request));
    return;
  }

  // 静的アセット（JS/CSS）: Cache First
  if (isStaticAsset(url)) {
    event.respondWith(cacheFirst(request));
    return;
  }

  // CDN: Stale While Revalidate
  if (isCdnRequest(url)) {
    event.respondWith(staleWhileRevalidate(request));
    return;
  }

  // HTML（ナビゲーション）: Network First
  if (request.mode === 'navigate' || request.headers.get('accept')?.includes('text/html')) {
    event.respondWith(networkFirst(request));
    return;
  }

  // その他: Network First
  event.respondWith(networkFirst(request));
});

// キャッシュ戦略: Cache First
async function cacheFirst(request) {
  const cachedResponse = await caches.match(request);
  if (cachedResponse) {
    return cachedResponse;
  }

  try {
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      const cache = await caches.open(STATIC_CACHE_NAME);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    console.log('[SW] Cache First failed:', error);
    return new Response('Offline', { status: 503 });
  }
}

// キャッシュ戦略: Network First
async function networkFirst(request) {
  try {
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      const cache = await caches.open(DYNAMIC_CACHE_NAME);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    console.log('[SW] Network First: falling back to cache');
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }
    // オフラインページを返す
    if (request.mode === 'navigate') {
      return caches.match('/offline.html');
    }
    return new Response('Offline', { status: 503 });
  }
}

// キャッシュ戦略: Network Only
async function networkOnly(request) {
  try {
    return await fetch(request);
  } catch (error) {
    console.log('[SW] Network Only failed:', error);
    return new Response(JSON.stringify({ error: 'Offline' }), {
      status: 503,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}

// キャッシュ戦略: Stale While Revalidate
async function staleWhileRevalidate(request) {
  const cache = await caches.open(DYNAMIC_CACHE_NAME);
  const cachedResponse = await cache.match(request);

  const fetchPromise = fetch(request).then((networkResponse) => {
    if (networkResponse.ok) {
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  }).catch(() => cachedResponse);

  return cachedResponse || fetchPromise;
}

// ヘルパー関数
function isStaticAsset(url) {
  return url.pathname.match(/\.(js|css|png|jpg|jpeg|gif|svg|ico|woff|woff2)$/i) ||
         url.pathname.startsWith('/assets/');
}

function isCdnRequest(url) {
  return CDN_DOMAINS.some(domain => url.hostname.includes(domain));
}

// Push通知の受信
self.addEventListener('push', (event) => {
  console.log('[SW] Push received');

  let data = { title: 'PreCare', body: '新しい通知があります' };

  if (event.data) {
    try {
      data = event.data.json();
    } catch (e) {
      data.body = event.data.text();
    }
  }

  const options = {
    body: data.body,
    icon: '/icons/icon-192x192.png',
    badge: '/icons/icon-72x72.png',
    vibrate: [100, 50, 100],
    data: {
      url: data.url || '/',
      dateOfArrival: Date.now()
    },
    actions: data.actions || []
  };

  event.waitUntil(
    self.registration.showNotification(data.title, options)
  );
});

// 通知クリック時の処理
self.addEventListener('notificationclick', (event) => {
  console.log('[SW] Notification clicked');
  event.notification.close();

  const urlToOpen = event.notification.data?.url || '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // 既存のウィンドウがあればフォーカス
        for (const client of clientList) {
          if (client.url.includes(self.location.origin) && 'focus' in client) {
            client.navigate(urlToOpen);
            return client.focus();
          }
        }
        // なければ新しいウィンドウを開く
        if (clients.openWindow) {
          return clients.openWindow(urlToOpen);
        }
      })
  );
});

// 通知を閉じた時の処理
self.addEventListener('notificationclose', (event) => {
  console.log('[SW] Notification closed');
});
