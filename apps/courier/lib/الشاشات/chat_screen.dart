import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:io';
import 'package:intl/intl.dart';

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
  final cloudinary = CloudinaryPublic('dvnzloec6', 'flutter_unsigned', cache: false);
  String otherUserName = '';

  @override
  void initState() {
    super.initState();
    _fetchOtherUserName();
  }

  Future<void> _fetchOtherUserName() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).get();
    if (doc.exists) {
      setState(() {
        otherUserName = doc.data()!['name'] ?? 'المستخدم';
      });
    }
  }

  Future<String> _detectUserType(String userId) async {
    final firestore = FirebaseFirestore.instance;
    if ((await firestore.collection('clients').doc(userId).get()).exists) return 'عميل';
    if ((await firestore.collection('drivers').doc(userId).get()).exists) return 'مندوب';
    if ((await firestore.collection('restaurants').doc(userId).get()).exists) return 'مطعم';
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
      'senderId': widget.currentUserId,
      'senderType': senderType,
      'senderName': widget.currentUserName,
      'receiverId': widget.otherUserId,
      'timestamp': FieldValue.serverTimestamp(),
      if (text != null) 'message': text.trim(),
      if (imageUrl != null) 'imageUrl': imageUrl,
    };

    await FirebaseFirestore.instance
        .collection('supportMessages')
        .add(message);

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
        CloudinaryFile.fromFile(file.path, resourceType: CloudinaryResourceType.Image),
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
    return DateFormat('hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUserId.isEmpty || widget.otherUserId.isEmpty || widget.chatId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('⚠️ لا يمكن فتح الدردشة بسبب نقص في المعرفات')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(otherUserName.isNotEmpty ? otherUserName : 'تحميل...'),
        backgroundColor: const Color(0xFFF57C00),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
            onSelected: (source) {
              _pickAndSendImage(source == 'camera' ? ImageSource.camera : ImageSource.gallery);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'camera', child: Text('الكاميرا')),
              const PopupMenuItem(value: 'gallery', child: Text('المعرض')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('supportMessages')
                  .where('conversationId', isEqualTo: widget.chatId)
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('حدث خطأ في تحميل الرسائل: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!.docs;
                if (messages.isEmpty) {
                  return const Center(child: Text('لا توجد رسائل بعد'));
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == widget.currentUserId;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFFFFF3E0) : const Color(0xFFE0E0E0),
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
                            if (data['imageUrl'] != null)
                              GestureDetector(
                                onTap: () => _showImagePreview(data['imageUrl']),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالتك...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(text: _messageController.text),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: () => _sendMessage(text: _messageController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
