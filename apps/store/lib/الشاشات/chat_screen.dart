import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:io';
import 'package:intl/intl.dart' as intl;
import 'package:speedstar_core/src/config/ops_runtime_config.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class ChatScreen extends StatefulWidget {
  final String userId; // معرف المطعم للدعم
  const ChatScreen({super.key, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final cloudinary = CloudinaryPublic('dvnzloec6', 'flutter_unsigned', cache: false);
  static const _primaryColor = AppThemeArabic.clientPrimary;
  bool _chatEnabled = true;
  String _chatDisabledMessage = 'الدردشة متوقفة مؤقتًا.';

  String get _actorUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  String get _chatId => '${_actorUid}-support';

  @override
  void initState() {
    super.initState();
    _loadChatConfig();
  }

  Future<void> _loadChatConfig() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.fetchAndActivate();
      final ops = OpsRuntimeConfig.fromRemoteConfig(rc, appKey: 'store');
      if (!mounted) return;
      setState(() {
        _chatEnabled = ops.chatEnabled;
        _chatDisabledMessage = ops.chatDisabledMessage;
      });
    } catch (_) {
      // Keep defaults
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_actorUid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('انتهت الجلسة، سجل الدخول مرة أخرى.')),
      );
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await FirebaseFirestore.instance.collection('supportMessages').add({
      'conversationId': _chatId,
      'chatKind': 'support',
      'sourceApp': 'store',
      'senderId': _actorUid,
      'senderType': 'مطعم',
      'senderName': 'المطعم',
      'restaurantId': widget.userId,
      'actorUid': _actorUid,
      'receiverId': 'support',
      'participants': [_actorUid, 'support'],
      'participantsKey': [_actorUid, 'support']..sort(),
      'timestamp': FieldValue.serverTimestamp(),
      'message': text,
    });
    _controller.clear();
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (_actorUid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('انتهت الجلسة، سجل الدخول مرة أخرى.')),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile == null) return;

    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(File(pickedFile.path).path, resourceType: CloudinaryResourceType.Image),
      );
      await FirebaseFirestore.instance.collection('supportMessages').add({
        'conversationId': _chatId,
        'chatKind': 'support',
        'sourceApp': 'store',
        'senderId': _actorUid,
        'senderType': 'مطعم',
        'senderName': 'المطعم',
        'restaurantId': widget.userId,
        'actorUid': _actorUid,
        'receiverId': 'support',
        'participants': [_actorUid, 'support'],
        'participantsKey': [_actorUid, 'support']..sort(),
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': response.secureUrl,
      });
    } catch (e) {
      if (!mounted) return;
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
          child: InteractiveViewer(child: Image.network(imageUrl)),
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    return intl.DateFormat('hh:mm a').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    if (!_chatEnabled) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppThemeArabic.clientBackground,
          appBar: AppBar(
            title: const Text('الدردشة', style: TextStyle(color: AppThemeArabic.clientPrimary, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
            backgroundColor: Colors.white,
            centerTitle: true,
            elevation: 1,
            iconTheme: const IconThemeData(color: AppThemeArabic.clientPrimary),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _chatDisabledMessage,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeArabic.clientBackground,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('الدعم الفني', style: TextStyle(color: AppThemeArabic.clientPrimary, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
          backgroundColor: Colors.white,
          centerTitle: true,
          elevation: 1,
          iconTheme: const IconThemeData(color: AppThemeArabic.clientPrimary),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('supportMessages')
                    .where('conversationId', isEqualTo: _chatId)
                    .orderBy('timestamp')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('تعذر تحميل الرسائل: ${snapshot.error}'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final msgs = snapshot.data!.docs;
                  if (msgs.isEmpty) {
                    return const Center(child: Text('لا توجد رسائل بعد'));
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: msgs.length,
                    itemBuilder: (context, index) {
                      final m = msgs[index].data() as Map<String, dynamic>;
                      final isMe = m['senderId'] == _actorUid;
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: isMe
                                ? AppThemeArabic.clientSurface
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe && (m['senderName'] ?? '').toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    (m['senderName'] ?? '').toString(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              if (m['imageUrl'] != null)
                                GestureDetector(
                                  onTap: () => _showImagePreview((m['imageUrl'] ?? '').toString()),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      (m['imageUrl'] ?? '').toString(),
                                      height: 180,
                                      width: 180,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              else
                                Text((m['message'] ?? m['text'] ?? '').toString()),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(m['timestamp']),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.add_photo_alternate, color: _primaryColor),
                      onSelected: (source) {
                        _pickAndSendImage(
                          source == 'camera' ? ImageSource.camera : ImageSource.gallery,
                        );
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'camera', child: Text('الكاميرا')),
                        PopupMenuItem(value: 'gallery', child: Text('المعرض')),
                      ],
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'اكتب رسالتك...',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: _primaryColor),
                      onPressed: _send,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
