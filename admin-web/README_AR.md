# لوحة الأدمن (ويب) - SpeedStar

هذه لوحة ويب موحدة لإدارة كل النظام بدون إنشاء تطبيق جديد.

## الميزات
- تسجيل دخول بالبريد/كلمة المرور عبر Firebase Auth.
- حارس صلاحية Admin عبر:
  - قائمة بريد ثابتة داخل `firebase-config.js`.
  - أو مستند Firestore في `admins/{uid}` يحتوي `role=admin` أو `active=true`.
- تبويبات موحدة:
  - اللوحة: إحصاءات فورية + أحدث الطلبات.
  - المالية: مؤشرات الدفع والتحويلات.
  - الإدارة: إدارة المتاجر والمندوبين.
  - الدعم الفني: تذاكر `supportTickets` وإغلاقها.
  - طلبات التسجيل: المندوبين/المتاجر المعلقة.

## التشغيل المحلي
1. انسخ الملف:
   - `admin-web/js/firebase-config.example.js` -> `admin-web/js/firebase-config.js`
2. ضع مفاتيح Firebase الحقيقية داخل `firebase-config.js`.
3. شغّل استضافة محلية:
   - `firebase emulators:start --only hosting`
   - أو `firebase serve --only hosting`

## النشر
- `firebase deploy --only hosting`

## ملاحظات مهمة
- هذه النسخة تتخلص من أكواد Flutter القديمة غير الضرورية للأدمن وتبقي الوظائف الأساسية فقط.
- إذا لم يكن لديك collection باسم `supportTickets`، أنشئه من التطبيقات الثلاثة لإرسال رسائل الدعم بشكل موحّد.
- يفضّل لاحقًا إضافة Firestore Rules مخصصة لمسؤول النظام فقط.
