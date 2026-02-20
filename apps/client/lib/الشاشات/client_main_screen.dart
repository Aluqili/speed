import 'package:flutter/material.dart';
import 'client_home_tab.dart';
import 'client_orders_tab.dart';
import 'client_account_tab.dart';
import 'client_cart_screen.dart';

class ClientMainScreen extends StatefulWidget {
  final String clientId;

  const ClientMainScreen({Key? key, required this.clientId}) : super(key: key);

  @override
  State<ClientMainScreen> createState() => _ClientMainScreenState();
}

class _ClientMainScreenState extends State<ClientMainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> _tabs = [
      ClientHomeTab(clientId: widget.clientId),
      ClientOrdersTab(clientId: widget.clientId),
      ClientAccountTab(clientId: widget.clientId),
    ];

    return Scaffold(
      body: SafeArea(child: _tabs[_currentIndex]),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFFC107),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ClientCartScreen()),
          );
        },
        child: const Icon(Icons.shopping_cart),
      ),
      // ✅ نقل الزر إلى الزاوية بدل المنتصف
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFFFFC107),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'الطلبات'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'الحساب'),
        ],
      ),
    );
  }
}
