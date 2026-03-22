import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/auth_storage.dart';
import '../../../core/state/providers.dart';
import '../../../core/utils/app_notification.dart';

import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/map_picker_screen.dart';
import '../../orders/presentation/orders_screen.dart';
import '../../location/presentation/edit_location_screen.dart';
import '../../daftar/presentation/daftar_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);
  static const String _supportPhone = '966552134846';

  String? userName;
  String? userEmail;
  String? avatarUrl;
  String? address;
  int ordersCount = 0;
  double ordersTotal = 0;
  bool uploading = false;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      loadUserData();
      _loadAddress();
      _loadOrdersStats();
    });
  }

  Future<void> _loadAddress() async {
    final phone = ref.read(appStateProvider).userPhone;
    if (phone == null) return;
    final data = await Supabase.instance.client
        .from('addresses')
        .select()
        .eq('phone', phone)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (!mounted) return;
    setState(() => address = data?['address_name']);
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
      if (!mounted) return;
      setState(() {
        userName = response["name"];
        userEmail = response["email"];
        avatarUrl = response["avatar"];
      });
    } catch (e) {
      debugPrint("Load user error: $e");
    }
  }

  Future<void> _loadOrdersStats() async {
    final phone = ref.read(appStateProvider).userPhone;
    if (phone == null) return;
    try {
      final data = await Supabase.instance.client
          .from('orders')
          .select('total')
          .eq('phone', phone);
      if (!mounted) return;
      final list = List<Map<String, dynamic>>.from(data);
      setState(() {
        ordersCount = list.length;
        ordersTotal = list.fold(
          0,
          (sum, o) => sum + ((o['total'] as num?) ?? 0),
        );
      });
    } catch (e) {
      debugPrint("Load stats error: $e");
    }
  }

  Future<void> _openWhatsApp() async {
    final url = Uri.parse('https://wa.me/$_supportPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) AppNotification.error(context, "تعذر فتح واتساب");
    }
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
    setState(() => uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final path = "$phone/avatar.jpg";
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
      if (!mounted) return;
      setState(() {
        avatarUrl = "$url?v=${DateTime.now().millisecondsSinceEpoch}";
        uploading = false;
      });
      AppNotification.success(context, "تم تحديث الصورة");
    } catch (e) {
      if (!mounted) return;
      setState(() => uploading = false);
      AppNotification.error(context, "فشل رفع الصورة");
    }
  }

  void _showEditSheet() {
    final nameController = TextEditingController(text: userName);
    final emailController = TextEditingController(text: userEmail);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        // ✅ يقرأ ارتفاع الكيبورد من context الداخلي
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "تعديل البيانات",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: "الاسم الكامل",
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: _primaryDark,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "البريد الإلكتروني",
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: _primaryDark,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      final phone = ref.read(appStateProvider).userPhone;
                      if (phone == null) return;
                      try {
                        await Supabase.instance.client
                            .from("users")
                            .update({
                              "name": nameController.text.trim(),
                              "email": emailController.text.trim(),
                            })
                            .eq("phone", phone);
                        if (!mounted) return;
                        setState(() {
                          userName = nameController.text.trim();
                          userEmail = emailController.text.trim();
                        });
                        Navigator.pop(context);
                        AppNotification.success(
                          context,
                          "تم تحديث البيانات بنجاح",
                        );
                      } catch (e) {
                        if (!mounted) return;
                        AppNotification.error(context, "حدث خطأ أثناء الحفظ");
                      }
                    },
                    child: const Text(
                      "حفظ التعديلات",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleAddressTap() async {
    final phone = ref.read(appStateProvider).userPhone;
    if (phone == null) return;
    final addressData = await Supabase.instance.client
        .from('addresses')
        .select()
        .eq('phone', phone)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    double? lat = addressData?['lat'];
    double? lng = addressData?['lng'];
    String currentAddress =
        addressData?['address_name'] ?? "لا يوجد عنوان مسجل";
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on,
                color: _primaryDark,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "عنوان التوصيل",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              currentAddress,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapPickerScreen(
                        initialLocation: (lat != null && lng != null)
                            ? LatLng(lat, lng)
                            : null,
                      ),
                    ),
                  );
                  if (result != null && result is Map<String, dynamic>) {
                    try {
                      final p = ref.read(appStateProvider).userPhone;
                      if (p == null) return;
                      final existing = await Supabase.instance.client
                          .from('addresses')
                          .select('id')
                          .eq('phone', p)
                          .maybeSingle();
                      if (existing != null) {
                        await Supabase.instance.client
                            .from('addresses')
                            .update({
                              "address_name": result['address'],
                              "lat": result['lat'],
                              "lng": result['lng'],
                            })
                            .eq('phone', p);
                      } else {
                        await Supabase.instance.client
                            .from('addresses')
                            .insert({
                              "phone": p,
                              "address_name": result['address'],
                              "lat": result['lat'],
                              "lng": result['lng'],
                            });
                      }
                      await _loadAddress();
                      if (!mounted) return;
                      messenger.clearSnackBars();
                      AppNotification.success(
                        context,
                        "تم تحديث العنوان بنجاح",
                      );
                    } catch (e) {
                      if (!mounted) return;
                      AppNotification.error(
                        context,
                        "حدث خطأ أثناء حفظ العنوان",
                      );
                    }
                  }
                },
                icon: const Icon(Icons.edit_location_alt),
                label: const Text(
                  "تعديل العنوان",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(appStateProvider).userPhone;
    final state = ref.watch(appStateProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "حسابي",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildUserCard(phone),
          const SizedBox(height: 16),
          _buildStats(),
          const SizedBox(height: 16),
          _buildMenuSection(state),
          const SizedBox(height: 16),
          _buildLogout(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildUserCard(String? phone) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _primaryDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: pickImage,
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white24,
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: uploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : avatarUrl == null
                      ? const Icon(
                          Icons.person,
                          color: Colors.white70,
                          size: 44,
                        )
                      : null,
                ),
              ),
              // ✅ أيقونة القلم
              Positioned(
                bottom: 0,
                left: 0,
                child: GestureDetector(
                  onTap: pickImage,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            userName ?? "مستخدم",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          if (userEmail != null && userEmail!.isNotEmpty)
            Text(
              userEmail!,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          const SizedBox(height: 4),
          if (phone != null)
            Text(
              phone,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _showEditSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white30),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, color: Colors.white, size: 15),
                  SizedBox(width: 6),
                  Text(
                    "تعديل البيانات",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final totalStr = ordersTotal % 1 == 0
        ? ordersTotal.toInt().toString()
        : ordersTotal.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  "$ordersCount",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "طلب",
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey[200]),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      totalStr,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _primaryDark,
                      ),
                    ),
                    const Text(
                      " ﷼",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _primaryDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "إجمالي المشتريات",
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(appState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTile(
            icon: Icons.book_outlined,
            title: "دفتري 📒",
            subtitle: "دفتر البقالة الرقمي",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DaftarScreen()),
            ),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.shopping_bag_outlined,
            title: "طلباتي",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrdersScreen()),
            ),
            isFirst: true,
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.store_mall_directory_outlined,
            title: "موقعي",
            subtitle:
                "${appState.neighborhoodName ?? ''} - ${appState.marketName ?? ''}",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditLocationScreen()),
            ),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.location_on_outlined,
            title: "عنوان التوصيل",
            subtitle: address ?? "لم يتم تحديد عنوان",
            onTap: _handleAddressTap,
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.notifications_none,
            title: "الإشعارات",
            onTap: () => AppNotification.info(context, "قريباً..."),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.support_agent,
            title: "الدعم",
            subtitle: "تواصل معنا عبر واتساب",
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat, color: Color(0xFF25D366), size: 14),
                  SizedBox(width: 4),
                  Text(
                    "واتساب",
                    style: TextStyle(
                      color: Color(0xFF25D366),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            onTap: _openWhatsApp,
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.info_outline,
            title: "عن التطبيق",
            isLast: true,
            onTap: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text(
                  "دكان الحارة",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _primaryDark,
                  ),
                ),
                content: const Text(
                  "دكان الحارة هو تطبيق يُقرّب بين المستهلك ومتاجر حيّه بشكل سريع وسهل.\n\n"
                  "نؤمن بأن التسوق من أهل الحي يُعزز الاقتصاد المحلي ويوفر الوقت والجهد.\n\n"
                  "اطلب منتجاتك اليومية من متجرك المفضل وسنوصّلها إليك بكل سهولة.",
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 14, height: 1.7),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "حسناً",
                      style: TextStyle(color: _primaryDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _primaryDark, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                const Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() =>
      Divider(height: 1, color: Colors.grey[100], indent: 66);

  Widget _buildLogout() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          final navigator = Navigator.of(context);
          await AuthStorage().logout();
          // ✅ إعادة تهيئة AppState لمسح بيانات الجلسة
          ref.read(appStateProvider.notifier).reset();
          if (!mounted) return;
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                "تسجيل الخروج",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
