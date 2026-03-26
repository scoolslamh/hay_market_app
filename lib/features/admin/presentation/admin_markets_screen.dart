import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/app_notification.dart';
import 'admin_market_detail_screen.dart';

class AdminMarketsScreen extends StatefulWidget {
  const AdminMarketsScreen({super.key});

  @override
  State<AdminMarketsScreen> createState() => _AdminMarketsScreenState();
}

class _AdminMarketsScreenState extends State<AdminMarketsScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  final supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> pendingList = [];
  List<Map<String, dynamic>> activeList = [];
  List<Map<String, dynamic>> frozenList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMarkets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMarkets() async {
    try {
      setState(() => isLoading = true);
      final data = await supabase
          .from('markets')
          .select()
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(data);
      if (mounted) {
        setState(() {
          pendingList = list.where((m) => m['status'] == 'pending').toList();
          activeList = list.where((m) => m['status'] == 'active').toList();
          frozenList = list.where((m) => m['status'] == 'frozen').toList();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "إدارة المتاجر",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primaryDark,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _primaryDark,
          tabs: [
            Tab(text: "طلبات (${pendingList.length})"),
            Tab(text: "نشط (${activeList.length})"),
            Tab(text: "مجمد (${frozenList.length})"),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(pendingList),
                _buildList(activeList),
                _buildList(frozenList),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              "لا توجد متاجر",
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMarkets,
      color: _primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildMarketCard(list[i]),
      ),
    );
  }

  Widget _buildMarketCard(Map<String, dynamic> market) {
    final status = market['status'] ?? 'pending';
    Color statusColor;
    switch (status) {
      case 'active':
        statusColor = _primary;
        break;
      case 'frozen':
        statusColor = Colors.blue;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    String statusText;
    switch (status) {
      case 'active':
        statusText = 'نشط';
        break;
      case 'frozen':
        statusText = 'مجمد';
        break;
      case 'rejected':
        statusText = 'مرفوض';
        break;
      default:
        statusText = 'بانتظار القبول';
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminMarketDetailScreen(market: market),
          ),
        );
        _loadMarkets();
      },
      child: Container(
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
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // الحالة
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // اسم المتجر
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        market['name'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        market['neighborhood_name'] ?? '',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: Colors.grey[100]),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "عرض التفاصيل",
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        market['owner_phone'] ?? '',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.phone_outlined,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
