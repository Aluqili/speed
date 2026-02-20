/// خدمة المحادثة: دردشة خاصة ودعم فني.
import 'package:cloud_firestore/cloud_firestore.dart';

/// نوع الدردشة: خاصة أم دعم
enum ChatTypeArabic { private, support }

class ChatServiceArabic {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// إرسال رسالة
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
    String? imageUrl,
    required ChatTypeArabic type,
    String? chatId,
    String? supportChatId,
  }) async {
    final now = FieldValue.serverTimestamp();
    final msg = {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': now,
    };
    if (type == ChatTypeArabic.private) {
      if (chatId == null) {
        throw Exception('chatId required for private chat');
      }
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(msg);
    } else {
      if (supportChatId == null) {
        throw Exception('supportChatId required for support chat');
      }
      await _firestore
          .collection('supportChats')
          .doc(supportChatId)
          .collection('messages')
          .add(msg);
    }
  }

  /// جلب رسائل الدردشة (Stream)
  Stream<QuerySnapshot> getMessages({
    required ChatTypeArabic type,
    String? chatId,
    String? supportChatId,
  }) {
    if (type == ChatTypeArabic.private) {
      if (chatId == null) {
        throw Exception('chatId required for private chat');
      }
      return _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp')
          .snapshots();
    } else {
      if (supportChatId == null) {
        throw Exception('supportChatId required for support chat');
      }
      return _firestore
          .collection('supportChats')
          .doc(supportChatId)
          .collection('messages')
          .orderBy('timestamp')
          .snapshots();
    }
  }

  /// إنشاء معرف دردشة خاصة ثابت (بين مستخدمين)
  String getPrivateChatId(String userA, String userB) {
    final sorted = [userA, userB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// إنشاء معرف دردشة دعم (لكل مستخدم دردشة دعم واحدة)
  String getSupportChatId(String userId) => userId;
}
