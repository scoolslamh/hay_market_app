import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final supabase = Supabase.instance.client;

  late Map<String, dynamic> order;

  @override
  void initState() {
    super.initState();
    order = widget.order;
  }

  Future<void> updateStatus(String status) async {
    try {
      await supabase
          .from('orders')
          .update({"status": status})
          .eq('id', order['id']);

      setState(() {
        order['status'] = status;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("تم تحديث الحالة")));
    } catch (e) {
      debugPrint("Update error: $e");
    }
  }

  /// 🔥 تحويل الحالة للعربي
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

  @override
  Widget build(BuildContext context) {
    final List products = order['products'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("تفاصيل الطلب"),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            /// 📞 الهاتف
            ListTile(
              leading: const Icon(Icons.phone),
              title: Text(order['phone'] ?? "غير متوفر"),
            ),

            /// 📍 العنوان
            ListTile(
              leading: const Icon(Icons.location_on),
              title: Text(order['address'] ?? "لا يوجد عنوان"),
              subtitle: Text(order['neighborhood'] ?? ""),
            ),

            /// 📝 ملاحظات
            if (order['notes'] != null && order['notes'].toString().isNotEmpty)
              ListTile(
                leading: const Icon(Icons.note),
                title: Text(order['notes']),
              ),

            const Divider(),

            /// 🛒 المنتجات
            const Text(
              "المنتجات",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            if (products.isEmpty)
              const Text("لا توجد منتجات")
            else
              ...products.map((p) {
                return Card(
                  child: ListTile(
                    title: Text(p['name'] ?? "منتج"),
                    subtitle: Text("الكمية: ${p['quantity'] ?? 1}"),
                  ),
                );
              }),

            const SizedBox(height: 20),

            /// 💰 الإجمالي
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: Text("${order['total']} ريال"),
            ),

            const SizedBox(height: 20),

            /// 🔄 الحالة الحالية
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "الحالة: ${getStatusText(order['status'])}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 20),

            /// 🔘 أزرار التحديث
            ElevatedButton(
              onPressed: () => updateStatus("new"),
              child: const Text("جديد"),
            ),
            ElevatedButton(
              onPressed: () => updateStatus("processing"),
              child: const Text("قيد التنفيذ"),
            ),
            ElevatedButton(
              onPressed: () => updateStatus("delivered"),
              child: const Text("تم التوصيل"),
            ),
          ],
        ),
      ),
    );
  }
}
