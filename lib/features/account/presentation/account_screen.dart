import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/auth_storage.dart';
import '../../../core/state/providers.dart';

import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/map_picker_screen.dart';
import '../../orders/presentation/orders_screen.dart';
import '../../location/presentation/edit_location_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  String? userName;
  String? avatarUrl;

  String? address;
  String? notes;

  bool uploading = false;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      loadUserData();
      _loadAddress();
    });
  }

  // تم إصلاح الخطأ عبر تعريف phone من الـ Provider
  Future<void> _loadAddress() async {
    // جلب رقم الهاتف من الحالة (Provider)
    final phone = ref.read(appStateProvider).userPhone;
    if (phone == null) return;

    final data = await Supabase.instance.client
        .from('addresses')
        .select()
        .eq('phone', phone) // استخدام phone كمعرف
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (!mounted) return;

    setState(() {
      address = data?['address_name'];
      notes = data?['notes'];
    });
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

  void _handleAddressTap() async {
    // جلب رقم الهاتف من الحالة (Provider)
    final phone = ref.read(appStateProvider).userPhone;
    if (phone == null) return;

    final addressData = await Supabase.instance.client
        .from('addresses')
        .select()
        .eq('phone', phone) // استخدام phone كمعرف
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    String currentAddress =
        addressData?['address_name'] ?? "لا يوجد عنوان مسجل";
    String? currentNotes = addressData?['notes'];

    double? lat = addressData?['lat'];
    double? lng = addressData?['lng'];

    if (!mounted) return;

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
            if (currentNotes != null && currentNotes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  "ملاحظات: $currentNotes",
                  style: TextStyle(color: Colors.grey[600]),
                ),
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
                Navigator.pop(context);

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

                if (result != null) {
                  await _loadAddress();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("تم تحديث العنوان بنجاح"),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.edit_location_alt),
              label: const Text("تعديل العنوان"),
            ),
          ],
        ),
      ),
    );
  }

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
    final state = ref.watch(appStateProvider);

    const primaryColor = Color(0xFF004D40);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("لوحة التحكم"),
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
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white24,
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl!)
                        : null,
                    child: uploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : (avatarUrl == null
                              ? const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                )
                              : null),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  userName ?? "مستخدم",
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
                Text(
                  phone ?? "",
                  style: const TextStyle(color: Colors.white70),
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
            icon: Icons.store_mall_directory_outlined,
            title: "موقعي (الحي والمتجر)",
            subtitle:
                "${state.neighborhoodName ?? ''} - ${state.marketName ?? ''}",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditLocationScreen()),
            ),
          ),
          _buildMenuTile(
            icon: Icons.location_on_outlined,
            title: "العنوان",
            subtitle: address != null
                ? "$address ${notes?.isNotEmpty == true ? '- $notes' : ''}"
                : "حدد موقعك الآن",
            onTap: () => _handleAddressTap(),
          ),
          _buildMenuTile(
            icon: Icons.notifications_none,
            title: "الإشعارات",
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("قريباً")));
            },
          ),
          _buildMenuTile(
            icon: Icons.support_agent,
            title: "الدعم",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("تواصل معنا قريباً")),
              );
            },
          ),
          _buildMenuTile(
            icon: Icons.info_outline,
            title: "عن التطبيق",
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: "دكان الحارة",
                applicationVersion: "1.0.0",
                applicationLegalese: "© 2026 جميع الحقوق محفوظة",
              );
            },
          ),
          const SizedBox(height: 20),
          const Divider(),
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
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF004D40)),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
