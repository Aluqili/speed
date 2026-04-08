# دليل تجهيز وإصدار iOS لتطبيقات SpeedStar

هذا الدليل يغطي التطبيقات الثلاثة:

- apps/client
- apps/store
- apps/courier

## 1) معرفات الحزمة (Bundle IDs)

تم توحيدها في إعدادات iOS لتطابق Firebase:

- Client: com.speedstar.client
- Store: com.speedstar.store
- Courier: com.speedstar.courier

تأكد أن نفس المعرفات موجودة في Apple Developer و App Store Connect.

## 2) ربط Firebase على iOS

لكل تطبيق، أنشئ تطبيق iOS في Firebase بنفس Bundle ID ثم نزّل ملف GoogleService-Info.plist.

ضع الملف داخل:

- apps/client/ios/Runner/GoogleService-Info.plist
- apps/store/ios/Runner/GoogleService-Info.plist
- apps/courier/ios/Runner/GoogleService-Info.plist

ملاحظة: الملفات غير مضافة حالياً في المستودع (عن قصد). يجب إضافتها قبل بناء iOS النهائي.

تنبيه أمني:

- لا ترفع ملفات GoogleService-Info.plist إلى GitHub.
- تم ضبط .gitignore في المشروع لمنع رفعها تلقائياً.

## 3) Google Maps API Key

تم ربط GMSApiKey في Info.plist مع متغير MAPS_API_KEY من ملفات xcconfig.

اضبط المفتاح بشكل آمن (محلي فقط) عبر ملف Secrets.xcconfig غير المتعقّب:

1. انسخ ملف المثال في كل تطبيق:

```bash
cp apps/client/ios/Flutter/Secrets.xcconfig.example apps/client/ios/Flutter/Secrets.xcconfig
cp apps/store/ios/Flutter/Secrets.xcconfig.example apps/store/ios/Flutter/Secrets.xcconfig
cp apps/courier/ios/Flutter/Secrets.xcconfig.example apps/courier/ios/Flutter/Secrets.xcconfig
```

1. عدّل قيمة MAPS_API_KEY داخل كل ملف Secrets.xcconfig محليًا.

ملاحظة:

- ملفات Debug.xcconfig و Release.xcconfig تم إعدادها لقراءة Secrets.xcconfig إن وجد.
- الملف Secrets.xcconfig داخل .gitignore ولن يتم رفعه خارجيًا.

لمن يريد الإعداد اليدوي المباشر، هذه الملفات الأساسية:

- apps/client/ios/Flutter/Debug.xcconfig
- apps/client/ios/Flutter/Release.xcconfig
- apps/store/ios/Flutter/Debug.xcconfig
- apps/store/ios/Flutter/Release.xcconfig
- apps/courier/ios/Flutter/Debug.xcconfig
- apps/courier/ios/Flutter/Release.xcconfig

مثال:
MAPS_API_KEY=AIza...

## 4) صلاحيات iOS (Info.plist)

تم تجهيز رسائل الاستخدام المطلوبة للآتي:

- الكاميرا
- الموقع أثناء الاستخدام
- قراءة الصور
- حفظ الصور

راجع النصوص إذا أردت صياغة قانونية مخصصة قبل النشر.

## 5) التوقيع (Signing)

من جهاز Mac (Xcode):

1. افتح Runner.xcworkspace لكل تطبيق.
2. اختر فريق Apple Developer الصحيح (Team).
3. فعّل Automatically manage signing.
4. تأكد من اختيار Provisioning Profile الصحيح لكل Release.

## 6) إعداد CocoaPods

تم إضافة Podfile لكل تطبيق. بعد flutter pub get نفّذ على Mac:

```bash
cd apps/client
flutter pub get
cd ios && pod repo update && pod install && cd ..

cd ../store
flutter pub get
cd ios && pod repo update && pod install && cd ..

cd ../courier
flutter pub get
cd ios && pod repo update && pod install && cd ..
```

## 7) البناء للاختبار (IPA/TestFlight)

لكل تطبيق:

```bash
flutter build ipa --release
```

أو من Xcode:

- Product -> Archive
- ثم Distribute App -> App Store Connect -> Upload

## 8) ملاحظات مهمة على Windows

لا يمكن إخراج IPA موقّع نهائيًا من Windows مباشرة. يلزم Mac فعلي أو CI على macOS مثل Codemagic أو GitHub Actions.

للمسار العملي المجهز لهذا المستودع باستخدام Codemagic من ويندوز:

- راجع docs/codemagic_client_ios_ar.md

## 9) Checklist قبل الإرسال

- Bundle ID مطابق بين Xcode و Firebase و Apple
- GoogleService-Info.plist موجود لكل تطبيق
- MAPS_API_KEY مضبوط في Release.xcconfig
- التأكد أن أي ملف يحتوي أسرار مثل GoogleService-Info.plist و Secrets.xcconfig غير مرفوع للمستودع
- Signing أو Team أو Profiles مضبوطة
- اختبار تسجيل الدخول والخرائط والإشعارات ورفع الصور على iPhone حقيقي
- رفع Build إلى TestFlight ثم اختبار QA
