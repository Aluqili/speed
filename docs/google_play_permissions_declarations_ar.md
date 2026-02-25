# Google Play - Permissions Declarations (جاهز للنسخ)

آخر تحديث: 23 فبراير 2026

هذا الملف يقدّم إجابات عملية لقسم الأذونات في Play Console لكل تطبيق.
تم الاستناد إلى الكود الحالي ونتائج merged manifests الموجودة في build.

---

## 1) تطبيق العميل (Client)

### الأذونات الظاهرة حاليًا
- INTERNET
- ACCESS_COARSE_LOCATION
- ACCESS_FINE_LOCATION
- POST_NOTIFICATIONS

### إجابات مقترحة في Play Console

- **Location permission**: نعم، التطبيق يستخدم الموقع لتحديد عنوان التوصيل وحساب المسافة وعرض المطاعم ضمن النطاق.
- **هل الموقع مطلوب لوظائف أساسية؟** نعم.
- **هل تجمعون الموقع في الخلفية (Background)?** لا (Foreground فقط ضمن تجربة العنوان/الطلب).
- **Notifications permission**: نعم، لإرسال تنبيهات حالة الطلب والتنبيهات المهمة.
- **هل الإشعارات ضرورية لوظيفة أساسية؟** ليست شرطًا لفتح التطبيق، لكنها مهمة لتتبع الطلبات.

### نص تبرير مختصر (Copy/Paste)
نستخدم إذن الموقع الدقيق/التقريبي لتمكين اختيار عنوان التوصيل وحساب المسافة وعرض المطاعم المتاحة ضمن نطاق العميل. ونستخدم إذن الإشعارات لإرسال تحديثات حالة الطلب والتنبيهات التشغيلية المهمة.

---

## 2) تطبيق المندوب (Courier)

### الأذونات الظاهرة حاليًا
- INTERNET
- ACCESS_COARSE_LOCATION
- ACCESS_FINE_LOCATION
- POST_NOTIFICATIONS

### إجابات مقترحة في Play Console

- **Location permission**: نعم، التطبيق يعتمد على الموقع لتوجيه المندوب للمطعم والعميل ومتابعة التنفيذ.
- **هل الموقع مطلوب لوظائف أساسية؟** نعم.
- **هل تجمعون الموقع في الخلفية (Background)?** لا حسب التصاريح الحالية (لا يوجد ACCESS_BACKGROUND_LOCATION في manifests الحالية).
- **Notifications permission**: نعم، لاستقبال عروض/إسناد الطلبات والتنبيهات الفورية.
- **هل الإشعارات ضرورية؟** مهمة جدًا للتشغيل الفوري لكنها ليست شرطًا لفتح التطبيق.

### نص تبرير مختصر (Copy/Paste)
يستخدم تطبيق المندوب إذن الموقع الدقيق/التقريبي لتوجيه المندوب أثناء تنفيذ الطلبات (الذهاب للمطعم ثم العميل) وضمان دقة التشغيل. كما يستخدم إذن الإشعارات لاستقبال الطلبات الجديدة وتحديثات الحالة الفورية.

---

## 3) تطبيق المتجر (Store)

### الأذونات الظاهرة حاليًا
- INTERNET
- ACCESS_COARSE_LOCATION
- ACCESS_FINE_LOCATION

### إجابات مقترحة في Play Console

- **Location permission**: نعم، لتحديد/التحقق من موقع المتجر وضبط النطاق الجغرافي للخدمة.
- **هل الموقع مطلوب لوظائف أساسية؟** نعم ضمن إعدادات المتجر والتغطية الجغرافية.
- **هل تجمعون الموقع في الخلفية (Background)?** لا.
- **Notifications permission**: غير ظاهر حاليًا في manifests الحالية لهذا التطبيق.

### نص تبرير مختصر (Copy/Paste)
يستخدم تطبيق المتجر إذن الموقع الدقيق/التقريبي لتحديد موقع المتجر وربطه بالنطاق الجغرافي لخدمة الطلبات والتوصيل.

---

## 4) تنبيه مهم قبل الإرسال النهائي

Play Console يحاسب على الصيغة النهائية داخل ملف AAB المرفوع. لذلك قبل الإرسال النهائي:

1. ابنِ نسخة Release لكل تطبيق.
2. ارفع AAB إلى المسار الداخلي (Internal testing).
3. راجع صفحة الأذونات التي يكتشفها Play تلقائيًا.
4. إذا ظهر إذن إضافي غير متوقع، حدّث إجابات declarations مباشرة وفقه.

---

## 5) روابط قانونية مرتبطة (ضعها مع الأذونات/البيانات)

- العميل:
  - Privacy: https://speedstar-dev.web.app/legal/privacy-client-ar.html
  - Account deletion: https://speedstar-dev.web.app/legal/account-deletion-client-ar.html

- المندوب:
  - Privacy: https://speedstar-dev.web.app/legal/privacy-courier-ar.html
  - Account deletion: https://speedstar-dev.web.app/legal/account-deletion-courier-ar.html

- المتجر:
  - Privacy: https://speedstar-dev.web.app/legal/privacy-store-ar.html
  - Account deletion: https://speedstar-dev.web.app/legal/account-deletion-store-ar.html
