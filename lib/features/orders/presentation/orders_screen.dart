import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/order_service.dart';
import '../../../core/models/order.dart';
import '../../../core/state/providers.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final OrderService orderService = OrderService();
  List<OrderModel> orders = [];
  bool loading = true;
  RealtimeChannel? ordersChannel;

  // ══════════════════════════════════════
  // الألوان الثابتة
  // ══════════════════════════════════════
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => loadOrders());
    listenToOrderUpdates();
  }

  void listenToOrderUpdates() {
    final phone = ref.read(appStateProvider).userPhone;
    if (phone == null) return;

    ordersChannel = Supabase.instance.client
        .channel('public:orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'phone',
            value: phone,
          ),
          callback: (payload) {
            if (mounted) loadOrders();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (ordersChannel != null) {
      Supabase.instance.client.removeChannel(ordersChannel!);
    }
    super.dispose();
  }

  Future<void> loadOrders() async {
    try {
      final data = await orderService.getOrdersByPhone();
      if (mounted) {
        setState(() {
          orders = data.map((o) => OrderModel.fromMap(o)).toList();
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  // ══════════════════════════════════════
  // الحالات
  // ══════════════════════════════════════
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

  IconData _statusIcon(String status) {
    switch (status) {
      case 'new':
        return Icons.hourglass_empty_rounded;
      case 'processing':
        return Icons.restaurant_rounded;
      case 'delivery_dining':
        return Icons.delivery_dining_rounded;
      case 'delivered':
        return Icons.check_circle_rounded;
      case 'canceled':
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline;
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

  // ══════════════════════════════════════
  // التاريخ والوقت
  // ══════════════════════════════════════
  String _formatDate(DateTime dt) {
    const months = [
      '',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  // ✅ نظام 24 ساعة مع padding للأصفار
  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatTotal(double total) {
    return total % 1 == 0 ? total.toInt().toString() : total.toStringAsFixed(2);
  }

  // ══════════════════════════════════════
  // build
  // ══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'طلباتي',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: loadOrders,
        color: _primary,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : orders.isEmpty
            ? _buildEmptyState()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _buildOrderCard(orders[index]),
              ),
      ),
    );
  }

  // ══════════════════════════════════════
  // حالة فارغة
  // ══════════════════════════════════════
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 80,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              const Text(
                'لا توجد طلبات سابقة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ابدأ تسوقك الآن من الصفحة الرئيسية',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // بطاقة الطلب
  // ══════════════════════════════════════
  Widget _buildOrderCard(OrderModel order) {
    final color = _statusColor(order.status);
    final icon = _statusIcon(order.status);
    final statusText = _statusText(order.status);
    final totalStr = _formatTotal(order.total);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            // ── شريط الحالة الملون ──
            Container(
              color: color.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // رقم الطلب على اليمين
                  Expanded(
                    child: Text(
                      'طلب #${order.id.substring(0, 8).toUpperCase()}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // الحالة على اليسار
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: color, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── تفاصيل الطلب ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // الإجمالي وعدد المنتجات
                  Row(
                    children: [
                      // الإجمالي على اليمين
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              totalStr,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: _primaryDark,
                              ),
                            ),
                            const Text(
                              ' ﷼',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
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
                        child: Row(
                          children: [
                            const Icon(
                              Icons.shopping_bag_outlined,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${order.products.length} منتج',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // التاريخ والوقت
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _formatTime(order.createdAt),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.access_time,
                        size: 13,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatDate(order.createdAt),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.calendar_today,
                        size: 13,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Divider(color: Colors.grey[100]),
                  // ── تفاصيل المنتجات قابلة للطي ──
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'تفاصيل الطلب',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 15,
                            color: Colors.grey[500],
                          ),
                        ],
                      ),
                      children: [
                        const SizedBox(height: 8),
                        ...order.products.map(
                          (p) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                // السعر على اليسار
                                Text(
                                  _buildProductPrice(p),
                                  style: TextStyle(
                                    color: _primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const Text(
                                  ' ﷼',
                                  style: TextStyle(
                                    color: _primary,
                                    fontSize: 12,
                                  ),
                                ),
                                const Spacer(),
                                // اسم المنتج على اليمين
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      p['name'] ?? '',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    if ((p['quantity'] ?? 1) > 1) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '×${p['quantity']}',
                                          style: const TextStyle(
                                            color: _primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: 6),
                                    const Text(
                                      '•',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بناء نص السعر — يدعم subtotal الجديد والسعر القديم
  String _buildProductPrice(Map p) {
    if (p['subtotal'] != null) {
      final sub = (p['subtotal'] as num).toDouble();
      return sub % 1 == 0 ? sub.toInt().toString() : sub.toStringAsFixed(1);
    }
    final price = (p['price'] as num?)?.toDouble() ?? 0;
    return price % 1 == 0 ? price.toInt().toString() : price.toStringAsFixed(1);
  }
}
