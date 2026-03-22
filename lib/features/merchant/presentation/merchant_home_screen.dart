import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_storage.dart';
import '../../auth/presentation/login_screen.dart';
import 'merchant_orders_screen.dart';
import 'merchant_products_screen.dart';
import 'warehouse_screen.dart';

class MerchantHomeScreen extends StatefulWidget {
  const MerchantHomeScreen({super.key});

  @override
  State<MerchantHomeScreen> createState() => _MerchantHomeScreenState();
}

class _MerchantHomeScreenState extends State<MerchantHomeScreen> {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  int currentIndex = 0;
  String? marketName;
  String? marketId;

  // إحصائيات الداش بورد
  int totalOrders = 0;
  int activeOrders = 0;
  int totalCustomers = 0;
  double totalRevenue = 0;
  int totalProducts = 0;
  bool loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadMarketAndStats();
  }

  Future<void> _loadMarketAndStats() async {
    try {
      final phone = await AuthStorage().getPhone();
      if (phone == null) return;

      final supabase = Supabase.instance.client;

      // جلب بيانات المتجر
      final market = await supabase
          .from('markets')
          .select()
          .eq('owner_phone', phone)
          .maybeSingle();

      if (market == null) return;

      final mId = market['id'];
      final mName = market['name'];

      // جلب الإحصائيات
      final orders = await supabase
          .from('orders')
          .select('total, phone, status')
          .eq('market_id', mId);

      final products = await supabase
          .from('products')
          .select('id')
          .eq('market_id', mId);

      final ordersList = List<Map<String, dynamic>>.from(orders);
      final activeList = ordersList
          .where((o) => o['status'] != 'delivered' && o['status'] != 'canceled')
          .toList();

      final uniqueCustomers = ordersList.map((o) => o['phone']).toSet().length;

      final revenue = ordersList
          .where((o) => o['status'] == 'delivered')
          .fold<double>(0, (sum, o) => sum + ((o['total'] as num?) ?? 0));

      if (mounted) {
        setState(() {
          marketId = mId;
          marketName = mName;
          totalOrders = ordersList.length;
          activeOrders = activeList.length;
          totalCustomers = uniqueCustomers;
          totalRevenue = revenue;
          totalProducts = products.length;
          loadingStats = false;
        });
      }
    } catch (e) {
      debugPrint("Stats error: $e");
      if (mounted) setState(() => loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: currentIndex == 0
          ? _buildDashboard()
          : currentIndex == 1
          ? const MerchantOrdersScreen()
          : currentIndex == 2
          ? const MerchantProductsScreen()
          : const WarehouseScreen(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ══════════════════════════════════════
  // Dashboard
  // ══════════════════════════════════════
  Widget _buildDashboard() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadMarketAndStats,
        color: _primary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── الهيدر ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // تسجيل خروج
                GestureDetector(
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    await AuthStorage().logout();
                    // ✅ تسجيل خروج من Supabase لمسح الجلسة كاملاً
                    await Supabase.instance.client.auth.signOut();
                    if (!mounted) return;
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.logout,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                ),

                // اسم المتجر
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "مرحباً 👋",
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    Text(
                      marketName ?? "متجرك",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── إحصائيات ──
            if (loadingStats)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  // الصف الأول
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          "الطلبات الكلية",
                          "$totalOrders",
                          Icons.receipt_long_outlined,
                          _primaryDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          "الطلبات النشطة",
                          "$activeOrders",
                          Icons.pending_outlined,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // الصف الثاني
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          "العملاء",
                          "$totalCustomers",
                          Icons.people_outline,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          "المنتجات",
                          "$totalProducts",
                          Icons.inventory_2_outlined,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // الإيرادات — صف كامل
                  _buildRevenueCard(),
                ],
              ),

            const SizedBox(height: 20),

            // ── اختصارات سريعة ──
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                "وصول سريع",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildShortcut(
                    icon: Icons.receipt_long,
                    label: "الطلبات",
                    color: _primaryDark,
                    onTap: () => setState(() => currentIndex = 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildShortcut(
                    icon: Icons.inventory_2,
                    label: "المنتجات",
                    color: Colors.purple,
                    onTap: () => setState(() => currentIndex = 2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildShortcut(
                    icon: Icons.warehouse,
                    label: "المستودع",
                    color: Colors.orange,
                    onTap: () => setState(() => currentIndex = 3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildRevenueCard() {
    final totalStr = totalRevenue % 1 == 0
        ? totalRevenue.toInt().toString()
        : totalRevenue.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00695C)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                totalStr,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const Text(
                " ﷼",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.trending_up, color: Colors.white70, size: 28),
              const SizedBox(height: 4),
              Text(
                "إجمالي الإيرادات",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShortcut({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // Bottom Navigation
  // ══════════════════════════════════════
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: _primaryDark,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      onTap: (index) => setState(() => currentIndex = index),
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: "الرئيسية",
        ),
        // ✅ Badge على أيقونة الطلبات
        BottomNavigationBarItem(
          icon: _buildOrdersIcon(active: false),
          activeIcon: _buildOrdersIcon(active: true),
          label: "الطلبات",
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined),
          activeIcon: Icon(Icons.inventory_2),
          label: "المنتجات",
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.warehouse_outlined),
          activeIcon: Icon(Icons.warehouse),
          label: "المستودع",
        ),
      ],
    );
  }

  Widget _buildOrdersIcon({required bool active}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          active ? Icons.receipt_long : Icons.receipt_long_outlined,
          color: active ? _primaryDark : Colors.grey,
        ),
        if (activeOrders > 0)
          Positioned(
            top: -4,
            left: -4,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  activeOrders > 9 ? '9+' : '$activeOrders',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
