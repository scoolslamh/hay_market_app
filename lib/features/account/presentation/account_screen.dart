import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // أضف هذا
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/auth_storage.dart';
import '../../../core/state/providers.dart';

import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/map_picker_screen.dart'; // استيراد شاشة الخريطة
import '../../orders/presentation/orders_screen.dart';

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

  /// دالة جلب وعرض العنوان الحالي في BottomSheet
  void _handleAddressTap() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // 1. جلب العنوان الحالي من جدول addresses
    final addressData = await Supabase.instance.client
        .from('addresses')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    String currentAddress =
        addressData?['address_name'] ?? "لا يوجد عنوان مسجل";
    double? lat = addressData?['lat'];
    double? lng = addressData?['lng'];

    if (!mounted) return;

    // 2. عرض الـ BottomSheet
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.location_on, size: 50, color: Color(0xFF004D40)),
            const SizedBox(height: 15),
            const Text(
              "عنوان التوصيل الحالي",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              currentAddress,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004D40),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () async {
                Navigator.pop(context); // إغلاق الـ BottomSheet

                // الانتقال للخريطة وتمرير الموقع الحالي إن وجد
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MapPickerScreen(
                      initialLocation: (lat != null && lng != null)
                          ? LatLng(lat, lng)
                          : null,
                    ),
                  ),
                );

                // إذا اختار موقعاً جديداً، سيتم الحفظ تلقائياً في الخريطة، ونحن هنا فقط نحدث الـ UI
                if (result != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("تم تحديث العنوان بنجاح")),
                  );
                }
              },
              icon: const Icon(Icons.edit_location_alt),
              label: const Text("تعديل الموقع من الخريطة"),
            ),
          ],
        ),
      ),
    );
  }

  // (دالة pickImage كما هي في كودك الأصلي...)
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
    } catch (e) {
      setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(appStateProvider).userPhone;
    const primaryColor = Color(0xFF004D40);

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
            onTap: _handleAddressTap, // استدعاء الدالة الجديدة هنا
          ),
          _buildMenuTile(
            icon: Icons.settings_outlined,
            title: "الإعدادات",
            onTap: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("الإعدادات قريباً"))),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          ListTile(
            onTap: () async {
              final storage = AuthStorage();
              await storage.logout();
              if (!mounted) return;
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
