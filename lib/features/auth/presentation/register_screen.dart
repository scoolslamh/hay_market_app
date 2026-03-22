import 'package:flutter/material.dart';
import '../../../core/utils/app_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/state/providers.dart';
import '../../location/presentation/neighborhood_screen.dart';
import 'map_picker_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final String phone;
  const RegisterScreen({super.key, required this.phone});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();

  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  Map<String, dynamic>? _selectedLocationData;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. حفظ بيانات المستخدم في جدول users وجلب الـ 'id' المولد تلقائياً
      // نستخدم .select('id').single() للحصول على المعرف فور الحفظ
      final userResponse = await supabase
          .from("users")
          .upsert({
            "phone": widget.phone,
            "name": nameController.text.trim(),
            "email": emailController.text.trim(),
            "address": addressController.text,
            "role": "customer",
          }, onConflict: 'phone')
          .select('id')
          .single();

      final String generatedUserId = userResponse['id'];

      // 2. إدخال الموقع الدقيق في جدول addresses مع ربطه بـ user_id الصحيح
      if (_selectedLocationData != null) {
        await supabase.from("addresses").upsert({
          "user_id": generatedUserId, // ✅ الربط الصحيح بالمعرف
          "phone": widget.phone, // الاحتفاظ بالرقم كمرجع إضافي
          "address_name": _selectedLocationData!['address'],
          "lat": _selectedLocationData!['lat'],
          "lng": _selectedLocationData!['lng'],
        }, onConflict: 'phone');
      }

      // 3. تحديث حالة التطبيق المحلية
      ref.read(appStateProvider.notifier).setUserPhone(widget.phone);

      if (!mounted) return;

      AppNotification.success(context, "تم حفظ بياناتك بنجاح، اختر حيك الآن");

      // 4. التوجه لاختيار الحي
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const NeighborhoodScreen()),
        (route) => false,
      );
    } catch (e) {
      AppNotification.error(context, "حدث خطأ أثناء الحفظ: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _selectedLocationData = result;
        addressController.text = result['address'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إكمال التسجيل"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "الاسم الكامل",
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? "يرجى إدخال الاسم"
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "البريد الإلكتروني",
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "يرجى إدخال البريد";
                  }
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value)) {
                    return "بريد غير صحيح";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: addressController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "عنوان التوصيل المختار",
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? "يرجى تحديد الموقع من الخريطة"
                    : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.map_outlined),
                label: const Text("اختيار الموقع من الخريطة"),
                onPressed: pickLocation,
              ),
              const SizedBox(height: 40),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004D40),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: saveUser,
                      child: const Text(
                        "حفظ واختيار الحي",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
