import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  /// 🔐 مفاتيح التخزين
  static const _userPhoneKey = "user_phone";
  static const _neighborhoodIdKey = "neighborhood_id";
  static const _marketIdKey = "market_id";
  static const _neighborhoodNameKey = "neighborhood_name";
  static const _marketNameKey = "market_name";

  /// =========================
  /// 📱 حفظ رقم الهاتف
  /// =========================
  Future<void> savePhone(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userPhoneKey, phone);
    } catch (e) {
      throw Exception("فشل حفظ رقم الهاتف");
    }
  }

  /// قراءة رقم الهاتف
  Future<String?> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userPhoneKey);
  }

  /// =========================
  /// 🏙️ حفظ اختيار المستخدم
  /// =========================
  Future<void> saveUserSelection({
    required String neighborhoodId,
    required String marketId,
    String? neighborhoodName,
    String? marketName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_neighborhoodIdKey, neighborhoodId);
      await prefs.setString(_marketIdKey, marketId);

      if (neighborhoodName != null) {
        await prefs.setString(_neighborhoodNameKey, neighborhoodName);
      }

      if (marketName != null) {
        await prefs.setString(_marketNameKey, marketName);
      }
    } catch (e) {
      throw Exception("فشل حفظ بيانات المستخدم");
    }
  }

  /// =========================
  /// 📥 جلب بيانات الاختيار
  /// =========================
  Future<Map<String, String?>> getUserSelection() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      "neighborhoodId": prefs.getString(_neighborhoodIdKey),
      "marketId": prefs.getString(_marketIdKey),
      "neighborhoodName": prefs.getString(_neighborhoodNameKey),
      "marketName": prefs.getString(_marketNameKey),
    };
  }

  /// =========================
  /// 🔍 هل المستخدم جاهز للدخول السريع؟
  /// =========================
  Future<bool> hasCompleteSession() async {
    final prefs = await SharedPreferences.getInstance();

    final phone = prefs.getString(_userPhoneKey);
    final neighborhood = prefs.getString(_neighborhoodIdKey);
    final market = prefs.getString(_marketIdKey);

    return phone != null && neighborhood != null && market != null;
  }

  /// =========================
  /// 🚪 تسجيل الخروج (كامل)
  /// =========================
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_userPhoneKey);
    await prefs.remove(_neighborhoodIdKey);
    await prefs.remove(_marketIdKey);
    await prefs.remove(_neighborhoodNameKey);
    await prefs.remove(_marketNameKey);
  }
}
