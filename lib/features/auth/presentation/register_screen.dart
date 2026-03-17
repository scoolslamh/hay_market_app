import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/navigation/main_navigation.dart';
import 'map_picker_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String phone;
  const RegisterScreen({super.key, required this.phone});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();

  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  // متغير لحفظ بيانات الموقع الدقيقة (lat, lng, address) القادمة من الخريطة
  Map<String, dynamic>? _selectedLocationData;

  Future<void> saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. الحصول على هوية المستخدم الحالي (User ID)
      final user = supabase.auth.currentUser;
      if (user == null) throw "لم يتم العثور على جلسة مستخدم نشطة";

      // 2. إدخال البيانات في جدول users (البيانات الشخصية)
      await supabase.from("users").insert({
        "id": user.id, // نستخدم الـ ID الخاص بـ Auth
        "phone": widget.phone,
        "name": nameController.text,
        "email": emailController.text,
        "address": addressController.text,
        "role": "customer",
      });

      // 3. إدخال الموقع الدقيق في جدول addresses (موقع التوصيل)
      if (_selectedLocationData != null) {
        await supabase.from("addresses").insert({
          "user_id": user.id,
          "address_name": _selectedLocationData!['address'],
          "lat": _selectedLocationData!['lat'],
          "lng": _selectedLocationData!['lng'],
        });
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("حدث خطأ أثناء الحفظ: $e")));
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
        _selectedLocationData =
            result; // حفظ البيانات كاملة (الإحداثيات + النص)
        addressController.text = result['address']; // عرض النص فقط للمستخدم
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
              const SizedBox(height: 20),

              // حقل الاسم
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

              // حقل البريد الإلكتروني
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
                  if (value == null || value.isEmpty)
                    return "يرجى إدخال البريد";
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value))
                    return "بريد غير صحيح";
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // حقل العنوان
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

              // زر اختيار الموقع
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

              // زر الحفظ
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
                        "حفظ وإكمال التسجيل",
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
