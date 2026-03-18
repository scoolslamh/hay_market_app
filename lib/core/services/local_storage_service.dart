import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const neighborhoodKey = "user_neighborhood";
  static const phoneKey = "user_phone"; // إضافة مفتاح لرقم الجوال

  // --- دوال خاصة برقم الجوال (مطلوبة لـ AppStateNotifier) ---

  Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  // --- الدوال السابقة الخاصة بالحي (للحفاظ على المميزات القديمة) ---

  Future<void> saveNeighborhood(String id) async {
    await setString(neighborhoodKey, id);
  }

  Future<String?> getNeighborhood() async {
    return await getString(neighborhoodKey);
  }
}
