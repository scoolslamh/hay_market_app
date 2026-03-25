import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/account/presentation/account_screen.dart';
import '../state/providers.dart';
import '../services/auth_storage.dart';

class MainNavigation extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  late int currentIndex;
  bool isLoading = true;

  final List<Widget> screens = const [
    HomeScreen(),
    OrdersScreen(),
    CartScreen(),
    AccountScreen(),
  ];

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;

    _loadSavedData(); // 🔥 استرجاع البيانات
  }

  /// 🔥 استرجاع الحي والماركت
  Future<void> _loadSavedData() async {
    try {
      final storage = AuthStorage();
      final data = await storage.getUserSelection().timeout(
        const Duration(seconds: 3),
      );

      final marketId = data['marketId'];
      final marketName = data['marketName'];
      final neighborhoodId = data['neighborhoodId'];
      final neighborhoodName = data['neighborhoodName'];

      if (marketId != null) {
        ref
            .read(appStateProvider.notifier)
            .setMarket(marketId, marketName ?? "");
      }

      if (neighborhoodId != null) {
        ref
            .read(appStateProvider.notifier)
            .setNeighborhood(neighborhoodId, neighborhoodName ?? "");
      }
    } catch (e) {
      debugPrint("loadSavedData error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartService = ref.watch(cartServiceProvider);

    /// ⏳ أثناء تحميل البيانات
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: screens),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        selectedItemColor: const Color(0xFF004D40),
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
                if (cartService.cartItems.isNotEmpty)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
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
