String formatUnifiedOrderCode({
  dynamic orderNumber,
  dynamic orderId,
  dynamic docId,
}) {
  String normalize(dynamic value, {bool shortenFallback = false}) {
    var raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return '';

    if (raw.startsWith('#')) {
      raw = raw.substring(1).trim();
    }

    final ordPrefix = RegExp(r'^(ord)[\s_-]*', caseSensitive: false);
    if (ordPrefix.hasMatch(raw)) {
      final tail = raw.replaceFirst(ordPrefix, '').trim();
      return tail.isEmpty ? 'ORD-000000' : 'ORD-$tail';
    }

    if (shortenFallback && raw.length > 8) {
      raw = raw.substring(0, 8);
    }

    return 'ORD-$raw';
  }

  final fromOrderNumber = normalize(orderNumber);
  if (fromOrderNumber.isNotEmpty) return fromOrderNumber;

  final fromOrderId = normalize(orderId);
  if (fromOrderId.isNotEmpty) return fromOrderId;

  final fromDocId = normalize(docId, shortenFallback: true);
  if (fromDocId.isNotEmpty) return fromDocId;

  return 'ORD-000000';
}
