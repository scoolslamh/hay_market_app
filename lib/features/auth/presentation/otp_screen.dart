import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/auth_storage.dart';
import '../../../core/state/providers.dart';
import '../../welcome/presentation/welcome_screen.dart';
import 'register_screen.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final otpController = TextEditingController();

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  Future<void> verifyOtp() async {
    final otp = otpController.text.trim();

    if (otp.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("الرجاء إدخال رمز التحقق")));
      return;
    }

    /// قراءة رقم الجوال
    final phone = ref.read(appStateProvider).userPhone;

    if (phone == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("حدث خطأ في تسجيل الدخول")));
      return;
    }

    final supabase = Supabase.instance.client;

    try {
      /// البحث عن المستخدم
      final user = await supabase
          .from("users")
          .select()
          .eq("phone", phone)
          .maybeSingle();

      /// حفظ تسجيل الدخول في الجهاز
      final storage = AuthStorage();
      await storage.savePhone(phone);

      if (!mounted) return;

      /// مستخدم جديد
      if (user == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => RegisterScreen(phone: phone)),
        );
      }
      /// مستخدم موجود
      else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("حدث خطأ: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(appStateProvider).userPhone;

    return Scaffold(
      appBar: AppBar(title: const Text("رمز التحقق")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "تم إرسال رمز التحقق إلى:",
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: 8),

            Text(
              phone ?? "",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 30),

            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "رمز التحقق",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: verifyOtp,
                child: const Text("تأكيد"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
