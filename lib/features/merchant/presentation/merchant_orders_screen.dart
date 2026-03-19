import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_storage.dart';
import 'order_details_screen.dart'; // 🔥 مهم

class MerchantOrdersScreen extends StatefulWidget {
  const MerchantOrdersScreen({super.key});

  @override
  State<MerchantOrdersScreen> createState() => _MerchantOrdersScreenState();
}

class _MerchantOrdersScreenState extends State<MerchantOrdersScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;

  String? marketId;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
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

      setState(() {
        orders = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Orders error: $e");
      setState(() => isLoading = false);
    }
  }

  /// 🔥 تحسين عرض الحالة
  String getStatusText(String status) {
    switch (status) {
      case "new":
        return "جديد";
      case "processing":
        return "قيد التنفيذ";
      case "delivered":
        return "تم التوصيل";
      default:
        return status;
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "new":
        return Colors.grey;
      case "processing":
        return Colors.orange;
      case "delivered":
        return Colors.green;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return const Center(child: Text("لا توجد طلبات حالياً"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];

        return InkWell(
          /// 🔥 هنا الحل الرئيسي
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailsScreen(order: order),
              ),
            );
          },

          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            margin: const EdgeInsets.symmetric(vertical: 8),

            child: Padding(
              padding: const EdgeInsets.all(12),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 📞 رقم العميل
                  Text("📞 ${order['phone']}"),

                  const SizedBox(height: 5),

                  /// 💰 السعر
                  Text("💰 ${order['total']} ريال"),

                  const SizedBox(height: 8),

                  /// 🔥 الحالة بشكل جميل
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: getStatusColor(order['status']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      getStatusText(order['status']),
                      style: TextStyle(
                        color: getStatusColor(order['status']),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
