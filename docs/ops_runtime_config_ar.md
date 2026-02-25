# مفاتيح التشغيل الاحترافي (Remote Config)

هذا الملف يوضح مفاتيح التحكم الموحدة بين لوحة الإدارة والتطبيقات الثلاثة (Client / Courier / Store).

## الفكرة

- التحكم يتم مركزيًا عبر Firebase Remote Config.
- كل تطبيق يقرأ مفاتيح عامة `ops_*` + مفاتيح خاصة به.
- النتيجة: نفس منطق التطبيقات الكبيرة (Feature Flags موحدة + Overrides لكل تطبيق).

## المفاتيح العامة

- `ops_chat_enabled` (bool): تشغيل/إيقاف الدردشة للجميع.
- `ops_chat_disabled_message` (string): رسالة موحدة عند إيقاف الدردشة.
- `ops_notifications_enabled` (bool): تشغيل/إيقاف التنبيهات للجميع.
- `ops_ringtone_enabled` (bool): تشغيل/إيقاف النغمة للجميع.
- `ops_ringtone_volume` (double من 0 إلى 1): مستوى صوت افتراضي عام.

## المفاتيح الخاصة بكل تطبيق

استبدل `{app}` بـ `client` أو `courier` أو `store`.

- `{app}_chat_enabled` (bool): تحكم دردشة التطبيق.
- `{app}_chat_disabled_message` (string): رسالة إيقاف دردشة للتطبيق.
- `{app}_notifications_enabled` (bool): تحكم تنبيهات التطبيق.
- `{app}_ringtone_enabled` (bool): تحكم نغمة التطبيق.
- `{app}_ringtone_volume` (double من 0 إلى 1): مستوى صوت نغمة التطبيق.

## مفاتيح التسعير المرن (العميل)

هذه المفاتيح تتحكم برسوم **الطلبات الكبيرة** وتعمل عن بعد بدون تحديث التطبيق:

- `pricing_large_item_fee_enabled` (bool): تشغيل/إيقاف رسوم الطلبات الكبيرة.
- `pricing_large_item_threshold` (double): سعر الوجبة الذي تبدأ بعده الرسوم (مثال: `10000`).
- `pricing_large_item_fee_base` (double): الرسوم الأساسية لكل وجبة فوق الحد (مثال: `500`).
- `pricing_large_item_step_amount` (double): مقدار الزيادة في سعر الوجبة لكل شريحة إضافية (مثال: `5000`).
- `pricing_large_item_step_fee` (double): الزيادة في الرسوم لكل شريحة إضافية (مثال: `500`).
- `pricing_large_item_fee_cap_per_unit` (double): سقف الرسوم لكل وجبة مهما ارتفع السعر (مثال: `2500`).

مفاتيح حماية هامش التوصيل (عميل مقابل مندوب):

- `pricing_delivery_platform_margin_fixed` (double): هامش المنصة المستهدف فوق رسوم المندوب (مثال: `700`).
- `pricing_delivery_platform_min_margin` (double): أقل هامش مسموح للمنصة مهما تغيرت القيم (مثال: `300`).

> الصيغة الحالية في التطبيق: لكل وجبة سعرها أعلى من `threshold` يتم حساب رسوم تصاعدية خطية، ثم ضربها في الكمية.

> الصيغة الحالية لرسوم التوصيل: `رسوم العميل = رسوم المندوب حسب المسافة + هامش المنصة` مع حد أدنى للهامش عبر `pricing_delivery_platform_min_margin`.

## أولوية التطبيق (Precedence)

- الدردشة تعمل فقط إذا:
  - `ops_chat_enabled = true` **و** `{app}_chat_enabled = true`.
- النغمة تعمل فقط إذا:
  - `ops_notifications_enabled = true`
  - **و** `{app}_notifications_enabled = true`
  - **و** `ops_ringtone_enabled = true`
  - **و** `{app}_ringtone_enabled = true`.
- رسالة إيقاف الدردشة:
  1) `{app}_chat_disabled_message`
  2) `ops_chat_disabled_message`
  3) رسالة fallback داخل التطبيق.
- مستوى الصوت:
  1) `{app}_ringtone_volume` (إذا > 0)
  2) `ops_ringtone_volume`.

## أمثلة تشغيل سريعة

- إيقاف دردشة العميل فقط:
  - `client_chat_enabled = false`
