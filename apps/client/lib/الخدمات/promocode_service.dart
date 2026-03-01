import 'package:cloud_functions/cloud_functions.dart';

class PromocodeService {
  PromocodeService()
      : _validateCallable = FirebaseFunctions.instanceFor(region: 'me-central1')
            .httpsCallable('validatePromocodeForClient'),
        _redeemCallable = FirebaseFunctions.instanceFor(region: 'me-central1')
            .httpsCallable('redeemPromocodeForClientOrder');

  final HttpsCallable _validateCallable;
  final HttpsCallable _redeemCallable;

  Future<Map<String, dynamic>?> validatePromocode({
    required String code,
    required num subtotal,
    required num deliveryFee,
    required num largeOrderFee,
    required String restaurantId,
    required List<Map<String, dynamic>> items,
    bool isNewOrder = true,
  }) async {
    final response = await _validateCallable.call(<String, dynamic>{
      'code': code.trim().toUpperCase(),
      'order': {
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'largeOrderFee': largeOrderFee,
        'restaurantId': restaurantId,
        'items': items,
        'isNewOrder': isNewOrder,
      },
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['ok'] != true) return data;
    return data;
  }

  Future<Map<String, dynamic>> redeemPromocode({
    required String code,
    required num subtotal,
    required num deliveryFee,
    required num largeOrderFee,
    required String restaurantId,
    required List<Map<String, dynamic>> items,
    required String orderReference,
    bool isNewOrder = true,
  }) async {
    final response = await _redeemCallable.call(<String, dynamic>{
      'code': code.trim().toUpperCase(),
      'order': {
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'largeOrderFee': largeOrderFee,
        'restaurantId': restaurantId,
        'items': items,
        'orderReference': orderReference,
        'isNewOrder': isNewOrder,
      },
    });
    return Map<String, dynamic>.from(response.data as Map);
  }
}