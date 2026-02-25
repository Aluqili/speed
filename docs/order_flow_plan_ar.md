# خطة تدفق الطلب (بدون OTP)

## الهدف
تطبيق تدفق موحّد وقابل للتحكم عن بعد لتقليل التعارض بين تطبيقات العميل/المتجر/المندوب.

## تسلسل العمل
1. العميل ينشئ الطلب => `store_pending`.
2. المتجر يقبل أو يرفض:
   - قبول => `courier_searching`.
   - رفض => `store_rejected`.
3. النظام يعرض الطلب على مندوب لمدة 40 ثانية (`courier_offer_pending`).
   - قبول المندوب => `courier_assigned`.
   - رفض/انتهاء مهلة => العودة إلى `courier_searching` ثم مندوب آخر.
4. المتجر يجهّز الطلب ويضغط جاهز => `pickup_ready`.
5. المندوب يستلم الطلب => `picked_up`.
6. المندوب يصل للعميل => `arrived_to_client` (يرسل إشعار للعميل).
7. المندوب يسلّم الطلب => `delivered`.

## ملاحظات تنفيذية
- لا يتم حذف الطلب من قاعدة البيانات؛ فقط تغيير الحالة.
- عرض الطلبات يتم بالفلترة حسب الحالة:
  - المتجر: النشطة (`store_pending`, `courier_assigned`, `pickup_ready`) / المكتملة (`delivered`, `store_rejected`, `cancelled`).
  - المندوب: المعروضة (`courier_offer_pending`) / النشطة (`courier_assigned`, `pickup_ready`, `picked_up`, `arrived_to_client`) / المكتملة (`delivered`).
  - العميل: الحالية (كل ما قبل `delivered`) / السابقة (`delivered`, `cancelled`, `store_rejected`).
- إسناد المندوب يجب أن يكون ذريًا (Transaction/Cloud Function) لمنع قبول مزدوج.
- ضبط `maxCourierAssignmentAttempts` (مثلاً 5) ثم تحويل الحالة إلى `delivery_failed` أو `cancelled` بسياسة واضحة.

## التحكم عن بعد
- ملف التدفق الجاهز: [docs/order_workflow_remote_config.orders.json](docs/order_workflow_remote_config.orders.json)
- يمكن تخزين محتواه في Firestore:
  - Collection: `workflows`
  - Document: `orders`
  - Field: `transitions`

## بدون OTP
هذا التدفق يعتمد على الحالة والأدوار فقط، بدون رمز تسليم.