- إيقاف النغمة في المتجر فقط:
  - `store_ringtone_enabled = false`
- تخفيض صوت النغمة في المتجر:
  - `store_ringtone_volume = 0.35`
- إيقاف التنبيهات للجميع:
  - `ops_notifications_enabled = false`

## ملاحظة تشغيلية

- بعد تعديل القيم من لوحة Firebase، التطبيقات تسحب القيم عبر `fetchAndActivate`.
- يفضل تثبيت قيم الإنتاج في Remote Config وتفعيل التدريجي حسب الحاجة.

## قيم Production جاهزة (الإطلاق الطبيعي)

استخدم هذه القيم كبداية آمنة في بيئة الإنتاج:

| المفتاح | القيمة المقترحة |
| --- | --- |
| `ops_chat_enabled` | `true` |
| `ops_chat_disabled_message` | `الدردشة متوقفة مؤقتًا، نرجو المحاولة لاحقًا.` |
| `ops_notifications_enabled` | `true` |
| `ops_ringtone_enabled` | `true` |
| `ops_ringtone_volume` | `0.75` |
| `client_chat_enabled` | `true` |
| `client_chat_disabled_message` | `خدمة الدردشة غير متاحة الآن، تواصل معنا لاحقًا.` |
| `client_notifications_enabled` | `true` |
| `client_ringtone_enabled` | `false` |
| `client_ringtone_volume` | `0.00` |
| `courier_chat_enabled` | `true` |
| `courier_chat_disabled_message` | `الدردشة غير متاحة مؤقتًا للمندوبين.` |
| `courier_notifications_enabled` | `true` |
| `courier_ringtone_enabled` | `true` |
| `courier_ringtone_volume` | `0.70` |
| `store_chat_enabled` | `true` |
| `store_chat_disabled_message` | `الدردشة غير متاحة مؤقتًا للمتجر.` |
| `store_notifications_enabled` | `true` |
| `store_ringtone_enabled` | `true` |
| `store_ringtone_volume` | `0.90` |
| `pricing_large_item_fee_enabled` | `true` |
| `pricing_large_item_threshold` | `10000` |
| `pricing_large_item_fee_base` | `500` |
| `pricing_large_item_step_amount` | `5000` |
| `pricing_large_item_step_fee` | `500` |
| `pricing_large_item_fee_cap_per_unit` | `2500` |
| `pricing_delivery_platform_margin_fixed` | `700` |
| `pricing_delivery_platform_min_margin` | `300` |

> ملاحظة: تم اقتراح `client_ringtone_enabled = false` لأن العميل غالبًا يعتمد على إشعارات النظام أكثر من جرس متكرر داخل التطبيق، بينما المتجر/المندوب يحتاجان تنبيهًا أعلى للأوامر التشغيلية.

## قيم طوارئ جاهزة (Emergency Kill Switch)

استخدم هذه المجموعة عند وجود ضغط تشغيلي/عطل دردشة/مشاكل إشعارات:

| المفتاح | القيمة الطارئة |
| --- | --- |
| `ops_chat_enabled` | `false` |
| `ops_chat_disabled_message` | `الدردشة متوقفة مؤقتًا بسبب أعمال الصيانة. نعتذر لكم.` |
| `ops_notifications_enabled` | `true` |
| `ops_ringtone_enabled` | `false` |
| `ops_ringtone_volume` | `0.50` |
| `client_chat_enabled` | `true` |
| `client_notifications_enabled` | `true` |
| `client_ringtone_enabled` | `false` |
| `courier_chat_enabled` | `true` |
| `courier_notifications_enabled` | `true` |
| `courier_ringtone_enabled` | `false` |
| `store_chat_enabled` | `true` |
| `store_notifications_enabled` | `true` |
| `store_ringtone_enabled` | `false` |

## JSON سريع للنسخ

يمكنك نسخ هذا القسم مباشرة إلى قالب إدارة داخلي (مرجعية تشغيل):

