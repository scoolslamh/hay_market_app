import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_storage.dart';
import '../../auth/presentation/login_screen.dart';
import 'admin_markets_screen.dart';
import 'admin_users_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_invite_codes_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  final supabase = Supabase.instance.client;
  int _currentIndex = 0;

  // إحصائيات
  int totalOrders = 0;
  int totalMarkets = 0;
  int pendingMarkets = 0;
  int totalUsers = 0;
  double totalRevenue = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      setState(() => isLoading = true);

      final results = await Future.wait([
        supabase.from('orders').select('total, status'),
        supabase.from('markets').select('id, status'),
        supabase.from('users').select('id'),
      ]);

      final orders = List<Map<String, dynamic>>.from(results[0] as List);
      final markets = List<Map<String, dynamic>>.from(results[1] as List);
      final users = List<Map<String, dynamic>>.from(results[2] as List);

      if (mounted) {
        setState(() {
          totalOrders = orders.length;
          totalMarkets = markets.where((m) => m['status'] == 'active').length;
          pendingMarkets = markets
              .where((m) => m['status'] == 'pending')
              .length;
          totalUsers = users.length;
          totalRevenue = orders
              .where((o) => o['status'] == 'delivered')
              .fold(0, (sum, o) => sum + ((o['total'] as num?) ?? 0));
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Stats error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _currentIndex == 0
          ? _buildDashboard()
          : _currentIndex == 1
          ? const AdminMarketsScreen()
          : _currentIndex == 2
          ? const AdminOrdersScreen()
          : _currentIndex == 3
          ? const AdminUsersScreen()
          : const AdminCategoriesScreen(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ══════════════════════════════════════
  // Dashboard
  // ══════════════════════════════════════
  Widget _buildDashboard() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadStats,
        color: _primary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── الهيدر ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () async {
                    final nav = Navigator.of(context);
                    await AuthStorage().logout();
                    if (!mounted) return;
                    nav.pushAndRemoveUntil(
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "مرحباً 👋",
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                    const Text(
                      "لوحة تحكم المدير",
                      style: TextStyle(
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

            // ── تنبيه طلبات الانضمام ──
            if (pendingMarkets > 0)
              GestureDetector(
                onTap: () => setState(() => _currentIndex = 1),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.arrow_back_ios,
                        size: 14,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "مراجعة الطلبات",
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "$pendingMarkets طلب انضمام جديد",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── الإحصائيات ──
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
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
                      "المتاجر النشطة",
                      "$totalMarkets",
                      Icons.store_outlined,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      "العملاء",
                      "$totalUsers",
                      Icons.people_outline,
                      Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      "بانتظار القبول",
                      "$pendingMarkets",
                      Icons.pending_outlined,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildRevenueCard(),
            ],

            const SizedBox(height: 20),

            // ── اختصارات ──
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                "إجراءات سريعة",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _buildShortcut(
                  Icons.store_outlined,
                  "المتاجر",
                  Colors.blue,
                  () => setState(() => _currentIndex = 1),
                ),
                _buildShortcut(
                  Icons.receipt_long_outlined,
                  "الطلبات",
                  _primaryDark,
                  () => setState(() => _currentIndex = 2),
                ),
                _buildShortcut(
                  Icons.people_outline,
                  "العملاء",
                  Colors.purple,
                  () => setState(() => _currentIndex = 3),
                ),
                _buildShortcut(
                  Icons.category_outlined,
                  "الأقسام",
                  Colors.teal,
                  () => setState(() => _currentIndex = 4),
                ),
                _buildShortcut(
                  Icons.vpn_key_outlined,
                  "أكواد الدعوة",
                  Colors.orange,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminInviteCodesScreen(),
                    ),
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
    final str = totalRevenue % 1 == 0
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
                str,
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
                "إجمالي المبيعات",
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

  Widget _buildShortcut(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          mainAxisAlignment: MainAxisAlignment.center,
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

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      selectedItemColor: _primaryDark,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      onTap: (i) => setState(() => _currentIndex = i),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: "الرئيسية",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.store_outlined),
          activeIcon: Icon(Icons.store),
          label: "المتاجر",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          activeIcon: Icon(Icons.receipt_long),
          label: "الطلبات",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          activeIcon: Icon(Icons.people),
          label: "العملاء",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.category_outlined),
          activeIcon: Icon(Icons.category),
          label: "الأقسام",
        ),
      ],
    );
  }
}
