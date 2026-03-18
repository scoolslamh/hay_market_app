import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/providers.dart';
import 'register_screen.dart'; // المسار: lib/features/auth/presentation/register_screen.dart
import '../../home/presentation/home_screen.dart'; // المسار: lib/features/home/presentation/home_screen.dart

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final phoneController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  Future<void> loginDirectly() async {
    final phone = phoneController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("الرجاء إدخال رقم الجوال")));
      return;
    }

    setState(() => isLoading = true);

    try {
      // 1. جلب خدمة المستخدم من المزود (Provider)
      final userService = ref.read(userServiceProvider);

      // 2. التحقق من وجود المستخدم في قاعدة البيانات (Supabase)
      final user = await userService.getUserByPhone(phone);

      // 3. تحديث رقم الجوال في الحالة العامة للتطبيق (AppState)
      ref.read(appStateProvider.notifier).setUserPhone(phone);

      if (!mounted) return;

      // ✅ التصحيح 1: التعامل مع user كـ Map واستخدام ['name'] بدلاً من .name
      if (user != null &&
          user['name'] != null &&
          user['name'].toString().isNotEmpty) {
        // إذا كان المستخدم موجوداً وبياناته مكتملة، نتوجه للرئيسية
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else {
        // ✅ التصحيح 2: تمرير رقم الجوال المطلوب (phone) لشاشة RegisterScreen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RegisterScreen(phone: phone)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("حدث خطأ: ${e.toString()}")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل الدخول")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "رقم الجوال",
                prefixText: "+966 ",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : loginDirectly,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("دخول"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
