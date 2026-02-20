import 'package:cloud_firestore/cloud_firestore.dart';

/// نوع الدردشة: دردشة خاصة أم دعم فني
enum ChatType { private, support }

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// إرسال رسالة
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
    String? imageUrl,
    required ChatType type,
    String? chatId, // للدردشة الخاصة
    String? supportChatId, // للدعم
  }) async {
    final now = FieldValue.serverTimestamp();
    final msg = {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': now,
    };
    if (type == ChatType.private) {
      if (chatId == null) throw Exception('chatId required for private chat');
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(msg);
    } else {
      // دعم: كل رسالة تظهر لجميع الأدمن
      if (supportChatId == null) throw Exception('supportChatId required for support chat');
      await _firestore
          .collection('supportChats')
          .doc(supportChatId)
          .collection('messages')
          .add(msg);
    }
  }

  /// جلب رسائل الدردشة (Stream)
  Stream<QuerySnapshot> getMessages({
    required ChatType type,
    String? chatId,
    String? supportChatId,
  }) {
    if (type == ChatType.private) {
      if (chatId == null) throw Exception('chatId required for private chat');
      return _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp')
          .snapshots();
    } else {
      if (supportChatId == null) throw Exception('supportChatId required for support chat');
      return _firestore
          .collection('supportChats')
          .doc(supportChatId)
          .collection('messages')
          .orderBy('timestamp')
          .snapshots();
    }
  }

  /// إنشاء أو جلب معرف دردشة خاصة (بين مستخدمين)
  String getPrivateChatId(String userA, String userB) {
    // ترتيب ثابت لضمان نفس المعرف
    final sorted = [userA, userB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// إنشاء أو جلب معرف دردشة دعم (لكل مستخدم دردشة دعم واحدة مع كل الأدمن)
  String getSupportChatId(String userId) => userId;
}