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
  // مفتاح التحقق من النموذج
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();

  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  // دالة الحفظ مع التحقق
  Future<void> saveUser() async {
    // 1. التأكد من صحة البيانات المدخلة أولاً
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await supabase.from("users").insert({
        "phone": widget.phone,
        "name": nameController.text,
        "email": emailController.text,
        "address": addressController.text,
        "role": "customer", // تحديد الدور افتراضياً
      });

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

  // دالة التقاط الموقع من الخريطة
  Future<void> pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );

    // التحقق من النتيجة (إذا كانت Map كما صممناها سابقاً أو String)
    if (result != null) {
      setState(() {
        if (result is Map) {
          addressController.text = result['address'];
        } else {
          addressController.text = result.toString();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إكمال التسجيل"), centerTitle: true),
      body: SingleChildScrollView(
        // لتجنب مشاكل لوحة المفاتيح
        padding: const EdgeInsets.all(24),
        child: Form(
          // إضافة الـ Form للتحقق
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

              // حقل البريد الإلكتروني مع التحقق
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
                  ).hasMatch(value)) {
                    return "يرجى إدخال بريد إلكتروني صحيح";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // حقل العنوان (للقراءة فقط لأنه يأتي من الخريطة)
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

              // زر الحفظ النهائي
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF004D40,
                        ), // لون دكان الحي
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: saveUser,
                      child: const Text(
                        "حفظ البيانات وإكمال التسجيل",
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
