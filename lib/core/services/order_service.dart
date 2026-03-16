import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cart_service.dart';

class OrderService extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;

  int _ordersCount = 0;

  int get count => _ordersCount;

  void _increase() {
    _ordersCount++;
    notifyListeners();
  }

  void clear() {
    _ordersCount = 0;
    notifyListeners();
  }

  /// إنشاء طلب جديد
  Future<void> createOrder({
    required String phone,
    required String marketId,
  }) async {
    final cart = CartService();

    if (cart.cartItems.isEmpty) {
      throw Exception("السلة فارغة");
    }

    /// تحويل المنتجات إلى JSON
    final products = cart.cartItems
        .map((p) => {"id": p.id, "name": p.name, "price": p.price})
        .toList();

    try {
      await supabase
          .from("orders")
          .insert({
            "user_phone": phone,
            "market_id": marketId,
            "products": products,
            "total": cart.total,
            "status": "new",
          })
          .timeout(const Duration(seconds: 10));

      /// زيادة عداد الطلبات
      _increase();

      /// تفريغ السلة
      cart.clear();
    } on TimeoutException {
      throw Exception("انتهت مهلة الاتصال بالخادم");
    } catch (e) {
      debugPrint("Create order error: $e");
      rethrow;
    }
  }

  /// جلب طلبات المستخدم
  Future<List<Map<String, dynamic>>> getOrdersByPhone(String phone) async {
    try {
      final response = await supabase
          .from("orders")
          .select()
          .eq("user_phone", phone)
          .order("created_at", ascending: false)
          .limit(50) // تحسين الأداء
          .timeout(const Duration(seconds: 10));

      return List<Map<String, dynamic>>.from(response);
    } on TimeoutException {
      debugPrint("Orders request timeout");
      return [];
    } catch (e) {
      debugPrint("Fetch orders error: $e");
      return [];
    }
  }
}
