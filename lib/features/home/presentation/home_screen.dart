import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/product_service.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/auth_storage.dart';
import '../../../core/models/product.dart';
import '../../../core/state/providers.dart';

import '../../markets/presentation/markets_screen.dart';
import '../../auth/presentation/login_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final productService = ProductService();
  final cartService = CartService();

  List<Product> products = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    final marketId = ref.read(appStateProvider).marketId;

    if (marketId == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final data = await productService.getProducts(marketId);

      setState(() {
        products = data.map<Product>((p) => Product.fromMap(p)).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void goBackToMarkets() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MarketsScreen()),
    );
  }

  Future<void> logout() async {
    final storage = AuthStorage();
    await storage.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final phone = appState.userPhone;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: goBackToMarkets,
        ),

        /// العنوان (الحي + الماركت)
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("الموقع", style: TextStyle(fontSize: 12)),

            Row(
              children: [
                const Icon(Icons.location_on, size: 16),

                const SizedBox(width: 4),

                Text(
                  appState.neighborhoodName ?? "",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            /// اسم الماركت
            if (appState.marketName != null)
              Text(
                appState.marketName!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),

        actions: [
          /// عداد السلة
          AnimatedBuilder(
            animation: cartService,
            builder: (context, _) {
              return Stack(
                children: [
                  if (cartService.count > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          cartService.count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          /// قائمة الحساب
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),

            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem(
                enabled: false,
                child: Text(
                  phone ?? "",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              const PopupMenuDivider(),

              const PopupMenuItem(
                value: "logout",
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text("تسجيل الخروج"),
                  ],
                ),
              ),
            ],

            onSelected: (value) {
              if (value == "logout") {
                logout();
              }
            },
          ),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : products.isEmpty
          ? const Center(child: Text("لا توجد منتجات"))
          : GridView.builder(
              padding: const EdgeInsets.all(10),

              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.75,
              ),

              itemCount: products.length,

              itemBuilder: (context, index) {
                final product = products[index];

                return Card(
                  elevation: 3,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: Padding(
                    padding: const EdgeInsets.all(8),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Center(
                            child:
                                product.image != null &&
                                    product.image!.isNotEmpty
                                ? Image.network(
                                    product.image!,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.image, size: 60),
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        Text(
                          "${product.price} ريال",
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const Spacer(),

                        SizedBox(
                          width: double.infinity,

                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add_shopping_cart),

                            label: const Text("إضافة"),

                            onPressed: () {
                              cartService.addToCart(product);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "${product.name} تمت إضافته للسلة",
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
