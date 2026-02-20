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

  const TransitionSpecArabic({
    required this.action,
    required this.from,
    required this.to,
    required this.allowedRoles,
  });

  factory TransitionSpecArabic.fromJson(Map<String, dynamic> json) {
    return TransitionSpecArabic(
      action: json['action'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      allowedRoles: List<String>.from(json['allowedRoles'] as List),
    );
  }
}
