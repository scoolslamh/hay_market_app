import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/auth_storage.dart';
import '../../../core/state/providers.dart';

import '../../auth/presentation/login_screen.dart';
import '../../orders/presentation/orders_screen.dart';
import '../../location/presentation/neighborhood_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  String? userName;
  String? avatarUrl;
  bool uploading = false;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    Future.microtask(loadUserData);
  }

  /// تحميل بيانات المستخدم (نفس منطق كودك الأصلي)
  Future<void> loadUserData() async {
    final phone = ref.read(appStateProvider).userPhone;
    if (phone == null) return;

    try {
      final response = await Supabase.instance.client
          .from("users")
          .select()
          .eq("phone", phone)
          .single();

      setState(() {
        userName = response["name"];
        avatarUrl = response["avatar"];
      });
    } catch (e) {
      debugPrint("Load user error: $e");
    }
  }

  /// اختيار وصورة ورفعها (نفس منطق كودك الأصلي مع الحفاظ على Upsert)
  Future<void> pickImage() async {
    final phone = ref.read(appStateProvider).userPhone;
    if (phone == null) return;

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (picked == null) return;
    final file = File(picked.path);
    final path = "$phone/avatar.jpg";

    setState(() => uploading = true);

    try {
      final bytes = await file.readAsBytes();
      await Supabase.instance.client.storage
          .from("avatars")
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final url = Supabase.instance.client.storage
          .from("avatars")
          .getPublicUrl(path);
      await Supabase.instance.client
          .from("users")
          .update({"avatar": url})
          .eq("phone", phone);

      final newUrl = "$url?v=${DateTime.now().millisecondsSinceEpoch}";

      setState(() {
        avatarUrl = newUrl;
        uploading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("تم تحديث الصورة")));
    } catch (e) {
      setState(() => uploading = false);
      debugPrint("Upload avatar error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(appStateProvider).userPhone;
    const primaryColor = Color(0xFF004D40); // لون دكان الحي

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "حسابي",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          /// الجزء العلوي: بطاقة المعلومات والصورة
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: pickImage,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white24,
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl!)
                            : null,
                        child: avatarUrl == null
                            ? const Icon(
                                Icons.camera_alt,
                                size: 35,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      if (uploading)
                        const CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.black45,
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      // أيقونة تعديل صغيرة
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.edit,
                            size: 15,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  userName ?? "مستخدم دكان الحي",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  phone ?? "",
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          /// القائمة الاحترافية
          _buildMenuTile(
            icon: Icons.shopping_bag_outlined,
            title: "طلباتي",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrdersScreen()),
            ),
          ),
          _buildMenuTile(
            icon: Icons.location_on_outlined,
            title: "العنوان",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NeighborhoodScreen()),
            ),
          ),
          _buildMenuTile(
            icon: Icons.settings_outlined,
            title: "الإعدادات",
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("الإعدادات قريباً")));
            },
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),

          /// تسجيل الخروج بتصميم مميز
          ListTile(
            onTap: () async {
              final storage = AuthStorage();
              await storage.logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              "تسجيل الخروج",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            tileColor: Colors.red.withOpacity(0.05),
          ),
        ],
      ),
    );
  }

  /// ودجت مخصص لبناء عناصر القائمة (لضمان تناسق التصميم)
  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF004D40)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
}
