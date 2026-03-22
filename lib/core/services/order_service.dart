import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  /// ✅ جلب آخر عنوان بـ phone (مصلح من user_id إلى phone)
  Future<Map<String, dynamic>?> _getLatestAddress(String phone) async {
    return await supabase
        .from('addresses')
        .select()
        .eq('phone', phone)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  /// 🧾 إنشاء طلب جديد
  Future<void> createOrder({
    required WidgetRef ref,
    String customerNotes = '',
    String paymentMethod = 'cash',
  }) async {
    final cart = CartService.instance;

    if (cart.items.isEmpty) {
      throw Exception("السلة فارغة");
    }

    final phone = await AuthStorage().getPhone();
    if (phone == null) throw Exception("المستخدم غير مسجل");

    final state = ref.read(appStateProvider);
    if (state.marketId == null) throw Exception("لم يتم تحديد متجر");

    /// ✅ جلب العنوان من addresses بـ phone
    final addressData = await _getLatestAddress(phone);
    final deliveryAddress = addressData?['address_name'] ?? "";
    final addressLat = addressData?['lat'];
    final addressLng = addressData?['lng'];

    /// 🛒 المنتجات مع الكمية
    final productsJson = cart.items
        .map(
          (item) => {
            "id": item.product.id,
            "name": item.product.name,
            "price": item.product.price,
            "quantity": item.quantity,
            "subtotal": item.subtotal,
          },
        )
        .toList();

    try {
      await supabase
          .from("orders")
          .insert({
            "phone": phone,
            "market_id": state.marketId,
            "market": state.marketName,
            "neighborhood": state.neighborhoodName,

            // ✅ العنوان الكامل من جدول addresses
            "address": deliveryAddress,
            "address_lat": addressLat,
            "address_lng": addressLng,

            // ✅ ملاحظات العميل من Bottom Sheet
            "notes": customerNotes,

            // ✅ طريقة الدفع
            "payment_method": paymentMethod,

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

  /// 📦 جلب الطلبات للمستخدم
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
