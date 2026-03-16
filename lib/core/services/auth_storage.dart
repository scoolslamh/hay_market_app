import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const userPhoneKey = "user_phone";

  /// حفظ رقم الهاتف
  Future<void> savePhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userPhoneKey, phone);
  }

  /// قراءة رقم الهاتف
  Future<String?> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(userPhoneKey);
  }

  /// تسجيل الخروج
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(userPhoneKey);
  }
}
