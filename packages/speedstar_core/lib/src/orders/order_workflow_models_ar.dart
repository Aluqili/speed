/// نماذج دورة الطلب (حالة وانتقال).
class OrderStateArabic {
  final String name;
  const OrderStateArabic(this.name);
}

class TransitionSpecArabic {
  final String action; // مثال: approve, assign_driver, deliver
  final String from;
  final String to;
  final List<String> allowedRoles; // مثال: ['store','courier','admin']
  final int? timeoutSeconds;
  final String? onTimeoutAction;
  final int? maxRetries;

  const TransitionSpecArabic({
    required this.action,
    required this.from,
    required this.to,
    required this.allowedRoles,
    this.timeoutSeconds,
    this.onTimeoutAction,
    this.maxRetries,
  });

  factory TransitionSpecArabic.fromJson(Map<String, dynamic> json) {
    return TransitionSpecArabic(
      action: json['action'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      allowedRoles: List<String>.from(json['allowedRoles'] as List),
      timeoutSeconds: (json['timeoutSeconds'] as num?)?.toInt(),
      onTimeoutAction: json['onTimeoutAction'] as String?,
      maxRetries: (json['maxRetries'] as num?)?.toInt(),
    );
  }
}
