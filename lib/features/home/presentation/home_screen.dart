import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/product_service.dart';
import '../../../core/models/product.dart';
import '../../../core/state/providers.dart';
import '../../markets/presentation/markets_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final productService = ProductService();

  List<Product> products = [];
  bool isLoading = true;
  String? lastLoadedMarketId;

  @override
  void initState() {
    super.initState();
    // التحميل الأولي للمنتجات
    Future.microtask(() => loadProducts());
  }

  Future<void> loadProducts() async {
    final marketId = ref.read(appStateProvider).marketId;

    if (marketId == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    // تجنب إعادة التحميل إذا لم يتغير المتجر
    if (marketId == lastLoadedMarketId && products.isNotEmpty) return;

    if (mounted) setState(() => isLoading = true);

    try {
      final data = await productService.getProducts(marketId);
      if (mounted) {
        setState(() {
          products = data.map<Product>((p) => Product.fromMap(p)).toList();
          isLoading = false;
          lastLoadedMarketId = marketId;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void goBackToMarkets() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MarketsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    // ✅ جلب نسخة السلة الموحدة من الـ Provider
    final cartService = ref.read(cartServiceProvider);

    // إعادة التحميل تلقائياً إذا تغير المتجر في الحالة
    if (appState.marketId != lastLoadedMarketId) {
      loadProducts();
    }

    return Scaffold(
      // ✅ أضفنا AppBar هنا ليعرض تفاصيل الحي والمتجر
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.storefront_outlined),
          onPressed: goBackToMarkets,
          tooltip: "تغيير المتجر",
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appState.neighborhoodName ?? "اختر الموقع",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            if (appState.marketName != null)
              Text(
                appState.marketName!,
                style: const TextStyle(fontSize: 12, color: Colors.greenAccent),
              ),
          ],
        ),
      ),
      // ✅ الجسم يحتوي على المنتجات فقط، والـ BottomNavigationBar سيكون في الشاشة الأم
      body: RefreshIndicator(
        onRefresh: loadProducts,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : products.isEmpty
            ? _buildEmptyState()
            : _buildProductsGrid(cartService),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.shopping_basket_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text("لا توجد منتجات متاحة حالياً"),
          TextButton(
            onPressed: loadProducts,
            child: const Text("إعادة المحاولة"),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid(var cartService) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.70, // تعديل بسيط لتناسب الأزرار
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(product, cartService);
      },
    );
  }

  Widget _buildProductCard(Product product, var cartService) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.grey[100],
              child: product.image != null && product.image!.isNotEmpty
                  ? Image.network(
                      product.image!,
                      fit: BoxFit.contain,
                      // ✅ معالجة أخطاء تحميل الصور (التي تظهر في صورتك)
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 40,
                      ),
                    )
                  : const Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "${product.price} ريال",
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF004D40,
                      ), // اللون الزيتي الخاص بك
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      // ✅ الإضافة للسلة عبر الخدمة الموحدة
                      cartService.addToCart(product);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("تمت إضافة ${product.name}"),
                          duration: const Duration(milliseconds: 800),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_shopping_cart, size: 16),
                        SizedBox(width: 4),
                        Text("إضافة"),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
