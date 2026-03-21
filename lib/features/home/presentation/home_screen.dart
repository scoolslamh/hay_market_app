import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/services/product_service.dart';
import '../../../core/services/cart_service.dart';
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

  // ✅ الأقسام والفلترة
  List<Map<String, dynamic>> categories = [];
  String? selectedCategoryId;
  bool loadingCategories = true;

  // ✅ البحث
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static const Color _primary = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      loadProducts();
      _loadCategories();
    });
  }

  /// ✅ جلب الأقسام من Supabase
  Future<void> _loadCategories() async {
    try {
      final data = await Supabase.instance.client
          .from('categories')
          .select()
          .order('sort_order', ascending: true);

      if (mounted) {
        setState(() {
          categories = List<Map<String, dynamic>>.from(data);
          loadingCategories = false;
        });
      }
    } catch (e) {
      debugPrint("Load categories error: $e");
      if (mounted) setState(() => loadingCategories = false);
    }
  }

  Future<void> loadProducts() async {
    final marketId = ref.read(appStateProvider).marketId;

    if (marketId == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

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
    final cartService = ref.read(cartServiceProvider);

    if (appState.marketId != lastLoadedMarketId) {
      loadProducts();
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],

      // ── الهيدر المحسّن ──
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // يسار: الموقع
              GestureDetector(
                onTap: goBackToMarkets,
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.black87,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              appState.neighborhoodName ?? "اختر موقعك",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                        if (appState.marketName != null)
                          Text(
                            appState.marketName ?? "",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // يمين: اسم المتجر
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (appState.neighborhoodName != null)
                    Text(
                      "حي ${appState.neighborhoodName}",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  Text(
                    appState.marketName ?? "دكان الحارة",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      // ── الجسم ──
      body: RefreshIndicator(
        onRefresh: loadProducts,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : products.isEmpty
            ? _buildEmptyState()
            : _buildBody(cartService),
      ),
    );
  }

  // ✅ البنر + المنتجات في ListView واحد
  Widget _buildBody(CartService cartService) {
    // ✅ فلترة المنتجات حسب القسم + البحث
    final filteredProducts = products.where((p) {
      final matchCategory =
          selectedCategoryId == null || p.categoryId == selectedCategoryId;
      final matchSearch =
          _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCategory && matchSearch;
    }).toList();

    return ListView(
      children: [
        // ── حقل البحث ──
        _buildSearchBar(),

        // ── البنر الإعلاني ──
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          height: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // زر تسوق الآن - بعرض محدد
                SizedBox(
                  width: 110,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF388E3C),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      "تسوق الآن",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "عروض وخصومات حصرية",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "اكتشف الجديد في المتجر",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── أقسام البقالة (تمرير أفقي) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "أقسام البقالة",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () => setState(() => selectedCategoryId = null),
                child: const Text(
                  "عرض الكل ←",
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        // ✅ تمرير أفقي انسيابي
        loadingCategories
            ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              )
            : SizedBox(
                height: 95,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = selectedCategoryId == cat['id'];
                    return GestureDetector(
                      onTap: () => setState(() {
                        selectedCategoryId = isSelected
                            ? null
                            : cat['id'] as String;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 80,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF4CAF50)
                                : Colors.grey.shade200,
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              cat['emoji'] ?? '📦',
                              style: const TextStyle(fontSize: 28),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              cat['name'] ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? const Color(0xFF388E3C)
                                    : Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            "المنتجات",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),

        // ── عنوان المنتجات مع اسم القسم المختار ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                selectedCategoryId != null
                    ? categories.firstWhere(
                        (c) => c['id'] == selectedCategoryId,
                        orElse: () => {'name': 'المنتجات'},
                      )['name']
                    : "جميع المنتجات",
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${filteredProducts.length} منتج",
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),

        // ✅ حالة لا توجد منتجات في هذا القسم
        if (filteredProducts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    _searchQuery.isNotEmpty
                        ? Icons.search_off
                        : Icons.inbox_outlined,
                    size: 50,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isNotEmpty
                        ? "لا توجد نتائج لـ \"$_searchQuery\""
                        : "لا توجد منتجات في هذا القسم",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          // ✅ GridView بالمنتجات المفلترة
          GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) =>
                _buildProductCard(filteredProducts[index], cartService),
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        textAlign: TextAlign.right,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: "ابحث عن منتج...",
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          prefixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Icon(Icons.close, color: Colors.grey, size: 20),
                )
              : null,
          suffixIcon: Container(
            margin: const EdgeInsets.all(6),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.search, color: Colors.white, size: 20),
          ),
        ),
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

  /// ✅ Supabase Image Transform — يضبط الحجم والجودة تلقائياً
  String _transformImageUrl(String url) {
    // فقط صور Supabase Storage تدعم التحويل
    if (!url.contains('supabase')) return url;

    // إذا كان الـ URL يحتوي على /object/public نحوله لـ /render/image
    final transformed = url.replaceFirst(
      '/object/public/',
      '/render/image/public/',
    );

    return '$transformed?width=300&height=300&resize=contain&quality=80';
  }

  /// ✅ شعار التطبيق كـ placeholder عند غياب صورة المنتج
  Widget _buildLogoPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFE8F5E9), // أخضر فاتح جداً
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Image.asset(
          'assets/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(
              Icons.storefront_outlined,
              color: Color(0xFF4CAF50),
              size: 36,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product, CartService cartService) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── صورة المنتج ──
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Container(
                width: double.infinity,
                color: const Color(0xFFF8F8F8),
                child: product.image != null && product.image!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _transformImageUrl(product.image ?? ""),
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        ),
                        fadeInDuration: const Duration(milliseconds: 300),
                        fadeOutDuration: const Duration(milliseconds: 100),
                        // ✅ عند خطأ التحميل → شعار التطبيق
                        errorWidget: (_, __, ___) => _buildLogoPlaceholder(),
                      )
                    // ✅ لا توجد صورة → شعار التطبيق
                    : _buildLogoPlaceholder(),
              ),
            ),
          ),

          // ── تفاصيل المنتج ──
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // اسم المنتج
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // السعر + زر الإضافة
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ✅ رمز الريال السعودي
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            product.price % 1 == 0
                                ? product.price.toInt().toString()
                                : product.price.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Text(
                            "﷼",
                            style: TextStyle(
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),

                      // ✅ زر + دائري أنيق
                      GestureDetector(
                        onTap: () {
                          cartService.addToCart(product);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("تمت إضافة ${product.name}"),
                              duration: const Duration(milliseconds: 700),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF4CAF50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
