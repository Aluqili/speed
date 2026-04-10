# تجهيز Google Play - SpeedStar

آخر تحديث: 14 مارس 2026

## 1) الروابط القانونية الجاهزة

- الصفحة القانونية الرئيسية: [https://speedstar-dev.web.app/legal/](https://speedstar-dev.web.app/legal/)
- سياسة خصوصية العميل: [https://speedstar-dev.web.app/legal/privacy-client-ar.html](https://speedstar-dev.web.app/legal/privacy-client-ar.html)
- سياسة خصوصية المندوب: [https://speedstar-dev.web.app/legal/privacy-courier-ar.html](https://speedstar-dev.web.app/legal/privacy-courier-ar.html)
- سياسة خصوصية المتجر: [https://speedstar-dev.web.app/legal/privacy-store-ar.html](https://speedstar-dev.web.app/legal/privacy-store-ar.html)
- حذف حساب العميل: [https://speedstar-dev.web.app/legal/account-deletion-client-ar.html](https://speedstar-dev.web.app/legal/account-deletion-client-ar.html)
- حذف حساب المندوب: [https://speedstar-dev.web.app/legal/account-deletion-courier-ar.html](https://speedstar-dev.web.app/legal/account-deletion-courier-ar.html)
- حذف حساب المتجر: [https://speedstar-dev.web.app/legal/account-deletion-store-ar.html](https://speedstar-dev.web.app/legal/account-deletion-store-ar.html)

البريد الرسمي للخصوصية والحذف:

- [speedstarapp0@gmail.com](mailto:speedstarapp0@gmail.com)

## 2) أين تضع كل رابط داخل Play Console

لكل تطبيق (Client / Courier / Store):

1. ادخل إلى التطبيق في Play Console.
2. من App content > Privacy policy ضع رابط سياسة الخصوصية الخاصة بنفس التطبيق.
3. من Data safety > Account deletion ضع رابط حذف الحساب الخاص بنفس التطبيق.

## 3) نصوص Data safety المقترحة (جاهزة للنسخ)

> ملاحظة: هذه الصياغة مبنية على الكود الحالي والاعتمادات. قبل الإرسال النهائي، راجع أسئلة Play Console بندًا بندًا حسب التطبيق.

### A) تطبيق العميل (Client)

#### هل يجمع تطبيق العميل بيانات؟

- نعم.

#### هل يشارك تطبيق العميل البيانات مع جهات خارجية؟

- لا (عدا مزودي الخدمة الأساسيين لتشغيل التطبيق مثل Firebase).

#### أنواع البيانات التي يجمعها التطبيق

- المعلومات الشخصية: الاسم، الهاتف، البريد الإلكتروني.
- الموقع: موقع تقريبي/دقيق (عبر العنوان والإحداثيات) لتقديم خدمة التوصيل.
- نشاط التطبيق: بيانات الطلبات وحالاتها.
- الرسائل داخل التطبيق (عند التواصل مع الدعم).

#### الغرض من الجمع

- وظائف التطبيق الأساسية (إنشاء الحساب، تنفيذ الطلب، التوصيل).
- دعم العملاء.
- الأمان ومنع إساءة الاستخدام.
- التحليلات التشغيلية الداخلية.

#### هل بيانات تطبيق العميل مشفّرة أثناء النقل؟

- نعم.

#### هل حذف بيانات تطبيق العميل متاح؟

- نعم عبر: [https://speedstar-dev.web.app/legal/account-deletion-client-ar.html](https://speedstar-dev.web.app/legal/account-deletion-client-ar.html)

### B) تطبيق المندوب (Courier)

#### هل يجمع تطبيق المندوب بيانات؟

- نعم.

#### هل يشارك تطبيق المندوب البيانات مع جهات خارجية؟

- لا (عدا مزودي البنية التشغيلية مثل Firebase).

#### ما أنواع بيانات تطبيق المندوب؟

- معلومات شخصية: الاسم، الهاتف، البريد.
- الموقع (يشمل أثناء التشغيل لتتبع رحلة التوصيل).
- نشاط التطبيق: الطلبات المسندة، حالات التنفيذ.
- رسائل/دعم داخل التطبيق.

#### ما غرض جمع بيانات تطبيق المندوب؟

- إسناد الطلبات والتنقل للمطعم والعميل.
- تشغيل الخدمة وتحسين الجودة.
- الأمان ومنع الاحتيال.

#### هل بيانات تطبيق المندوب مشفّرة أثناء النقل؟

- نعم.

#### هل حذف بيانات تطبيق المندوب متاح؟

- نعم عبر: [https://speedstar-dev.web.app/legal/account-deletion-courier-ar.html](https://speedstar-dev.web.app/legal/account-deletion-courier-ar.html)

### C) تطبيق المتجر (Store)

#### هل يجمع تطبيق المتجر بيانات؟

- نعم.

#### هل يشارك تطبيق المتجر البيانات مع جهات خارجية؟

- لا (عدا مزودي تشغيل البنية مثل Firebase).

#### ما أنواع بيانات تطبيق المتجر؟

- معلومات المتجر/المستخدم: الاسم، الهاتف، البريد.
- الموقع (لضبط النطاق الجغرافي).
- بيانات الطلبات والقوائم التشغيلية.

#### ما غرض جمع بيانات تطبيق المتجر؟

- إدارة الطلبات وقائمة المنتجات.
- تشغيل الخدمة وتحسين الأداء.
- الأمان والامتثال.

#### هل بيانات تطبيق المتجر مشفّرة أثناء النقل؟

- نعم.

#### هل حذف بيانات تطبيق المتجر متاح؟

- نعم عبر: [https://speedstar-dev.web.app/legal/account-deletion-store-ar.html](https://speedstar-dev.web.app/legal/account-deletion-store-ar.html)

## 4) مراجعة أذونات Android (الحالة الحالية)

### المصرّح به مباشرة في AndroidManifest لكل التطبيقات

- INTERNET

### أذونات متوقعة من الحزم (تظهر غالبًا في merged manifest وقت البناء)

- الموقع (Location): بسبب geolocator/google_maps/geocoding (خصوصًا client/courier/store).
- الإشعارات: flutter_local_notifications (client/courier/store).
- الدفع بالإشعارات السحابية: firebase_messaging (courier).
- الوسائط/الصور: image_picker (بحسب استخدام الرفع أو اختيار الصور).

## 5) قائمة فحص سريعة قبل الإرسال

1. افتح App content وأضف رابط سياسة الخصوصية الصحيح لكل تطبيق.
2. أكمل Data safety من النصوص أعلاه (مع تدقيق نهائي حسب أسئلة النموذج).
3. أضف رابط حذف الحساب في قسم Account deletion لكل تطبيق.
4. تأكد من وجود خيار حذف الحساب داخل التطبيق نفسه:
   - العميل: الإعدادات > حذف الحساب.
   - المندوب: حسابي > حذف الحساب.
   - المتجر: إعدادات المطعم > حذف الحساب.
5. راجع قسم Permissions declarations لأي إذن حساس يظهر في Play Console.
6. ارفع AAB تجريبي لكل تطبيق وراجع التحذيرات قبل الإرسال النهائي.
