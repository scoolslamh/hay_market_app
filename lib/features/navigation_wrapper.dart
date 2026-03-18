import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home/presentation/home_screen.dart';
import 'cart/presentation/cart_screen.dart';
import 'orders/presentation/orders_screen.dart';

final navigationIndexProvider = StateProvider<int>((ref) => 0);

class NavigationWrapper extends ConsumerWidget {
  const NavigationWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navigationIndexProvider);

    final List<Widget> screens = [
      const HomeScreen(),
      const CartScreen(),
      const OrdersScreen(),
    ];

    return Scaffold(
      // الـ AppBar الرئيسي للتطبيق
      appBar: AppBar(title: const Text("دكان الحي"), centerTitle: true),
      body: IndexedStack(index: index, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (val) => ref.read(navigationIndexProvider.notifier).state = val,
        selectedItemColor: Colors.green[800],
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "الرئيسية"),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: "السلة",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "طلباتي"),
        ],
      ),
    );
  }
}
