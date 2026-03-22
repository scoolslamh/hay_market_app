import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_storage.dart';
import 'order_details_screen.dart';

class MerchantOrdersScreen extends StatefulWidget {
  const MerchantOrdersScreen({super.key});

  @override
  State<MerchantOrdersScreen> createState() => _MerchantOrdersScreenState();
}

class _MerchantOrdersScreenState extends State<MerchantOrdersScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> activeOrders = [];
  List<Map<String, dynamic>> archivedOrders = [];
  bool isLoading = true;
  String? marketId;
  RealtimeChannel? _channel;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_channel != null) supabase.removeChannel(_channel!);
    super.dispose();
  }

  Future<void> _loadOrders() async {
    try {
      setState(() => isLoading = true);
      final phone = await AuthStorage().getPhone();
      if (phone == null) return;

      final market = await supabase
          .from('markets')
          .select()
          .eq('owner_phone', phone)
          .maybeSingle();

      if (market == null) {
        setState(() => isLoading = false);
        return;
      }

      marketId = market['id'];

      final data = await supabase
          .from('orders')
          .select()
          .eq('market_id', marketId!)
          .order('created_at', ascending: false);

      final all = List<Map<String, dynamic>>.from(data);

      // ✅ فصل النشطة عن المؤرشفة
      final active = all
          .where((o) => o['status'] != 'delivered' && o['status'] != 'canceled')
          .toList();
      final archived = all
          .where((o) => o['status'] == 'delivered' || o['status'] == 'canceled')
          .toList();

      if (mounted) {
        setState(() {
          activeOrders = active;
          archivedOrders = archived;
          isLoading = false;
        });
      }

      // ✅ Realtime
      _setupRealtime();
    } catch (e) {
      debugPrint("Orders error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _setupRealtime() {
    if (marketId == null) return;
    _channel?.unsubscribe();
    _channel = supabase
        .channel('merchant_orders_$marketId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'market_id',
            value: marketId!,
          ),
          callback: (_) => _loadOrders(),
        )
        .subscribe();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'new':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'delivery_dining':
        return Colors.purple;
      case 'delivered':
        return _primary;
      case 'canceled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'new':
        return 'قيد المراجعة';
      case 'processing':
        return 'جاري التجهيز';
      case 'delivery_dining':
        return 'جاري التوصيل';
      case 'delivered':
        return 'تم التوصيل';
      case 'canceled':
        return 'ملغي';
      default:
        return status;
    }
  }

  String _formatTime(String? createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
          "الطلبات",
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
            Tab(text: "النشطة (${activeOrders.length})"),
            Tab(text: "الأرشيف (${archivedOrders.length})"),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersList(activeOrders),
                _buildOrdersList(archivedOrders),
              ],
            ),
    );
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              "لا توجد طلبات",
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: _primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _buildOrderCard(orders[index]),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final color = _statusColor(order['status'] ?? '');
    final products = (order['products'] as List?) ?? [];
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final totalStr = total % 1 == 0
        ? total.toInt().toString()
        : total.toStringAsFixed(1);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)),
        );
        _loadOrders();
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
        child: Column(
          children: [
            // شريط الحالة
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // الحالة
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusText(order['status'] ?? ''),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // رقم الطلب
                  Text(
                    "طلب #${order['id'].toString().substring(0, 8).toUpperCase()}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // تفاصيل
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // الوقت
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 13,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(order['created_at']),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      // رقم العميل
                      Row(
                        children: [
                          Text(
                            order['phone'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
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
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // الإجمالي
                      Row(
                        children: [
                          Text(
                            totalStr,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _primaryDark,
                            ),
                          ),
                          const Text(
                            " ﷼",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _primaryDark,
                            ),
                          ),
                        ],
                      ),
                      // عدد المنتجات
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${products.length} منتج",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // طريقة الدفع
                  if (order['payment_method'] != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          order['payment_method'] == 'cash'
                              ? '💵 كاش'
                              : order['payment_method'] == 'mada'
                              ? '💳 مدى'
                              : '📒 دفتر',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
