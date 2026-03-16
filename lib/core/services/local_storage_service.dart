import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const neighborhoodKey = "user_neighborhood";

  Future<void> saveNeighborhood(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(neighborhoodKey, id);
  }

  Future<String?> getNeighborhood() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(neighborhoodKey);
  }
}
