// Required by Firebase Web Push so the browser can deliver notifications
// while the BuzzCart tab isn't focused (or is closed). This config must
// mirror lib/core/notifications/firebase_web_options.dart exactly — update
// both together.
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'REPLACE_WITH_WEB_API_KEY',
  appId: 'REPLACE_WITH_WEB_APP_ID',
  messagingSenderId: '1063811069935',
  projectId: 'buzzcart-mig01',
  authDomain: 'buzzcart-mig01.firebaseapp.com',
  storageBucket: 'buzzcart-mig01.firebasestorage.app',
});

// The "notification" payload in each push is displayed by the browser
// automatically; no onBackgroundMessage handler is needed unless the
// notification's content needs to be customized further.
firebase.messaging();
