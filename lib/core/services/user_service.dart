import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final supabase = Supabase.instance.client;

  /// التحقق من وجود المستخدم وجلب بياناته إن وجدت
  Future<Map<String, dynamic>?> getUserByPhone(String phone) async {
    final data = await supabase
        .from('users')
        .select()
        .eq('phone', phone)
        .maybeSingle();

    return data; // سيعيد null إذا كان المستخدم جديداً
  }

  /// وظيفة حفظ أو تحديث بيانات المستخدم (الاسم، البريد، العنوان)
  Future<void> updateProfile({
    required String phone,
    required String name,
    required String email,
    String? address,
    Map<String, dynamic>? locationData,
  }) async {
    // 1. تحديث الجدول الرئيسي للمستخدمين
    await supabase.from("users").upsert({
      "phone": phone,
      "name": name,
      "email": email,
      "address": address,
      "role": "customer",
    }, onConflict: 'phone');

    // 2. تحديث جدول العناوين إذا توفرت بيانات الموقع
    if (locationData != null) {
      await supabase.from("addresses").upsert({
        "phone": phone,
        "address_name": locationData['address'],
        "lat": locationData['lat'],
        "lng": locationData['lng'],
      }, onConflict: 'phone');
    }
  }

  /// دالة بسيطة للتحقق من الوجود (اختياري)
  Future<bool> userExists(String phone) async {
    final data = await getUserByPhone(phone);
    return data != null;
  }
}
