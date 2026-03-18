import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_state.dart';

class AppStateNotifier extends StateNotifier<AppState> {
  final SupabaseClient supabase;

  AppStateNotifier({required this.supabase}) : super(AppState());

  /// 🔹 حفظ رقم المستخدم
  void setUserPhone(String phone) {
    state = state.copyWith(userPhone: phone);
  }

  /// 🔹 حفظ الماركت المختار
  void setMarket(String marketId, String marketName) {
    state = state.copyWith(
      marketId: marketId,
      marketName: marketName,
      products: [], // 🔥 مهم لتفريغ المنتجات عند تغيير المتجر
    );
  }

  /// 🔹 حفظ الحي المختار
  void setNeighborhood(String neighborhoodId, String neighborhoodName) {
    state = state.copyWith(
      neighborhoodId: neighborhoodId,
      neighborhoodName: neighborhoodName,
    );
  }

  /// 🔹 إزالة الماركت
  void clearMarket() {
    state = state.copyWith(
      marketId: null,
      marketName: null,
      products: [], // 🔥 تنظيف البيانات
    );
  }

  /// 🔥 تحميل البيانات الأساسية
  Future<void> loadInitialData() async {
    try {
      // ✅ منع إعادة التحميل إذا البيانات موجودة
      if (state.products.isNotEmpty) return;

      state = state.copyWith(isLoading: true);

      if (state.marketId == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final response = await supabase
          .from('products')
          .select()
          .eq('market_id', state.marketId!);

      final products = List<dynamic>.from(response);

      state = state.copyWith(products: products, isLoading: false);
    } catch (e, stack) {
      state = state.copyWith(isLoading: false);

      debugPrint("Error loading products: $e");
      debugPrintStack(stackTrace: stack);
    }
  }

  /// 🔄 تحديث يدوي (Pull to refresh)
  Future<void> refreshData() async {
    try {
      state = state.copyWith(isLoading: true);

      if (state.marketId == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final response = await supabase
          .from('products')
          .select()
          .eq('market_id', state.marketId!);

      final products = List<dynamic>.from(response);

      state = state.copyWith(products: products, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      debugPrint("Refresh error: $e");
    }
  }

  /// 🧹 إعادة ضبط الحالة (Logout)
  void reset() {
    state = AppState();
  }
}
