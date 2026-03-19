import 'package:flutter/material.dart';
import 'merchant_orders_screen.dart';
import 'merchant_products_screen.dart';
import '../../../core/services/auth_storage.dart';
import '../../auth/presentation/login_screen.dart';

class MerchantHomeScreen extends StatefulWidget {
  const MerchantHomeScreen({super.key});

  @override
  State<MerchantHomeScreen> createState() => _MerchantHomeScreenState();
}

class _MerchantHomeScreenState extends State<MerchantHomeScreen> {
  int currentIndex = 0;

  final pages = [const MerchantOrdersScreen(), const MerchantProductsScreen()];

  final titles = ["الطلبات", "المنتجات"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[currentIndex]),
        backgroundColor: Colors.green,
        actions: [
          /// 🔥 تسجيل خروج (تم التعديل هنا)
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthStorage().logout(); // ✅ الحل الصحيح

              if (!context.mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),

      /// 📱 عرض الشاشة الحالية
      body: pages[currentIndex],

      /// 🔽 التنقل السفلي
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: Colors.green,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: "الطلبات",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: "المنتجات"),
        ],
      ),
    );
  }
}
