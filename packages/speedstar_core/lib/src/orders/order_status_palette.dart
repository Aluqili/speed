import 'package:flutter/material.dart';

import '../../الثيم/ثيم_التطبيق.dart';

class OrderStatusPalette {
  static const Color pending = Colors.orange;
  static const Color assigned = Color(0xFF2563EB);
  static const Color inTransit = Color(0xFF0F766E);
  static const Color delivered = AppThemeArabic.clientSuccess;
  static const Color cancelled = AppThemeArabic.clientError;
  static const Color neutral = AppThemeArabic.clientTextSecondary;

  static String normalize(String status) {
    switch (status.trim()) {
      case 'pending_payment':
      case 'انتظار الدفع':
      case 'payment_review':
      case 'store_pending':
      case 'under_review':
      case 'قيد المراجعة':
      case 'بانتظار المطعم':
        return 'pending';
      case 'courier_searching':
      case 'courier_offer_pending':
      case 'courier_assigned':
      case 'pickup_ready':
      case 'جاهز للتوصيل':
      case 'قيد التجهيز':
        return 'assigned';
      case 'picked_up':
      case 'arrived_to_client':
      case 'وصل إلى العميل':
      case 'قيد التوصيل':
        return 'in_transit';
      case 'delivered':
      case 'تم التوصيل':
      case 'paid':
      case 'تم الدفع':
      case 'approved':
      case 'تمت الموافقة':
        return 'delivered';
      case 'store_rejected':
      case 'cancelled':
      case 'ملغي':
      case 'rejected':
      case 'رفض الدفع':
      case 'مرفوض':
        return 'cancelled';
      default:
        return 'neutral';
    }
  }

  static Color colorForStatus(String status, {String? paymentStatus}) {
    if ((paymentStatus ?? '').trim() == 'انتظار الدفع') {
      return pending;
    }
    switch (normalize(status)) {
      case 'pending':
        return pending;
      case 'assigned':
        return assigned;
      case 'in_transit':
        return inTransit;
      case 'delivered':
        return delivered;
      case 'cancelled':
        return cancelled;
      default:
        return neutral;
    }
  }

  static Color backgroundForStatus(String status, {String? paymentStatus}) {
    return colorForStatus(status, paymentStatus: paymentStatus)
        .withOpacity(0.12);
  }

  static String displayText(String status) {
    switch (status.trim()) {
      case 'pending_payment':
      case 'انتظار الدفع':
        return 'انتظار الدفع';
      case 'payment_review':
      case 'store_pending':
      case 'under_review':
      case 'قيد المراجعة':
      case 'بانتظار المطعم':
        return 'قيد المراجعة';
      case 'courier_searching':
        return 'جاري البحث عن مندوب';
      case 'courier_offer_pending':
        return 'بانتظار رد المندوب';
      case 'courier_assigned':
        return 'تم تعيين مندوب';
      case 'pickup_ready':
      case 'جاهز للتوصيل':
        return 'جاهز للاستلام';
      case 'picked_up':
      case 'قيد التوصيل':
        return 'قيد التوصيل';
      case 'arrived_to_client':
      case 'وصل إلى العميل':
        return 'وصل إلى العميل';
      case 'delivered':
      case 'تم التوصيل':
        return 'تم التوصيل';
      case 'store_rejected':
        return 'مرفوض من المتجر';
      case 'cancelled':
      case 'ملغي':
        return 'ملغي';
      default:
        return status;
    }
  }
}
