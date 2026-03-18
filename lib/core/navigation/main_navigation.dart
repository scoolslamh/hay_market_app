import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/account/presentation/account_screen.dart';
import '../state/providers.dart';

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int currentIndex = 0;

  // قائمة الشاشات
  final List<Widget> screens = const [
    HomeScreen(),
    OrdersScreen(),
    CartScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // 🔥 مراقبة حالة السلة عبر Riverpod لضمان تحديث العداد فوراً
    final cartService = ref.watch(cartServiceProvider);

    // مراقبة حالة التطبيق (الحي والماركت) لضمان استجابة الواجهة
    final appState = ref.watch(appStateProvider);

    return Scaffold(
      // استخدام IndexedStack يحافظ على حالة الشاشات (مثلاً مكان التوقف في القائمة)
      body: IndexedStack(index: currentIndex, children: screens),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        selectedItemColor: const Color(0xFF004D40), // لون دكان الحي المميز
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: "الرئيسية",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: "الطلبات",
          ),
          BottomNavigationBarItem(
            label: "السلة",
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_outlined),
                // ✅ العداد الآن يقرأ من النسخة الموحدة للسلة
                if (cartService.cartItems.isNotEmpty)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle, // شكل دائري أفضل
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ), // تحديد يبرز العداد
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        cartService.cartItems.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: "الحساب",
          ),
        ],
      ),
    );
  }
}
