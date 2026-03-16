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

  /// تحميل بيانات المستخدم
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

  /// اختيار صورة
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

    setState(() {
      uploading = true;
    });

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

      /// تحديث قاعدة البيانات
      await Supabase.instance.client
          .from("users")
          .update({"avatar": url})
          .eq("phone", phone);

      /// منع cache
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
      setState(() {
        uploading = false;
      });

      debugPrint("Upload avatar error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(appStateProvider).userPhone;

    return Scaffold(
      appBar: AppBar(title: const Text("الحساب")),

      body: ListView(
        padding: const EdgeInsets.all(20),

        children: [
          /// صورة المستخدم
          Center(
            child: GestureDetector(
              onTap: pickImage,

              child: Stack(
                alignment: Alignment.center,

                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.green.shade100,
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl!)
                        : null,
                    child: avatarUrl == null
                        ? const Icon(Icons.camera_alt, size: 32)
                        : null,
                  ),

                  if (uploading)
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(45),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          /// الهاتف + الاسم
          Center(
            child: Column(
              children: [
                Text(
                  phone ?? "",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  userName ?? "",
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          const Divider(),

          /// طلباتي
          ListTile(
            leading: const Icon(Icons.shopping_bag),
            title: const Text("طلباتي"),
            trailing: const Icon(Icons.arrow_forward_ios),

            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrdersScreen()),
              );
            },
          ),

          /// العنوان
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text("العنوان"),
            trailing: const Icon(Icons.arrow_forward_ios),

            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NeighborhoodScreen()),
              );
            },
          ),

          /// الإعدادات
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("الإعدادات"),
            trailing: const Icon(Icons.arrow_forward_ios),

            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("الإعدادات قريباً")));
            },
          ),

          const Divider(),

          /// تسجيل الخروج
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              "تسجيل الخروج",
              style: TextStyle(color: Colors.red),
            ),

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
          ),
        ],
      ),
    );
  }
}
