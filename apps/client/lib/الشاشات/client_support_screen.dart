import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class ClientSupportScreen extends StatefulWidget {
  final String userId;

  const ClientSupportScreen({super.key, required this.userId});

  @override
  State<ClientSupportScreen> createState() => _ClientSupportScreenState();
}

class _ClientSupportScreenState extends State<ClientSupportScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final cloudinary =
      CloudinaryPublic('dvnzloec6', 'flutter_unsigned', cache: false);
  static const _primaryColor = AppThemeArabic.clientPrimary;
  static const _closedSupportTicketMessage =
      'أغلق الدعم الفني هذه التذكرة. يمكنك قراءة المحادثة السابقة فقط.';
  bool _loadingConversation = true;
  String _supportConversationId = '';
  String _clientDisplayName = 'العميل';

  void _onMessageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  String get _actorUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  String _buildDefaultConversationId() => '${_actorUid}-support';

  String _buildNewSupportChatId() {
    return '${_actorUid}-support-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onMessageChanged);
    _bootstrapSupportConversation();
  }

  Future<void> _bootstrapSupportConversation() async {
    if (_actorUid.isEmpty) {
      if (!mounted) return;
      setState(() => _loadingConversation = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.userId)
          .get();
      final data = doc.data() ?? <String, dynamic>{};
      final savedConversationId =
          (data['lastSupportConversationId'] ?? '').toString().trim();
      final displayName =
          (data['name'] ?? data['fullName'] ?? 'العميل').toString().trim();
      if (!mounted) return;
      setState(() {
        _supportConversationId = savedConversationId.isNotEmpty
            ? savedConversationId
            : _buildDefaultConversationId();
        _clientDisplayName = displayName.isNotEmpty ? displayName : 'العميل';
        _loadingConversation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _supportConversationId = _buildDefaultConversationId();
        _loadingConversation = false;
      });
    }
  }

  Future<void> _persistConversationId(String conversationId) async {
    await FirebaseFirestore.instance.collection('clients').doc(widget.userId).set({
      'lastSupportConversationId': conversationId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _startNewSupportTicket() async {
    if (_actorUid.isEmpty) return;
    final newConversationId = _buildNewSupportChatId();
    try {
      await _persistConversationId(newConversationId);
    } catch (_) {
    }
    if (!mounted) return;
    setState(() {
      _supportConversationId = newConversationId;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onMessageChanged);
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
    if (text.isEmpty || _supportConversationId.isEmpty) return;
    await FirebaseFirestore.instance.collection('supportMessages').add({
      'conversationId': _supportConversationId,
      'chatKind': 'support',
      'sourceApp': 'client',
      'senderId': _actorUid,
      'senderType': 'client',
      'senderName': _clientDisplayName,
      'clientId': widget.userId,
      'actorUid': _actorUid,
      'receiverId': 'support',
      'participants': [_actorUid, 'support'],
      'participantsKey': [_actorUid, 'support']..sort(),
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'open',
      'message': text,
    });
    await _persistConversationId(_supportConversationId);
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

    if (_supportConversationId.isEmpty) return;

    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(File(pickedFile.path).path,
            resourceType: CloudinaryResourceType.Image),
      );
      await FirebaseFirestore.instance.collection('supportMessages').add({
        'conversationId': _supportConversationId,
        'chatKind': 'support',
        'sourceApp': 'client',
        'senderId': _actorUid,
        'senderType': 'client',
        'senderName': _clientDisplayName,
        'clientId': widget.userId,
        'actorUid': _actorUid,
        'receiverId': 'support',
        'participants': [_actorUid, 'support'],
        'participantsKey': [_actorUid, 'support']..sort(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'open',
        'imageUrl': response.secureUrl,
      });
      await _persistConversationId(_supportConversationId);
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

  int _timestampMillis(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingConversation) {
      return const Scaffold(
        backgroundColor: AppThemeArabic.clientBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeArabic.clientBackground,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('الدعم الفني',
              style: TextStyle(
                  color: AppThemeArabic.clientPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  fontFamily: 'Tajawal')),
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
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppThemeArabic.clientPrimary, Color(0xFF0EA5E9)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تواصل مع الدعم الفني',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _clientDisplayName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('supportMessages')
                    .where('conversationId', isEqualTo: _supportConversationId)
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

                  final msgs = snapshot.data!.docs.toList()
                    ..sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      return _timestampMillis(aData['timestamp'])
                          .compareTo(_timestampMillis(bData['timestamp']));
                    });
                  final latestData = msgs.isNotEmpty
                      ? msgs.last.data() as Map<String, dynamic>
                      : <String, dynamic>{};
                  final supportConversationClosed =
                      (latestData['status'] ?? 'open').toString() == 'closed';

                  if (msgs.isNotEmpty) {
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
                      if (supportConversationClosed)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(16),
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
                        child: msgs.isEmpty
                            ? const Center(
                                child: Text(
                                  'لا توجد رسائل بعد',
                                  style: TextStyle(fontFamily: 'Tajawal'),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(12),
                                itemCount: msgs.length,
                                itemBuilder: (context, index) {
                                  final m = msgs[index].data()
                                      as Map<String, dynamic>;
                                  final isMe = m['senderId'] == _actorUid;
                                  return Align(
                                    alignment: isMe
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? AppThemeArabic.clientSurface
                                            : Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: isMe
                                              ? AppThemeArabic.clientPrimary
                                                  .withOpacity(0.10)
                                              : Colors.transparent,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (!isMe &&
                                              (m['senderName'] ?? '')
                                                  .toString()
                                                  .isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 4),
                                              child: Text(
                                                (m['senderName'] ?? '')
                                                    .toString(),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ),
                                          if (m['imageUrl'] != null)
                                            GestureDetector(
                                              onTap: () => _showImagePreview(
                                                  (m['imageUrl'] ?? '')
                                                      .toString()),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  (m['imageUrl'] ?? '')
                                                      .toString(),
                                                  height: 180,
                                                  width: 180,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            )
                                          else
                                            Text(
                                              (m['message'] ?? m['text'] ?? '')
                                                  .toString(),
                                              style: const TextStyle(
                                                  fontFamily: 'Tajawal'),
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatTimestamp(m['timestamp']),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.add_photo_alternate,
                            color: _primaryColor),
                        onSelected: (source) {
                          _pickAndSendImage(
                            source == 'camera'
                                ? ImageSource.camera
                                : ImageSource.gallery,
                          );
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                              value: 'camera', child: Text('الكاميرا')),
                          PopupMenuItem(
                              value: 'gallery', child: Text('المعرض')),
                        ],
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: _supportConversationId.isNotEmpty,
                          textInputAction: TextInputAction.send,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'اكتب رسالتك...',
                            filled: true,
                            fillColor: AppThemeArabic.clientSurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('supportMessages')
                            .where('conversationId',
                                isEqualTo: _supportConversationId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final latest = snapshot.data?.docs.isNotEmpty == true
                              ? snapshot.data!.docs.last.data()
                                  as Map<String, dynamic>
                              : <String, dynamic>{};
                          final canCompose =
                              (latest['status'] ?? 'open').toString() !=
                                  'closed';
                          return IconButton(
                            icon: const Icon(Icons.send_rounded,
                                color: _primaryColor),
                            onPressed:
                                _controller.text.trim().isEmpty || !canCompose
                                    ? null
                                    : () => _send(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}