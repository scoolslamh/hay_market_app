import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final supabase = Supabase.instance.client;

  /// 🔍 جلب المستخدم حسب رقم الجوال
  Future<Map<String, dynamic>?> getUserByPhone(String phone) async {
    try {
      final data = await supabase
          .from('users')
          .select()
          .eq('phone', phone)
          .maybeSingle();

      return data;
    } catch (e) {
      print("GetUser Error: $e");
      return null;
    }
  }

  /// 🆕 إنشاء مستخدم جديد
  Future<void> createUser(Map<String, dynamic> data) async {
    try {
      await supabase.from('users').insert(data);
    } catch (e) {
      print("CreateUser Error: $e");
      rethrow;
    }
  }

  /// 🔄 تحديث بيانات المستخدم
  Future<void> updateProfile({
    required String phone,
    required String name,
    required String email,
    String? address,
    Map<String, dynamic>? locationData,
  }) async {
    try {
      // تحديث جدول users
      await supabase.from("users").upsert({
        "phone": phone,
        "name": name,
        "email": email,
        "address": address,
        "role": "customer",
      }, onConflict: 'phone');

      // تحديث العنوان
      if (locationData != null) {
        await supabase.from("addresses").upsert({
          "phone": phone,
          "address_name": locationData['address'],
          "lat": locationData['lat'],
          "lng": locationData['lng'],
        }, onConflict: 'phone');
      }
    } catch (e) {
      print("UpdateProfile Error: $e");
      rethrow;
    }
  }

  /// ✅ التحقق من وجود المستخدم
  Future<bool> userExists(String phone) async {
    final data = await getUserByPhone(phone);
    return data != null;
  }

  /// 🔥 إنشاء المستخدم إذا لم يكن موجود (الأفضل استخدامه)
  Future<void> ensureUserExists(String phone) async {
    final existing = await getUserByPhone(phone);

    if (existing == null) {
      await createUser({
        'phone': phone,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }
}
