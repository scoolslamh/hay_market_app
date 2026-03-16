import 'package:flutter/material.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/account/presentation/account_screen.dart';
import '../services/cart_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;

  final CartService cartService = CartService();

  late final List<Widget> screens;

  @override
  void initState() {
    super.initState();

    screens = const [
      HomeScreen(),
      OrdersScreen(),
      CartScreen(),
      AccountScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: cartService,

      builder: (context, _) {
        return Scaffold(
          body: IndexedStack(index: currentIndex, children: screens),

          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: currentIndex,
            selectedItemColor: Colors.green,
            unselectedItemColor: Colors.grey,

            onTap: (index) {
              setState(() {
                currentIndex = index;
              });
            },

            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: "الرئيسية",
              ),

              const BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long),
                label: "الطلبات",
              ),

              BottomNavigationBarItem(
                label: "السلة",

                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.shopping_cart),

                    if (cartService.count > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),

                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),

                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),

                          child: Text(
                            cartService.count.toString(),

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
                icon: Icon(Icons.person),
                label: "الحساب",
              ),
            ],
          ),
        );
      },
    );
  }
}
