import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ClientWalletScreen extends StatefulWidget {
  final String clientId;
  const ClientWalletScreen({Key? key, required this.clientId}) : super(key: key);

  @override
  State<ClientWalletScreen> createState() => _ClientWalletScreenState();
}

class _ClientWalletScreenState extends State<ClientWalletScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('محفظتي'),
          backgroundColor: Colors.white,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Color(0xFFFE724C)),
          elevation: 1,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet, size: 80, color: Color(0xFFFE724C)),
              const SizedBox(height: 20),
              const Text('رصيدك الحالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
              const SizedBox(height: 10),
              // هنا يمكن إضافة كود لجلب الرصيد من قاعدة البيانات إذا رغبت بذلك
              Text('0 ج.س', style: const TextStyle(fontSize: 28, color: Colors.green)),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () {
                  // الانتقال إلى شاشة الشحن
                  Get.toNamed('/client_wallet_recharge', arguments: {'clientId': widget.clientId});
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('شحن المحفظة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFE724C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
