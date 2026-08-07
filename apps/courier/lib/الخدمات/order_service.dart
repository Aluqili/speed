import '../helpers/courier_runtime_helpers.dart';

class OrderService {
  OrderService._();

  static Future<void> approveByRestaurant(String orderId) async {
    throw UnsupportedError(
      'Restaurant approval must be performed by the store app or admin backend.',
    );
  }

  static Future<void> driverGoToClient(String orderId, String driverId) async {
    await courierInvokeCallable(
      'courierUpdateOrderStage',
      {
        'orderId': orderId,
        'driverId': driverId,
        'stage': 'picked_up',
      },
      timeout: const Duration(seconds: 10),
      maxAttempts: 2,
    );
  }

  static Future<void> driverArrivedToClient(
      String orderId, String driverId) async {
    await courierInvokeCallable(
      'courierUpdateOrderStage',
      {
        'orderId': orderId,
        'driverId': driverId,
        'stage': 'arrived_to_client',
      },
      timeout: const Duration(seconds: 10),
      maxAttempts: 2,
    );
  }

  static Future<void> driverCompleteDelivery(
    String orderId,
    String driverId, {
    required String proofImageUrl,
  }) async {
    await courierInvokeCallable(
      'courierUpdateOrderStage',
      {
        'orderId': orderId,
        'driverId': driverId,
        'stage': 'delivered',
        'proofImageUrl': proofImageUrl,
      },
      timeout: const Duration(seconds: 12),
      maxAttempts: 2,
    );
  }

  static Future<void> cancelOrder(String orderId, {String? reason}) async {
    throw UnsupportedError(
      'Order cancellation must be performed by an authorized backend action.',
    );
  }
}
