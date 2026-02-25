# قواعد Firestore للأدمن والدعم الفني

تمت إضافة القواعد في:
- firestore.rules
- firestore.indexes.json

## الهدف
- تفعيل صلاحيات مسؤول النظام عبر collection اسمها admins.
- تفعيل مركز الدعم supportTickets بشكل موحد لكل التطبيقات.
- الحفاظ على تشغيل التطبيقات الحالية بدون كسر التدفق.

## من يعتبر Admin
أي مستخدم يوجد له مستند في:
- admins/{uid}
ويحتوي أحد الحقول التالية:
- role = admin
- active = true

## قواعد الدعم الفني
Collection: supportTickets
- create: لأي مستخدم مسجل دخول ويكون userId مطابق uid و sourceApp ضمن client/courier/store.
- read: للأدمن أو صاحب التذكرة.
- update/delete: للأدمن فقط.

## نشر القواعد
- firebase deploy --only firestore:rules,firestore:indexes

## ملاحظة
إذا أردت تشديد الأمان أكثر لاحقًا، الخطوة التالية هي استبدال صلاحية read/write العامة للمجموعات الأساسية بقواعد أدق لكل دور (client/store/courier) مع الاعتماد على custom claims أو حقول دور موثقة.
