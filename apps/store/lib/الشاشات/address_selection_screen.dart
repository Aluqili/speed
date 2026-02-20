import 'package:flutter/material.dart';

class AddressSelectionScreen extends StatelessWidget {
  const AddressSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اختيار العنوان')),
      body: const Center(child: Text('اختيار العنوان (لاحقاً)')),
    );
  }
}
