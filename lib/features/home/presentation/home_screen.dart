import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

import '../../../core/services/product_service.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/models/product.dart';
import '../../../core/state/providers.dart';
import '../../markets/presentation/markets_screen.dart';
import '../../../core/utils/app_notification.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final productService = ProductService();
  final supabase = Supabase.instance.client;

  List<Product> products = [];
  bool isLoading = true;
  String? lastLoadedMarketId;

  // ✅ البقالات القريبة
  List<Map<String, dynamic>> nearbyMarkets = [];
  bool isLoadingNearby = false;
  bool locationDenied = false;

  // ✅ الأقسام والفلترة
  List<Map<String, dynamic>> categories = [];
  String? selectedCategoryId;
  bool loadingCategories = true;

  // ✅ البحث
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ✅ عنوان التوصيل
  String? _deliveryAddress;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static const Color _primary = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final marketId = ref.read(appStateProvider).marketId;
      if (marketId == null) {
        if (mounted) setState(() => isLoading = false);
        await _loadNearbyMarkets();
      } else {
        loadProducts();
        _loadCategories();
      }
      _loadDeliveryAddress();
    });
  }

  /// ✅ جلب عنوان التوصيل من addresses
  Future<void> _loadDeliveryAddress() async {
    try {
      final phone = ref.read(appStateProvider).userPhone;
      if (phone == null) return;

      final data = await Supabase.instance.client
          .from('addresses')
          .select('address_name')
          .eq('phone', phone)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _deliveryAddress = data?['address_name'];
        });
      }
    } catch (e) {
      debugPrint("Load address error: $e");
    }
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

    // ✅ إذا لم يختر متجراً بعد — عرض شاشة اختيار البقالة
    if (appState.marketId == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "تموينات الحي",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF004D40),
            ),
          ),
        ),
        body: _buildEmptyState(),
      );
    }

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
              // يمين: عنوان التوصيل
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // السطر الأول: اسم الحي بدون إضافة كلمة "حي"
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        appState.neighborhoodName ?? "موقع التوصيل",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.location_on,
                        size: 11,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  // السطر الثاني: العنوان التفصيلي من الخريطة
                  if (_deliveryAddress != null)
                    SizedBox(
                      width: 140,
                      child: Text(
                        _deliveryAddress!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    )
                  else
                    Text(
                      "حدد عنوانك",
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),

      // ── الجسم ──
      body: RefreshIndicator(
        onRefresh: () async {
          final marketId = ref.read(appStateProvider).marketId;
          if (marketId == null) {
            await _loadNearbyMarkets();
          } else {
            await loadProducts();
          }
        },
        child: _buildMainContent(cartService),
      ),
    );
  }

  // ✅ المحتوى الرئيسي حسب الحالة
  Widget _buildMainContent(CartService cartService) {
    final marketId = ref.watch(appStateProvider).marketId;

    // لم يختر متجراً بعد
    if (marketId == null) {
      return _buildEmptyState();
    }

    // اختار متجراً — عرض المنتجات
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF004D40)),
      );
    }
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            const Text("لا توجد منتجات متاحة حالياً"),
            TextButton(
              onPressed: loadProducts,
              child: const Text("إعادة المحاولة"),
            ),
          ],
        ),
      );
    }
    return _buildBody(cartService);
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

  // ✅ حساب المسافة بين نقطتين (كيلومتر)
  double _calcDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  // ✅ جلب البقالات القريبة
  // ✅ طلب إذن الموقع بشكل صريح مع dialog
  Future<void> _requestLocationPermission() async {
    // أولاً نعرض dialog للمستخدم يشرح لماذا نحتاج الموقع
    if (!mounted) return;

    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "نحتاج موقعك 📍",
          textAlign: TextAlign.right,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "لعرض البقالات القريبة منك\nنحتاج الوصول لموقعك الحالي",
          textAlign: TextAlign.right,
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("لاحقاً", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004D40),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("السماح"),
          ),
        ],
      ),
    );

    if (agreed == true) {
      await _loadNearbyMarkets();
    } else {
      if (mounted) setState(() => isLoadingNearby = false);
    }
  }

  Future<void> _loadNearbyMarkets() async {
    if (mounted) setState(() => isLoadingNearby = true);

    try {
      // ✅ جلب كل المتاجر النشطة
      final data = await supabase
          .from('markets')
          .select()
          .eq('status', 'active');

      final markets = List<Map<String, dynamic>>.from(data);
      debugPrint("🏪 Active markets: ${markets.length}");

      // ✅ محاولة جلب الموقع المحفوظ
      double? userLat;
      double? userLng;

      try {
        final phone = ref.read(appStateProvider).userPhone;
        if (phone != null) {
          final saved = await supabase
              .from('addresses')
              .select('lat, lng')
              .eq('phone', phone)
              .maybeSingle();

          if (saved != null && saved['lat'] != null && saved['lng'] != null) {
            userLat = (saved['lat'] as num).toDouble();
            userLng = (saved['lng'] as num).toDouble();
            debugPrint("📍 Saved location: $userLat, $userLng");
          }
        }
      } catch (e) {
        debugPrint("⚠️ Could not get saved location: $e");
      }

      // ✅ بناء قائمة المتاجر مع المسافة
      final nearby = <Map<String, dynamic>>[];

      for (final m in markets) {
        double dist = 0.0;

        if (userLat != null && userLng != null) {
          final lat = (m['lat'] as num?)?.toDouble();
          final lng = (m['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            dist = _calcDistance(userLat, userLng, lat, lng);
          }
        }

        nearby.add(Map<String, dynamic>.from(m)..['distance'] = dist);
      }

      // ترتيب من الأقرب للأبعد
      nearby.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );

      debugPrint("✅ Markets to show: ${nearby.length}");

      if (mounted) {
        setState(() {
          nearbyMarkets = nearby;
          isLoadingNearby = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error loading markets: $e");
      if (mounted) setState(() => isLoadingNearby = false);
    }
  }

  // ✅ حساب المسافة بين نقطتين (كيلومتر)

  // ✅ اختيار بقالة
  void _selectMarket(Map<String, dynamic> market) async {
    final notifier = ref.read(appStateProvider.notifier);
    notifier.setMarket(market['id'] as String, market['name'] ?? '');
    await notifier.loadInitialData();
    if (mounted) {
      setState(() {
        products = [];
        isLoading = true;
      });
      loadProducts();
      _loadCategories();
    }
  }

  Widget _buildEmptyState() {
    if (isLoadingNearby) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF004D40)),
            SizedBox(height: 16),
            Text(
              "جاري البحث عن البقالات القريبة...",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (locationDenied) return _buildLocationDenied();

    if (nearbyMarkets.isEmpty) return _buildNoMarkets();

    // ✅ عرض البقالات
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: nearbyMarkets.length + 1,
      itemBuilder: (_, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                "مرحباً بك! 👋",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF004D40),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "اختر بقالتك القريبة لتبدأ التسوق",
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${nearbyMarkets.length} بقالة",
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                  const Text(
                    "البقالات القريبة منك",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          );
        }
        return _buildMarketCard(nearbyMarkets[index - 1]);
      },
    );
  }

  Widget _buildMarketsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "${nearbyMarkets.length} بقالة",
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const Row(
              children: [
                Text(
                  "البقالات القريبة منك",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.store_outlined, color: Color(0xFF004D40), size: 20),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final m in nearbyMarkets) _buildMarketCard(m),
      ],
    );
  }

  Widget _buildMarketCard(Map<String, dynamic> market) {
    final dist = (market['distance'] as double);
    final distStr = dist == 0
        ? ""
        : dist < 1
        ? "${(dist * 1000).toInt()} م"
        : "${dist.toStringAsFixed(1)} كم";
    final name = market['name']?.toString() ?? '';
    final neighborhood = market['neighborhood_name']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            // أيقونة المتجر
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.store_outlined,
                color: Color(0xFF004D40),
                size: 26,
              ),
            ),
            const SizedBox(width: 12),

            // معلومات المتجر
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    name,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (neighborhood.isNotEmpty)
                    Text(
                      neighborhood,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  if (distStr.isNotEmpty)
                    Text(
                      distStr,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // زر الاختيار
            SizedBox(
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _selectMarket(market),
                child: const Text(
                  "اختر",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDenied() {
    return Column(
      children: [
        const SizedBox(height: 30),
        const Icon(Icons.location_off_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        const Text(
          "لم يتم السماح بالوصول للموقع",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          "نحتاج موقعك لعرض البقالات القريبة منك",
          style: TextStyle(color: Colors.grey[500], fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF004D40),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            setState(() => locationDenied = false);
            _loadNearbyMarkets();
          },
          icon: const Icon(Icons.my_location, size: 18),
          label: const Text("السماح بالموقع"),
        ),
      ],
    );
  }

  Widget _buildNoMarkets() {
    return Column(
      children: [
        const SizedBox(height: 30),
        const Text("😔", style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        const Text(
          "لا توجد بقالات قريبة منك",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          "لا توجد بقالات في نطاق 3 كيلومتر حالياً\nسيتم إشعارك عند إضافة بقالة في حيك",
          style: TextStyle(color: Colors.grey[500], fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF004D40)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _loadNearbyMarkets,
          icon: const Icon(Icons.refresh, color: Color(0xFF004D40), size: 18),
          label: const Text(
            "إعادة البحث",
            style: TextStyle(color: Color(0xFF004D40)),
          ),
        ),
      ],
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
                          AppNotification.success(
                            context,
                            "تمت إضافة ${product.name} للسلة",
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
