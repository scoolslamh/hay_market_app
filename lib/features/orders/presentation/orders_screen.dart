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

  Color getStatusColor(String status) {
    switch (status) {
      case "new":
        return Colors.orange;
      case "preparing":
        return Colors.blue;
      case "delivery":
        return Colors.purple;
      case "done":
        return Colors.green;
      case "canceled":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case "new":
        return "📦 قيد المراجعة";
      case "preparing":
        return "👨‍🍳 جاري التجهيز";
      case "delivery":
        return "🚚 جاري التوصيل";
      case "done":
        return "✅ تم التوصيل";
      case "canceled":
        return "❌ تم الإلغاء";
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("طلباتي"), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: loadOrders,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : orders.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return _buildOrderCard(order);
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        alignment: Alignment.center,
        child: const Text("لا توجد طلبات سابقة"),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(
          Icons.shopping_bag_outlined,
          color: getStatusColor(order.status),
        ),
        title: Text(
          "طلب #${order.id.substring(0, 8).toUpperCase()}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("الإجمالي: ${order.total} ريال"),
        trailing: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: getStatusColor(order.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            getStatusText(order.status),
            style: TextStyle(
              color: getStatusColor(order.status),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const Text(
                  "تفاصيل المنتجات:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...order.products.map(
                  (p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("• ${p['name']}"),
                        Text("${p['price']} ريال"),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "التاريخ: ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}",
                    ),
                    Text(
                      "الوقت: ${order.createdAt.hour}:${order.createdAt.minute}",
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
