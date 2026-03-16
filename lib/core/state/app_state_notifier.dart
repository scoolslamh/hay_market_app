import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_state.dart';

class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier() : super(AppState());

  /// حفظ رقم المستخدم
  void setUserPhone(String phone) {
    state = state.copyWith(userPhone: phone);
  }

  /// حفظ الماركت المختار
  void setMarket(String marketId, String marketName) {
    state = state.copyWith(marketId: marketId, marketName: marketName);
  }

  /// حفظ الحي المختار
  void setNeighborhood(String neighborhoodId, String neighborhoodName) {
    state = state.copyWith(
      neighborhoodId: neighborhoodId,
      neighborhoodName: neighborhoodName,
    );
  }

  /// إزالة الماركت
  void clearMarket() {
    state = state.copyWith(marketId: null, marketName: null);
  }
}
