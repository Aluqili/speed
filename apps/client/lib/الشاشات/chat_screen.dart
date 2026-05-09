import 'dart:io';
import 'package:flutter/material.dart';
import '../الثيم/client_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;

import '../الخدمات/cloudinary_service.dart';

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String otherUserId;
  final String currentUserRole;
  final String chatId;
  final String currentUserName;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.otherUserId,
    required this.currentUserRole,
    required this.chatId,
    required this.currentUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const Color _primary = ClientColors.primary;

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _cloudinary = CloudinaryService.build();

  String _otherUserName = '';
  bool _sendingImage = false;

  // ─── تحديد الـ collection الصحيحة ─────────────────────────────────────────
  // المندوب يكتب في 'chats' للدردشة المباشرة
  // والدعم الفني في 'supportMessages'
  bool get _isSupportChat =>
      widget.otherUserId == 'support' ||
      widget.chatId.contains('-support');

  String get _collection => _isSupportChat ? 'supportMessages' : 'chats';

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() => setState(() {}));
    _fetchOtherUserName();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── data ──────────────────────────────────────────────────────────────────

  Future<void> _fetchOtherUserName() async {
    for (final col in ['clients', 'drivers', 'restaurants']) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(col)
            .doc(widget.otherUserId)
            .get();
        if (doc.exists) {
          final d = doc.data() ?? {};
          final name =
              (d['name'] ?? d['fullName'] ?? d['displayName'] ?? '')
                  .toString()
                  .trim();
          if (name.isNotEmpty) {
            if (mounted) setState(() => _otherUserName = name);
            return;
          }
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _otherUserName = 'المستخدم');
  }

  /// تسجيل آخر وقت قراءة للمحادثة
  Future<void> _markAsRead() async {
    if (widget.currentUserId.isEmpty || widget.chatId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.currentUserId)
          .collection('chatReadStatus')
          .doc(widget.chatId)
          .set(
            {'lastReadAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true),
          );
    } catch (_) {}
  }

  Stream<List<Map<String, dynamic>>> get _messagesStream =>
      FirebaseFirestore.instance
          .collection(_collection)
          .where('conversationId', isEqualTo: widget.chatId)
          .snapshots(includeMetadataChanges: true)
          .map((snap) {
        final docs = snap.docs
            .map((d) => {'_id': d.id, ...d.data()})
            .toList();
        docs.sort((a, b) {
          final at = _tsMillis(a['timestamp']);
          final bt = _tsMillis(b['timestamp']);
          return at.compareTo(bt);
        });
        return docs;
      });

  int _tsMillis(dynamic v) {
    if (v is Timestamp) return v.millisecondsSinceEpoch;
    return 0;
  }

  Future<void> _sendMessage({String? text, String? imageUrl}) async {
    if ((text == null || text.trim().isEmpty) && imageUrl == null) return;

    final message = {
      'conversationId': widget.chatId,
      'chatKind': _isSupportChat ? 'support' : 'direct',
      'sourceApp': 'client',
      'senderId': widget.currentUserId,
      'senderType': widget.currentUserRole.isNotEmpty
          ? widget.currentUserRole
          : 'client',
      'senderName': widget.currentUserName,
      'receiverId': widget.otherUserId,
      'participants': [widget.currentUserId, widget.otherUserId],
      'participantsKey': ([widget.currentUserId, widget.otherUserId]..sort()),
      'timestamp': FieldValue.serverTimestamp(),
      if (text != null && text.trim().isNotEmpty) 'message': text.trim(),
      if (imageUrl != null) 'imageUrl': imageUrl,
    };

    await FirebaseFirestore.instance.collection(_collection).add(message);
    _messageController.clear();
    // تحديث وقت القراءة عند الإرسال أيضاً
    _markAsRead();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 70);
    if (picked == null) return;
    setState(() => _sendingImage = true);
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(File(picked.path).path,
            resourceType: CloudinaryResourceType.Image),
      );
      await _sendMessage(imageUrl: response.secureUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل رفع الصورة: $e')));
      }
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
  }

  void _showImagePreview(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(child: Image.network(url)),
        ),
      ),
    );
  }

  String _formatTime(dynamic ts) {
    if (ts == null || ts is! Timestamp) return '';
    try {
      return intl.DateFormat('hh:mm a', 'ar').format(ts.toDate().toLocal());
    } catch (_) {
      return '';
    }
  }

  // ─── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.currentUserId.isEmpty ||
        widget.otherUserId.isEmpty ||
        widget.chatId.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
              backgroundColor: _primary,
              title: const Text('دردشة',
                  style: TextStyle(color: Colors.white))),
          body: const Center(
              child: Text('تعذر فتح الدردشة — بيانات غير مكتملة.')),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            Expanded(child: _buildMessagesList()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0.5,
      centerTitle: false,
      iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _primary.withValues(alpha: 0.12),
            child: const Icon(Icons.person_rounded, color: _primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _otherUserName.isNotEmpty ? _otherUserName : '...',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _isSupportChat ? 'الدعم الفني' : 'عبر الدردشة الفورية',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (!_sendingImage)
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_photo_alternate_outlined,
                color: Colors.black87),
            onSelected: (v) => _pickAndSendImage(
                v == 'camera' ? ImageSource.camera : ImageSource.gallery),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'camera',
                  child: Row(children: [
                    Icon(Icons.camera_alt_outlined),
                    SizedBox(width: 8),
                    Text('الكاميرا')
                  ])),
              PopupMenuItem(
                  value: 'gallery',
                  child: Row(children: [
                    Icon(Icons.photo_library_outlined),
                    SizedBox(width: 8),
                    Text('المعرض')
                  ])),
            ],
          )
        else
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _messagesStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text('تعذر تحميل الرسائل',
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        final messages = snap.data ?? [];

        if (messages.isNotEmpty) {
          _scrollToBottom();
          // تحديث وقت القراءة عند وصول رسائل جديدة
          _markAsRead();
        }

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 56, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('لا توجد رسائل بعد',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                const SizedBox(height: 4),
                Text('ابدأ المحادثة الآن',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          itemCount: messages.length,
          itemBuilder: (context, i) {
            final msg = messages[i];
            final isMe = msg['senderId'] == widget.currentUserId;
            final showName = !isMe &&
                (_otherUserName.isNotEmpty &&
                    (msg['senderName'] ?? '').toString().isNotEmpty);
            return _MessageBubble(
              message: msg,
              isMe: isMe,
              showSenderName: showName,
              senderName: (msg['senderName'] ?? _otherUserName).toString(),
              time: _formatTime(msg['timestamp']),
              onImageTap: _showImagePreview,
            );
          },
        );
      },
    );
  }

  Widget _buildInputBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) =>
                    _sendMessage(text: _messageController.text),
                maxLines: null,
                style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالتك...',
                  hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _messageController.text.trim().isNotEmpty
                  ? _primary
                  : (isDark ? const Color(0xFF333333) : Colors.grey[300]),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, size: 20),
              color: Colors.white,
              onPressed: _messageController.text.trim().isEmpty
                  ? null
                  : () => _sendMessage(text: _messageController.text),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Message Bubble ────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showSenderName,
    required this.senderName,
    required this.time,
    required this.onImageTap,
  });

  final Map<String, dynamic> message;
  final bool isMe;
  final bool showSenderName;
  final String senderName;
  final String time;
  final void Function(String url) onImageTap;

  static const _primary = ClientColors.primary;

  @override
  Widget build(BuildContext context) {
    final text = (message['message'] ?? message['text'] ?? '').toString();
    final imageUrl = message['imageUrl'] as String?;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
            bottom: 8,
            right: isMe ? 0 : 40,
            left: isMe ? 40 : 0),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showSenderName)
              Padding(
                padding: const EdgeInsets.only(bottom: 2, right: 4, left: 4),
                child: Text(senderName,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _primary)),
              ),
            Container(
              padding: imageUrl != null
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? _primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 4,
                      offset: Offset(0, 1))
                ],
              ),
              child: imageUrl != null
                  ? GestureDetector(
                      onTap: () => onImageTap(imageUrl),
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                        ),
                        child: Image.network(imageUrl,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                    ? child
                                    : const SizedBox(
                                        width: 200,
                                        height: 200,
                                        child: Center(
                                            child:
                                                CircularProgressIndicator()))),
                      ),
                    )
                  : Text(
                      text,
                      style: TextStyle(
                          fontSize: 15,
                          color: isMe ? Colors.white : Theme.of(context).colorScheme.onSurface,
                          height: 1.4),
                    ),
            ),
            if (time.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.only(top: 3, right: 4, left: 4),
                child: Text(
                  time,
                  style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

