importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB-Oo_86VpG_refQU7my0qk10tQFQDU-Fo',
  authDomain: 'presto-app-74abe.firebaseapp.com',
  projectId: 'presto-app-74abe',
  storageBucket: 'presto-app-74abe.firebasestorage.app',
  messagingSenderId: '151421230024',
  appId: '1:151421230024:web:8b83d1d11084c5a02b3efd',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const data = payload.data || {};
  const title = notification.title || 'IliPresto';
  const options = {
    body: notification.body || '',
    data: {
      routeName: data.routeName || '',
      conversationId: data.conversationId || '',
      offerId: data.offerId || '',
    },
  };

  self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const routeName = data.routeName ||
    (data.conversationId ? `/messages/${encodeURIComponent(data.conversationId)}` : '') ||
    (data.offerId ? `/offers/${encodeURIComponent(data.offerId)}` : '') ||
    '/';

  event.waitUntil(
    self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    }).then((clientsArr) => {
      for (const client of clientsArr) {
        if ('focus' in client) {
          client.postMessage({ routeName });
          return client.focus();
        }
      }

      if (self.clients.openWindow) {
        return self.clients.openWindow(routeName);
      }

      return undefined;
    }),
  );
});