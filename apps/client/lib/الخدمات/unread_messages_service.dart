import 'package:cloud_firestore/cloud_firestore.dart';

/// خدمة لتتبع الرسائل غير المقروءة
class UnreadMessagesService {
  static final _fs = FirebaseFirestore.instance;

  /// تحديث وقت آخر قراءة لمحادثة معينة
  static Future<void> markConversationRead(
      String clientId, String conversationId) async {
    if (clientId.isEmpty || conversationId.isEmpty) return;
    try {
      await _fs
          .collection('clients')
          .doc(clientId)
          .collection('chatReadStatus')
          .doc(conversationId)
          .set(
            {'lastReadAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true),
          );
    } catch (_) {}
  }

  /// تدفق عدد الرسائل غير المقروءة من المندوب في محادثة مباشرة
  static Stream<int> unreadDirectChatStream(
      String clientId, String conversationId) {
    if (clientId.isEmpty || conversationId.isEmpty) {
      return const Stream.empty();
    }

    // استمع لرسائل المحادثة + حالة القراءة معاً
    return _fs
        .collection('clients')
        .doc(clientId)
        .collection('chatReadStatus')
        .doc(conversationId)
        .snapshots()
        .asyncMap((readDoc) async {
      final lastReadAt =
          (readDoc.data()?['lastReadAt'] as Timestamp?)?.toDate();

      final snap = await _fs
          .collection('chats')
          .where('conversationId', isEqualTo: conversationId)
          .get();

      return snap.docs.where((d) {
        final data = d.data();
        if ((data['senderId'] ?? '') == clientId) return false;
        final ts = (data['timestamp'] as Timestamp?)?.toDate();
        if (ts == null) return lastReadAt == null;
        return lastReadAt == null || ts.isAfter(lastReadAt);
      }).length;
    });
  }

  /// تدفق عدد الرسائل غير المقروءة من الدعم الفني
  static Stream<int> unreadSupportStream(String clientId) {
    if (clientId.isEmpty) return const Stream.empty();

    final conversationId = '$clientId-support';

    return _fs
        .collection('clients')
        .doc(clientId)
        .collection('chatReadStatus')
        .doc(conversationId)
        .snapshots()
        .asyncMap((readDoc) async {
      final lastReadAt =
          (readDoc.data()?['lastReadAt'] as Timestamp?)?.toDate();

      // ابحث في كل محادثات الدعم لهذا العميل
      final snap = await _fs
          .collection('supportMessages')
          .where('clientId', isEqualTo: clientId)
          .get();

      return snap.docs.where((d) {
        final data = d.data();
        // الرسائل التي ليست من العميل (أي من الدعم)
        if ((data['senderType'] ?? '') == 'client') return false;
        if ((data['senderId'] ?? '') == clientId) return false;
        final ts = (data['timestamp'] as Timestamp?)?.toDate();
        if (ts == null) return lastReadAt == null;
        return lastReadAt == null || ts.isAfter(lastReadAt);
      }).length;
    });
  }

  /// تدفق لمعرفة هل يوجد أي رسائل غير مقروءة (دعم + مندوب)
  static Stream<bool> hasAnyUnreadStream(
      String clientId, List<String> directChatIds) {
    if (clientId.isEmpty) return Stream.value(false);

    // ندمج تدفق الدعم + كل محادثات مباشرة
    final streams = <Stream<int>>[
      unreadSupportStream(clientId),
      ...directChatIds.map((id) => unreadDirectChatStream(clientId, id)),
    ];

    // نرجع true إذا أي منها > 0
    if (streams.isEmpty) return Stream.value(false);
    return streams.first.map((unreadCount) => unreadCount > 0);
  }
}
