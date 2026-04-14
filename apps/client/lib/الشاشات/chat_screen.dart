import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/src/config/ops_runtime_config.dart';

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String otherUserId;
  final String currentUserRole;
  final String chatId;
  final String currentUserName;

  const ChatScreen({
    Key? key,
    required this.currentUserId,
    required this.otherUserId,
    required this.currentUserRole,
    required this.chatId,
    required this.currentUserName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final cloudinary =
      CloudinaryPublic('dvnzloec6', 'flutter_unsigned', cache: false);
  String otherUserName = '';
  bool _chatEnabled = true;
  String _chatDisabledMessage = 'الدردشة متوقفة مؤقتًا.';
  static const String _closedSupportTicketMessage =
      'أغلق الدعم الفني هذه التذكرة. يمكنك قراءة المحادثة السابقة فقط.';

  bool get _isSupportChat =>
      widget.otherUserId == 'support' || widget.chatId.endsWith('-support');

  String get _chatKind => _isSupportChat ? 'support' : 'direct';

  String get _sourceApp => 'client';

  int _timestampMillis(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    return 0;
  }

  String _buildNewSupportChatId() {
    return '${widget.currentUserId}-support-${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _startNewSupportTicket() async {
    final newChatId = _buildNewSupportChatId();

    try {
      await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.currentUserId)
          .set({
        'lastSupportConversationId': newChatId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Navigation should still proceed even if the metadata update fails.
    }

    if (!mounted) return;

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUserId: widget.currentUserId,
          otherUserId: widget.otherUserId,
          currentUserRole: widget.currentUserRole,
          chatId: newChatId,
          currentUserName: widget.currentUserName,
        ),
      ),
    );
  }

  void _onMessageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
    _loadChatConfig();
    _fetchOtherUserName();
  }

  Future<void> _loadChatConfig() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.fetchAndActivate();
      final ops = OpsRuntimeConfig.fromRemoteConfig(rc, appKey: 'client');
      if (!mounted) return;
      setState(() {
        _chatEnabled = ops.chatEnabled;
        _chatDisabledMessage = ops.chatDisabledMessage;
      });
    } catch (_) {
      // Keep defaults
    }
  }

  Future<String?> _findUserNameInCollection(
      String collection, String userId) async {
    try {
      final directDoc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(userId)
          .get();
      if (directDoc.exists) {
        final data = directDoc.data() ?? <String, dynamic>{};
        final name =
            (data['name'] ?? data['fullName'] ?? data['displayName'] ?? '')
                .toString()
                .trim();
        if (name.isNotEmpty) return name;
      }

      final candidateFields = ['ownerUid', 'uid', 'userId'];
      for (final field in candidateFields) {
        final query = await FirebaseFirestore.instance
            .collection(collection)
            .where(field, isEqualTo: userId)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          final name =
              (data['name'] ?? data['fullName'] ?? data['displayName'] ?? '')
                  .toString()
                  .trim();
          if (name.isNotEmpty) return name;
        }
      }
    } catch (_) {
      // Ignore and continue fallback chain
    }
    return null;
  }

  Future<void> _fetchOtherUserName() async {
    if (_isSupportChat) {
      if (!mounted) return;
      setState(() {
        otherUserName = 'الدعم الفني';
      });
      return;
    }

    final fallbackCollections = ['clients', 'drivers', 'restaurants'];
    for (final col in fallbackCollections) {
      final name = await _findUserNameInCollection(col, widget.otherUserId);
      if (name != null && name.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          otherUserName = name;
        });
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      otherUserName = 'المستخدم';
    });
  }

  Future<String> _detectUserType(String userId) async {
    final firestore = FirebaseFirestore.instance;
    if ((await firestore.collection('clients').doc(userId).get()).exists)
      return 'عميل';
    if ((await firestore.collection('drivers').doc(userId).get()).exists)
      return 'مندوب';
    if ((await firestore.collection('restaurants').doc(userId).get()).exists)
      return 'مطعم';
    return 'غير معروف';
  }

  void _sendMessage({String? text, String? imageUrl}) async {
    if ((text == null || text.trim().isEmpty) && imageUrl == null) return;

    String senderType = widget.currentUserRole;
    if (senderType.isEmpty || senderType == 'غير معروف') {
      senderType = await _detectUserType(widget.currentUserId);
    }

    final message = {
      'conversationId': widget.chatId,
      'chatKind': _chatKind,
      'sourceApp': _sourceApp,
      'senderId': widget.currentUserId,
      'senderType': senderType,
      'senderName': widget.currentUserName,
      'receiverId': widget.otherUserId,
      'participants': [widget.currentUserId, widget.otherUserId],
      'participantsKey': [widget.currentUserId, widget.otherUserId]..sort(),
      'timestamp': FieldValue.serverTimestamp(),
      if (_isSupportChat) 'status': 'open',
      if (text != null) 'message': text.trim(),
      if (imageUrl != null) 'imageUrl': imageUrl,
    };

    await FirebaseFirestore.instance.collection('supportMessages').add(message);

    if (_isSupportChat) {
      await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.currentUserId)
          .set({
        'lastSupportConversationId': widget.chatId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    _messageController.clear();
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);

    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(file.path,
            resourceType: CloudinaryResourceType.Image),
      );
      _sendMessage(imageUrl: response.secureUrl);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل رفع الصورة: $e')),
      );
    }
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(imageUrl),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return DateFormat('hh:mm a', 'ar').format(date);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUserId.isEmpty ||
        widget.otherUserId.isEmpty ||
        widget.chatId.isEmpty) {
      return const Scaffold(
        body:
            Center(child: Text('⚠️ لا يمكن فتح الدردشة بسبب نقص في المعرفات')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(otherUserName.isNotEmpty ? otherUserName : 'تحميل...'),
        backgroundColor: AppThemeArabic.clientPrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _isSupportChat
                  ? (_chatEnabled
                      ? 'محادثة دعم'
                      : 'محادثة دعم متاحة الآن رغم الإيقاف المؤقت')
                  : 'محادثة مباشرة',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
            enabled: !_isSupportChat,
            onSelected: (source) {
              _pickAndSendImage(source == 'camera'
                  ? ImageSource.camera
                  : ImageSource.gallery);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'camera', child: Text('الكاميرا')),
              const PopupMenuItem(value: 'gallery', child: Text('المعرض')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('supportMessages')
            .where('conversationId', isEqualTo: widget.chatId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('حدث خطأ في تحميل الرسائل: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final messages = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              return _timestampMillis(aData['timestamp'])
                  .compareTo(_timestampMillis(bData['timestamp']));
            });

          final latestData = messages.isNotEmpty
              ? messages.last.data() as Map<String, dynamic>
              : <String, dynamic>{};
          final supportConversationClosed = _isSupportChat &&
              (latestData['status'] ?? 'open').toString() == 'closed';
          final canCompose = !supportConversationClosed;

          if (messages.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(
                  _scrollController.position.maxScrollExtent,
                );
              }
            });
          }

          return Column(
            children: [
              if (_isSupportChat && !_chatEnabled)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: Text(
                    'تم فتح مراسلة الدعم للعملاء مباشرة. التنبيه الحالي من الإعدادات كان: $_chatDisabledMessage',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ),
              if (supportConversationClosed)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCC80)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        _closedSupportTicketMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _startNewSupportTicket,
                          icon: const Icon(Icons.add_comment_outlined),
                          label: const Text('فتح تذكرة جديدة'),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: messages.isEmpty
                    ? const Center(child: Text('لا توجد رسائل بعد'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final data =
                              messages[index].data() as Map<String, dynamic>;
                          final isMe = data['senderId'] == widget.currentUserId;
                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(10),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.7,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFFFFF3E0)
                                    : const Color(0xFFE0E0E0),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: Radius.circular(isMe ? 12 : 0),
                                  bottomRight: Radius.circular(isMe ? 0 : 12),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe &&
                                      (data['senderName'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        (data['senderName'] ?? '').toString(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                  if (data['imageUrl'] != null)
                                    GestureDetector(
                                      onTap: () =>
                                          _showImagePreview(data['imageUrl']),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          data['imageUrl'],
                                          height: 180,
                                          width: 180,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      data['message'] ?? '',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _formatTimestamp(data['timestamp']),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        enabled: canCompose,
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: canCompose
                              ? 'اكتب رسالتك...'
                              : 'التذكرة مغلقة ولا يمكن إضافة رد جديد',
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: canCompose
                            ? (_) => _sendMessage(text: _messageController.text)
                            : null,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.send,
                        color: canCompose
                            ? AppThemeArabic.clientPrimary
                            : Colors.grey,
                      ),
                      onPressed: !canCompose ||
                              _messageController.text.trim().isEmpty
                          ? null
                          : () => _sendMessage(text: _messageController.text),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
