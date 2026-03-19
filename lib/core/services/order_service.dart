import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ جديد
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cart_service.dart';
import 'auth_storage.dart';
import '../state/providers.dart';

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

  /// 🔥 جلب آخر عنوان
  Future<Map<String, dynamic>?> _getLatestAddress() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    return await supabase
        .from('addresses')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  /// 🧾 إنشاء طلب جديد (تم تطويرها بشكل صحيح)
  Future<void> createOrder({
    required String marketId,
    required WidgetRef ref, // ✅ مهم جدًا
  }) async {
    final cart = CartService.instance;

    if (cart.cartItems.isEmpty) {
      throw Exception("السلة فارغة");
    }

    final phone = await AuthStorage().getPhone();

    if (phone == null) {
      throw Exception("المستخدم غير مسجل");
    }

    /// ✅ جلب الحالة الصحيحة من Riverpod
    final state = ref.read(appStateProvider);

    /// 🔥 جلب العنوان
    final addressData = await _getLatestAddress();

    final address = addressData?['address_name'] ?? "";
    final notes = addressData?['notes'] ?? "";

    /// 🛒 المنتجات
    final productsJson = cart.cartItems
        .map((p) => {"id": p.id, "name": p.name, "price": p.price})
        .toList();

    try {
      await supabase
          .from("orders")
          .insert({
            "phone": phone,
            "market_id": marketId,

            /// 🔥 البيانات الجديدة (تعمل الآن بشكل صحيح)
            "neighborhood": state.neighborhoodName,
            "market": state.marketName,
            "address": address,
            "notes": notes,

            "products": productsJson,
            "total": cart.total,
            "status": "new",
            "created_at": DateTime.now().toIso8601String(),
          })
          .timeout(const Duration(seconds: 10));

      _increase();

      cart.clearCart();
    } on TimeoutException {
      throw Exception("انتهت مهلة الاتصال بالخادم");
    } catch (e) {
      debugPrint("Create order error: $e");
      rethrow;
    }
  }

  /// 📦 جلب الطلبات
  Future<List<Map<String, dynamic>>> getOrdersByPhone() async {
    try {
      final phone = await AuthStorage().getPhone();

      if (phone == null) return [];

      final response = await supabase
          .from("orders")
          .select()
          .eq("phone", phone)
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
