// انسخ هذا الملف إلى firebase-config.js وضع مفاتيح مشروعك.
export const firebaseConfig = {
  apiKey: 'YOUR_API_KEY',
  authDomain: 'YOUR_PROJECT.firebaseapp.com',
  projectId: 'YOUR_PROJECT_ID',
  storageBucket: 'YOUR_PROJECT.appspot.com',
  messagingSenderId: 'YOUR_SENDER_ID',
  appId: 'YOUR_APP_ID'
};

// يسمح بالدخول إذا البريد موجود هنا أو إذا document admins/{uid} موجود role=admin.
export const staticAdminEmails = ['admin@speedstar.com'];
