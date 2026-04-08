# إعداد Codemagic لتطبيق العميل iOS من ويندوز

هذا الدليل يجهز لك بناء iOS لتطبيق العميل من غير Mac محلي.

الملفات التي يعتمد عليها هذا المسار:

- codemagic.yaml
- apps/client/ios/Flutter/Secrets.xcconfig
- apps/client/ios/Runner/GoogleService-Info.plist

لكن بما أن الملفات السرية المحلية لا يجب أن تدخل Git، فإن Codemagic سيولدها أثناء البناء من متغيرات سرية.

## ما الذي أضفناه

يوجد الآن في الجذر ملف codemagic.yaml وفيه مساران:

1. client_ios_validate
   - يبني iOS بدون توقيع.
   - هدفه التأكد أن المشروع يجهز على macOS سحابي بشكل صحيح.

2. client_ios_release_ipa
   - يبني IPA موقعة بعد ضبط التوقيع داخل Codemagic.
   - هدفه إخراج ملف IPA جاهز للرفع.

## قبل البدء

تأكد من الآتي:

- Bundle ID هو com.speedstar.client
- لديك تطبيق iOS مضاف في Firebase
- لديك ملف GoogleService-Info.plist الخاص بالعميل
- لديك حساب Apple Developer مفعل
- لديك App Store Connect app record لتطبيق العميل

## 1) إضافة المشروع إلى Codemagic

1. افتح Codemagic.
2. اختر Add application.
3. اربط مستودع GitHub الحالي.
4. اختر المستودع Aluqili/speed.
5. بعد إضافة التطبيق، اجعل Codemagic يقرأ الملف codemagic.yaml من الفرع codemagic-client-ios-setup أو من أي فرع تدمج إليه هذه التغييرات لاحقًا.

## 2) تجهيز المتغيرات السرية

أنشئ Group في Codemagic باسم مقترح مثل speedstar_client_ios ثم أضف داخله:

- CLIENT_IOS_MAPS_API_KEY
  - القيمة: مفتاح Google Maps iOS الخاص بتطبيق العميل

- CLIENT_IOS_GOOGLE_SERVICE_INFO_PLIST_B64
  - القيمة: محتوى ملف GoogleService-Info.plist بعد تحويله إلى Base64

### كيف تحول plist إلى Base64 على ويندوز PowerShell

شغل هذا الأمر محليًا على ويندوز بعد وضع ملف plist عندك:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("D:\path\to\GoogleService-Info.plist"))
```

انسخ الناتج بالكامل وضعه كقيمة للمتغير CLIENT_IOS_GOOGLE_SERVICE_INFO_PLIST_B64 في Codemagic.

## 3) أول بناء آمن: Validate

ابدأ أولاً بالـ workflow التالي:

- client_ios_validate

هذا المسار لا يحتاج توقيع iOS بعد، لكنه يتأكد من:

- جلب الحزم
- تثبيت Pods
- تكوين ملفات Firebase و Maps أثناء البناء
- نجاح بناء iOS على macOS سحابي

إذا فشل، أصلح الخطأ أولاً قبل الانتقال للتوقيع.

## 4) إعداد توقيع iOS داخل Codemagic

حتى يعمل المسار client_ios_release_ipa تحتاج ضبط iOS signing في Codemagic.

يوجد طريقتان، والأفضل لك هنا هو المسار الآلي:

1. من App Store Connect أنشئ API Key جديدة بصلاحية App Manager.
2. خذ القيم التالية:
   - Issuer ID
   - Key ID
   - ملف المفتاح .p8
3. داخل Codemagic افتح Team Settings أو App Settings ثم Apple Developer Portal integration.
4. اربط API key هناك.
5. فعّل إدارة ملفات التوقيع الخاصة بـ iOS للتطبيق com.speedstar.client.

مهم:

- أول مرة قد تحتاج التأكد أن Bundle ID موجود أصلًا في Apple Developer.
- إذا كانت شهادة التوقيع أو provisioning profile غير موجودة، Codemagic يمكنه إنشاؤها أو جلبها بحسب إعدادات الحساب.

## 5) بناء IPA موقعة

بعد نجاح التوقيع داخل Codemagic، شغل هذا المسار:

- client_ios_release_ipa

هذا المسار يقوم بـ:

- إنشاء Secrets.xcconfig وقت البناء
- إنشاء GoogleService-Info.plist وقت البناء
- تطبيق provisioning profiles على مشروع Xcode
- بناء IPA موقعة

وستجد ملف الإخراج داخل Artifacts في Codemagic.

## 6) ماذا بعد IPA

بعد أن ينجح أول IPA موقعة، أمامنا خياران:

1. ترفعها يدويًا إلى App Store Connect
2. أضيف لك خطوة نشر TestFlight مباشرة داخل codemagic.yaml

أنا أنصح أن نجعل أول تشغيل يقتصر على:

- Validate
- ثم Signed IPA

وبعد نجاحهما نضيف النشر الآلي إلى TestFlight حتى لا نخلط أخطاء البناء مع أخطاء التوزيع.

## 7) إذا فشل البناء

أرسل لي فقط:

- اسم الـ workflow الذي فشل
- أول خطأ ظاهر في اللوج
- آخر 30 إلى 50 سطر من اللوج

وسأعطيك التصحيح مباشرة.
