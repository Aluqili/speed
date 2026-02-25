# نشر Cloud Functions (تعيين مندوب + مهلة 40 ثانية)

## ما الذي أضيف؟
- `onOrderWorkflow`: يراقب الطلبات، وإذا صارت الحالة `courier_searching` يبدأ تعيين مندوب.
- `handleCourierOfferTimeouts`: مجدول كل دقيقة، ينهي العروض المنتهية (40 ثانية) ويعيد الإسناد تلقائيًا.
- `courierRespondToOffer` (Callable): قبول/رفض العرض من المندوب بشكل آمن.

## ملفات الإعداد
- [firebase.json](firebase.json)
- [functions/package.json](functions/package.json)
- [functions/index.js](functions/index.js)

## قبل النشر
1. ثبت Firebase CLI:
   - `npm i -g firebase-tools`
2. سجل دخول:
   - `firebase login`
3. اربط المشروع:
   - `firebase use --add`

## تثبيت واعتماد الدوال
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

## ملاحظات مهمة
- الدوال تستخدم الحالات الجديدة:
  - `courier_searching`
  - `courier_offer_pending`
  - `courier_assigned`
  - `pickup_ready`
  - `picked_up`
  - `arrived_to_client`
  - `delivered`
- لا يوجد OTP في هذا التدفق (حسب طلبك).
- تأكد أن وثائق `drivers` تحتوي:
  - `available: true/false`
  - `region: "..."`

## فهارس Firestore
قد تحتاج إنشاء فهرس للاستعلام:
- `orders` حيث `orderStatus == courier_offer_pending` و `offerExpiresAt <= now`

عند أول تشغيل سيظهر رابط إنشاء الفهرس في سجلات Firebase، وافق عليه مرة واحدة.