```json
{
  "launch": {
    "ops_chat_enabled": true,
    "ops_chat_disabled_message": "الدردشة متوقفة مؤقتًا، نرجو المحاولة لاحقًا.",
    "ops_notifications_enabled": true,
    "ops_ringtone_enabled": true,
    "ops_ringtone_volume": 0.75,
    "client_chat_enabled": true,
    "client_notifications_enabled": true,
    "client_ringtone_enabled": false,
    "client_ringtone_volume": 0.0,
    "courier_chat_enabled": true,
    "courier_notifications_enabled": true,
    "courier_ringtone_enabled": true,
    "courier_ringtone_volume": 0.7,
    "store_chat_enabled": true,
    "store_notifications_enabled": true,
    "store_ringtone_enabled": true,
    "store_ringtone_volume": 0.9,
    "pricing_large_item_fee_enabled": true,
    "pricing_large_item_threshold": 10000,
    "pricing_large_item_fee_base": 500,
    "pricing_large_item_step_amount": 5000,
    "pricing_large_item_step_fee": 500,
    "pricing_large_item_fee_cap_per_unit": 2500,
    "pricing_delivery_platform_margin_fixed": 700,
    "pricing_delivery_platform_min_margin": 300
  },
  "emergency": {
    "ops_chat_enabled": false,
    "ops_chat_disabled_message": "الدردشة متوقفة مؤقتًا بسبب أعمال الصيانة. نعتذر لكم.",
    "ops_notifications_enabled": true,
    "ops_ringtone_enabled": false,
    "ops_ringtone_volume": 0.5,
    "client_chat_enabled": true,
    "client_notifications_enabled": true,
    "client_ringtone_enabled": false,
    "courier_chat_enabled": true,
    "courier_notifications_enabled": true,
    "courier_ringtone_enabled": false,
    "store_chat_enabled": true,
    "store_notifications_enabled": true,
    "store_ringtone_enabled": false
  }
}
```

## خطوات تطبيق سريعة في Firebase Console

1. افتح **Remote Config** ثم عدّل القيم بالأعلى.
2. اضغط **Publish changes**.
3. راقب 5-10 دقائق سلوك الدردشة والطلبات في التطبيقات الثلاثة.
4. عند الحاجة: بدّل مباشرة إلى مجموعة **Emergency**.

## كيف تضيف مفاتيح التسعير (عمليًا)

1. افتح Firebase Console → مشروعك → **Run** → **Remote Config**.

1. اضغط **Create parameter** لكل مفتاح من مفاتيح التسعير التالية:

- `pricing_large_item_fee_enabled` = `true`
- `pricing_large_item_threshold` = `10000`
- `pricing_large_item_fee_base` = `500`
- `pricing_large_item_step_amount` = `5000`
- `pricing_large_item_step_fee` = `500`
- `pricing_large_item_fee_cap_per_unit` = `2500`
- `pricing_delivery_platform_margin_fixed` = `700`
- `pricing_delivery_platform_min_margin` = `300`

1. احفظ كل Parameter مع **Default value** (نوع Bool/Number بحسب المفتاح).
1. اضغط **Publish changes** لتفعيلها على جميع العملاء.
1. للاختبار السريع، غيّر قيمة واحدة فقط (مثل `pricing_large_item_fee_base`) ثم افتح السلة وتأكد من تغير بند **رسوم الطلبات الكبيرة**.

> ملاحظة: يوجد الآن حماية من السيرفر عبر Cloud Functions تقوم بإعادة احتساب الرسوم دوريًا على الطلبات الحديثة لضمان أن الإجمالي يعكس القيم الحالية من Remote Config.

## التحكم بالإشعارات من لوحة الأدمن

تمت إضافة تبويب **الإشعارات** في لوحة الأدمن لإرسال إشعارات يدوية.

- المسار: لوحة الأدمن → تبويب **الإشعارات**.
- أنماط الإرسال:
  - للجميع
  - لكل دور (العملاء / المندوبون / المتاجر)
  - لمستخدم محدد عبر UID

### الحقول المطلوبة

- نوع الإرسال
- (اختياري) دور المستخدم
- (إلزامي عند مستخدم محدد) UID
- عنوان الإشعار
- نص الرسالة

## الإشعارات الآلية (Auto Notifications)

تمت إضافة إشعارات آلية في Cloud Functions عند تغيّر حالة الطلب (`orders/{orderId}`)، وتشمل:

- استلام الطلب
- عرض توصيل للمندوب
- تعيين مندوب
- استلام الطلب من المتجر
- وصول المندوب للعميل
- التسليم
- الإلغاء

> ملاحظة: هذه الإشعارات تُكتب في Firestore (داخل `clients/{uid}/notifications` أو `notifications`)، والتطبيقات تعرضها حسب شاشات الإشعارات الحالية.
