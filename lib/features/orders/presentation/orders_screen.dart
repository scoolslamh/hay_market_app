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

  late RealtimeChannel ordersChannel;

  @override
  void initState() {
    super.initState();

    Future.microtask(() => loadOrders());

    listenToOrderUpdates();
  }

  /// الاستماع لتحديثات الطلبات
  void listenToOrderUpdates() {
    ordersChannel = Supabase.instance.client
        .channel('orders_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            loadOrders();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            loadOrders();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(ordersChannel);
    super.dispose();
  }

  Future<void> loadOrders() async {
    final phone = ref.read(appStateProvider).userPhone;

    if (phone == null) {
      setState(() => loading = false);
      return;
    }

    final data = await orderService.getOrdersByPhone(phone);

    setState(() {
      orders = data.map((o) => OrderModel.fromMap(o)).toList();
      loading = false;
    });
  }

  /// لون حالة الطلب
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
      default:
        return Colors.grey;
    }
  }

  /// نص حالة الطلب
  String getStatusText(String status) {
    switch (status) {
      case "new":
        return "قيد المراجعة";
      case "preparing":
        return "جاري التجهيز";
      case "delivery":
        return "جاري التوصيل";
      case "done":
        return "تم التوصيل";
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("طلباتي")),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
          ? const Center(child: Text("لا يوجد طلبات"))
          : ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];

                return Card(
                  margin: const EdgeInsets.all(10),
                  child: ExpansionTile(
                    title: Text(
                      "طلب رقم ${order.id.substring(0, 6)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("المجموع: ${order.total} ريال"),
                        const SizedBox(height: 5),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: getStatusColor(
                              order.status,
                            ).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            getStatusText(order.status),
                            style: TextStyle(
                              color: getStatusColor(order.status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "المنتجات:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),

                            const SizedBox(height: 5),

                            ...order.products.map((p) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Text(
                                  "- ${p['name']} (${p['price']} ريال)",
                                ),
                              );
                            }).toList(),

                            const SizedBox(height: 10),

                            Text(
                              "التاريخ: ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}",
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
