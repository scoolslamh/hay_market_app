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
    // جلب نسخة السلة (بما أنها Singleton ستكون هي نفسها التي يراها المستخدم)
    final cart = CartService();

    if (cart.cartItems.isEmpty) {
      throw Exception("السلة فارغة");
    }

    /// تحويل المنتجات إلى قائمة خريطة (Map) لتخزينها كـ JSON في Supabase
    final productsJson = cart.cartItems
        .map((p) => {"id": p.id, "name": p.name, "price": p.price})
        .toList();

    try {
      await supabase
          .from("orders")
          .insert({
            "phone":
                phone, // ✅ تأكد أن اسم العمود في الجدول هو phone وليس user_phone
            "market_id": marketId,
            "products": productsJson,
            "total": cart.total,
            "status": "new",
          })
          .timeout(const Duration(seconds: 10));

      /// زيادة عداد الطلبات المحلي
      _increase();

      /// ✅ الإصلاح هنا: تم تغيير clear() إلى clearCart() ليتوافق مع ملف الخدمة الجديد
      cart.clearCart();
    } on TimeoutException {
      throw Exception("انتهت مهلة الاتصال بالخادم");
    } catch (e) {
      debugPrint("Create order error: $e");
      rethrow;
    }
  }

  /// جلب طلبات المستخدم بناءً على رقم الجوال
  Future<List<Map<String, dynamic>>> getOrdersByPhone(String phone) async {
    try {
      final response = await supabase
          .from("orders")
          .select()
          .eq("phone", phone) // ✅ تأكد من مطابقة اسم العمود
          .order("created_at", ascending: false)
          .limit(50)
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
