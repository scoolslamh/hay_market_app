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

      final orderTotal = cart.total;
      _increase();
      cart.clearCart();

      // ✅ إذا الدفع بالدفتر — احجز المبلغ فوراً
      if (paymentMethod == 'daftar') {
        await _reserveInDaftar(phone, orderTotal);
      }
    } on TimeoutException {
      throw Exception("انتهت مهلة الاتصال بالخادم");
    } catch (e) {
      debugPrint("Create order error: $e");
      rethrow;
    }
  }

  /// ✅ حجز المبلغ في الدفتر عند إرسال الطلب
  Future<void> _reserveInDaftar(String phone, double amount) async {
    try {
      final daftar = await supabase
          .from('daftar')
          .select()
          .eq('customer_phone', phone)
          .eq('status', 'approved')
          .maybeSingle();

      if (daftar == null) return;

      final reserved = (daftar['reserved_balance'] as num?)?.toDouble() ?? 0;

      await supabase
          .from('daftar')
          .update({'reserved_balance': reserved + amount})
          .eq('id', daftar['id']);

      debugPrint("✅ تم حجز $amount ﷼ في دفتر $phone");
    } catch (e) {
      debugPrint("Reserve daftar error: $e");
    }
  }

  /// ✅ تأكيد المبلغ عند التوصيل (محجوز → فعلي)
  Future<void> confirmDaftarPayment(
    String phone,
    double amount,
    String orderId,
  ) async {
    try {
      final daftar = await supabase
          .from('daftar')
          .select()
          .eq('customer_phone', phone)
          .eq('status', 'approved')
          .maybeSingle();

      if (daftar == null) return;

      final currentBalance =
          (daftar['current_balance'] as num?)?.toDouble() ?? 0;
      final reserved = (daftar['reserved_balance'] as num?)?.toDouble() ?? 0;
      final limit = (daftar['credit_limit'] as num?)?.toDouble() ?? 300;

      // نقل من محجوز لفعلي
      await supabase
          .from('daftar')
          .update({
            'current_balance': currentBalance + amount,
            'reserved_balance': (reserved - amount).clamp(0, double.infinity),
          })
          .eq('id', daftar['id']);

      // تسجيل المعاملة
      await supabase.from('daftar_transactions').insert({
        'daftar_id': daftar['id'],
        'order_id': orderId,
        'amount': amount,
        'type': 'order',
        'note': 'طلب #${orderId.substring(0, 8).toUpperCase()} — تم التوصيل',
      });

      debugPrint("✅ تم تأكيد $amount ﷼ في دفتر $phone");

      // إذا تجاوز 80% من الحد — تنبيه
      final newBalance = currentBalance + amount;
      if (newBalance / limit >= 0.8) {
        debugPrint(
          "⚠️ العميل وصل ${(newBalance / limit * 100).toInt()}% من حده",
        );
      }
    } catch (e) {
      debugPrint("Confirm daftar error: $e");
    }
  }

  /// ✅ تحرير المحجوز عند الإلغاء
  Future<void> releaseDaftarReservation(String phone, double amount) async {
    try {
      final daftar = await supabase
          .from('daftar')
          .select()
          .eq('customer_phone', phone)
          .maybeSingle();

      if (daftar == null) return;

      final reserved = (daftar['reserved_balance'] as num?)?.toDouble() ?? 0;

      await supabase
          .from('daftar')
          .update({
            'reserved_balance': (reserved - amount).clamp(0, double.infinity),
          })
          .eq('id', daftar['id']);

      debugPrint("✅ تم تحرير $amount ﷼ من محجوز دفتر $phone");
    } catch (e) {
      debugPrint("Release daftar error: $e");
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
