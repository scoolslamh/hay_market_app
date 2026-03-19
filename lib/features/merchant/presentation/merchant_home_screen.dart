import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_storage.dart';

class MerchantHomeScreen extends StatefulWidget {
  const MerchantHomeScreen({super.key});

  @override
  State<MerchantHomeScreen> createState() => _MerchantHomeScreenState();
}

class _MerchantHomeScreenState extends State<MerchantHomeScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;

  String? marketId;

  @override
  void initState() {
    super.initState();
    _loadMerchantData();
  }

  /// 🔥 تحميل بيانات التاجر
  Future<void> _loadMerchantData() async {
    try {
      final phone = await AuthStorage().getPhone();

      if (phone == null) return;

      /// 🏪 جلب المتجر الخاص بالتاجر
      final market = await supabase
          .from('markets')
          .select()
          .eq('owner_phone', phone)
          .maybeSingle();

      if (market == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      marketId = market['id'];

      /// 📦 جلب الطلبات
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
      debugPrint("Merchant load error: $e");
      setState(() => isLoading = false);
    }
  }

  /// 🔄 تحديث حالة الطلب
  Future<void> _updateOrderStatus(String orderId, String status) async {
    try {
      await supabase
          .from('orders')
          .update({"status": status})
          .eq('id', orderId);

      /// تحديث محلي سريع
      setState(() {
        final index = orders.indexWhere((o) => o['id'] == orderId);
        if (index != -1) {
          orders[index]['status'] = status;
        }
      });
    } catch (e) {
      debugPrint("Update status error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("لوحة التاجر"),
        backgroundColor: Colors.green,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
          ? const Center(child: Text("لا توجد طلبات حالياً"))
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];

                return Card(
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

                        /// 📍 العنوان
                        Text("📍 ${order['address'] ?? ''}"),

                        if (order['notes'] != null &&
                            order['notes'].toString().isNotEmpty)
                          Text("📝 ${order['notes']}"),

                        const SizedBox(height: 10),

                        /// 💰 الإجمالي
                        Text("💰 ${order['total']} ريال"),

                        const SizedBox(height: 10),

                        /// 🔄 الحالة
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("الحالة: ${order['status']}"),

                            DropdownButton<String>(
                              value: order['status'],
                              items: const [
                                DropdownMenuItem(
                                  value: "new",
                                  child: Text("جديد"),
                                ),
                                DropdownMenuItem(
                                  value: "processing",
                                  child: Text("قيد التنفيذ"),
                                ),
                                DropdownMenuItem(
                                  value: "delivered",
                                  child: Text("تم التوصيل"),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  _updateOrderStatus(
                                    order['id'].toString(),
                                    value,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
