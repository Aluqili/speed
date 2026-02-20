# مونو-ريبو SpeedStar (العميل/المندوب/المتجر)

هذا المشروع يضم ثلاث تطبيقات Flutter تشترك في الحزمة `packages/speedstar_core`.

- `apps/client`: تطبيق العميل
- `apps/courier`: تطبيق المندوب
- `apps/store`: تطبيق المتجر

توفر الحزمة المشتركة محرّك Server-Driven UI (SDUI) يعتمد على ملفات JSON عبر HTTP، مما يسمح بتحديث الواجهات سحابياً دون الحاجة لإصدار تحديث جديد في المتجر.

## تشغيل سريع (ويندوز)

1. تأكد من تثبيت Flutter (قناة stable) وضبط متغيرات PATH.
2. جلب الحزم:
   - `cd packages/speedstar_core && flutter pub get`
   - `cd ../../apps/client && flutter pub get`
3. إنشاء منصات لكل تطبيق:
   - `cd apps/client && flutter create .`
   - `cd ../courier && flutter create .`
   - `cd ../store && flutter create .`
4. تشغيل التطبيق (مثال العميل):
   - `cd apps/client && flutter run`

### التحديث السحابي
- استضف ملفات JSON (مثال: `https://yourdomain/sdui/client.json`) وحدّث الروابط داخل ملفات `main.dart` لكل تطبيق.
- يدعم SDUI مفاتيح عربية في JSON مثل: `نوع`، `نص`، `زر`، `صورة`، `فاصل`، `عنوان`، `رسالة`، `عرض`، `ارتفاع`.
