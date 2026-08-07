import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:speedstar_courier_app/helpers/courier_runtime_helpers.dart';
import 'package:speedstar_courier_app/الشاشات/courier_notification_details_screen.dart';

void main() {
  group('courierFormatDistance', () {
    test('formats meters and kilometers consistently', () {
      expect(courierFormatDistance(null), 'غير متاح');
      expect(courierFormatDistance(0.42), '420 م');
      expect(courierFormatDistance(2.25), '2.3 كم');
    });
  });

  test('courierHaversineKm returns zero for identical points', () {
    const point = LatLng(15.5007, 32.5599);
    expect(courierHaversineKm(point, point), closeTo(0, 0.0001));
  });

  group('notification image links', () {
    test('recognizes Cloudinary and storage image URLs', () {
      expect(
        CourierNotificationDetailsScreen.isLikelyImageUrl(
          'https://res.cloudinary.com/demo/image/upload/v1/notice',
        ),
        isTrue,
      );
      expect(
        CourierNotificationDetailsScreen.isLikelyImageUrl(
          'https://firebasestorage.googleapis.com/v0/b/app/o/notice',
        ),
        isTrue,
      );
    });

    test('rejects non-image or invalid URLs', () {
      expect(
        CourierNotificationDetailsScreen.isLikelyImageUrl(
            'ftp://example.com/a.jpg'),
        isFalse,
      );
      expect(
        CourierNotificationDetailsScreen.isLikelyImageUrl(
            'https://example.com/document.pdf'),
        isFalse,
      );
    });
  });
}
