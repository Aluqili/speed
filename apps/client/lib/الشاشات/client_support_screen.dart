import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClientSupportScreen extends StatefulWidget {
  const ClientSupportScreen({Key? key}) : super(key: key);

  static const Color primaryColor = Color(0xFFFE724C);
  static const Color backgroundColor = Color(0xFFF5F5F5);

  @override
  _ClientSupportScreenState createState() => _ClientSupportScreenState();
}

class _ClientSupportScreenState extends State<ClientSupportScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: ClientSupportScreen.backgroundColor,
        appBar: AppBar(
          title: const Text('خدمة العملاء',
              style: TextStyle(
                  color: ClientSupportScreen.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  fontFamily: 'Tajawal',
              )),
          backgroundColor: Colors.white,
          centerTitle: true,
          iconTheme: const IconThemeData(color: ClientSupportScreen.primaryColor),
          elevation: 1,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              Card(
                color: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  child: Column(
                    children: [
                      const Text(
                        'هل تحتاج إلى مساعدة؟',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: ClientSupportScreen.primaryColor,
                            fontFamily: 'Tajawal'),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'اكتب مشكلتك أو استفسارك وسيتم التواصل معك من قبل الإدارة مباشرة.',
                        style: TextStyle(fontSize: 15, color: Colors.grey, fontFamily: 'Tajawal'),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Card(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _messageController,
                        maxLines: 4,
                        style: const TextStyle(fontFamily: 'Tajawal'),
                        decoration: InputDecoration(
                          hintText: 'اكتب رسالتك هنا...',
                          hintStyle: const TextStyle(fontFamily: 'Tajawal'),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: ClientSupportScreen.backgroundColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.send, color: Colors.white),
                          label: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('إرسال', style: TextStyle(fontSize: 16, fontFamily: 'Tajawal')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ClientSupportScreen.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _sending ? null : _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;
    setState(() => _sending = true);
    // حفظ الرسالة في Firestore
    await FirebaseFirestore.instance
        .collection('supportMessages')
        .add({
      'senderType': 'client',
      'senderId': '', // ضع هنا معرف العميل إذا توفر
      'senderName': '', // ضع هنا اسم العميل إذا توفر
      'message': msg,
      'createdAt': FieldValue.serverTimestamp(),
    });
    setState(() => _sending = false);
    _messageController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إرسال رسالتك بنجاح!')),
    );
  }
}
