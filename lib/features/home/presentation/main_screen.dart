import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../orders/presentation/orders_screen.dart';

// مزود لإدارة التبويب الحالي
final navIndexProvider = StateProvider<int>((ref) => 0);

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navIndexProvider);

    // القائمة بالشاشات
    final List<Widget> screens = [
      const HomeScreen(),
      const CartScreen(),
      const OrdersScreen(),
    ];

    return Scaffold(
      // IndexedStack يحافظ على حالة الشاشات عند التنقل
      body: IndexedStack(index: selectedIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => ref.read(navIndexProvider.notifier).state = index,
        selectedItemColor: const Color(0xFF004D40), // اللون الزيتي الخاص بك
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'السلة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'طلباتي',
          ),
        ],
      ),
    );
  }
}
