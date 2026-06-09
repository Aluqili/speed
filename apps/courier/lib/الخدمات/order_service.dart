import 'package:cloud_functions/cloud_functions.dart';

class OrderService {
  OrderService._();

  static Future<void> approveByRestaurant(String orderId) async {
    throw UnsupportedError(
      'Restaurant approval must be performed by the store app or admin backend.',
    );
  }

  static Future<void> driverGoToClient(String orderId, String driverId) async {
    await FirebaseFunctions.instanceFor(region: 'me-central1')
        .httpsCallable('courierUpdateOrderStage')
        .call({
      'orderId': orderId,
      'driverId': driverId,
      'stage': 'picked_up',
    });
  }

  static Future<void> driverArrivedToClient(
      String orderId, String driverId) async {
    await FirebaseFunctions.instanceFor(region: 'me-central1')
        .httpsCallable('courierUpdateOrderStage')
        .call({
      'orderId': orderId,
      'driverId': driverId,
      'stage': 'arrived_to_client',
    });
  }

  static Future<void> driverCompleteDelivery(
    String orderId,
    String driverId, {
    required String proofImageUrl,
  }) async {
    await FirebaseFunctions.instanceFor(region: 'me-central1')
        .httpsCallable('courierUpdateOrderStage')
        .call({
      'orderId': orderId,
      'driverId': driverId,
      'stage': 'delivered',
      'proofImageUrl': proofImageUrl,
    });
  }

  static Future<void> cancelOrder(String orderId, {String? reason}) async {
    throw UnsupportedError(
      'Order cancellation must be performed by an authorized backend action.',
    );
  }
}
