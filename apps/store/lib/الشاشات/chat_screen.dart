import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedstar_core/speedstar_core.dart';

class ChatScreen extends StatefulWidget {
  final String userId; // معرف المطعم للدعم
  const ChatScreen({super.key, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = ChatServiceArabic();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await _service.sendMessage(
      senderId: widget.userId,
      receiverId: 'support',
      text: text,
      type: ChatTypeArabic.support,
      supportChatId: _service.getSupportChatId(widget.userId),
    );
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final chatId = _service.getSupportChatId(widget.userId);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الدعم الفني')),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _service.getMessages(
                  type: ChatTypeArabic.support,
                  supportChatId: chatId,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final msgs = snapshot.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: msgs.length,
                    itemBuilder: (context, index) {
                      final m = msgs[index].data() as Map<String, dynamic>;
                      final isMe = m['senderId'] == widget.userId;
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFFFFF3E0) : const Color(0xFFE0F7FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(m['text'] ?? ''),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'اكتب رسالتك...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _send,
                      child: const Text('إرسال'),
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
