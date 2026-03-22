import 'package:flutter/material.dart';
import '../../../core/utils/app_notification.dart';
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
  bool _isLoading = false;

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  Future<void> verifyOtp() async {
    final otp = otpController.text.trim();

    if (otp.isEmpty) {
      AppNotification.warning(context, "الرجاء إدخال رمز التحقق");
      return;
    }

    final originalPhone = ref.read(appStateProvider).userPhone;

    if (originalPhone == null) {
      AppNotification.error(context, "حدث خطأ: رقم الهاتف غير موجود");
      return;
    }

    // --- التعديل الجوهري للوضع التجريبي ---
    // سوبابيس في خانة Test Phone Numbers يطلب الرقم "صافي" بدون +
    final cleanPhoneForTest = originalPhone.replaceAll('+', '').trim();

    final supabase = Supabase.instance.client;
    setState(() => _isLoading = true);

    try {
      final AuthResponse response = await supabase.auth.verifyOTP(
        phone: cleanPhoneForTest, // نرسل الرقم بدون زائد ليطابق الإعدادات
        token: otp,
        type: OtpType.sms,
      );

      if (response.session != null) {
        // البحث عن بيانات المستخدم
        final userData = await supabase
            .from("users")
            .select()
            .eq("phone", originalPhone)
            .maybeSingle();

        final storage = AuthStorage();
        await storage.savePhone(originalPhone);

        if (!mounted) return;

        if (userData == null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RegisterScreen(phone: originalPhone),
            ),
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        // إذا فشل بالرقم الصافي، نحاول مرة أخيرة بالرقم الأصلي (احتياطاً)
        AppNotification.error(context, "خطأ: ${e.message}");
      }
    } catch (e) {
      if (mounted) {
        AppNotification.error(context, "حدث خطأ غير متوقع");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(appStateProvider).userPhone;

    return Scaffold(
      appBar: AppBar(title: const Text("رمز التحقق"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: Color(0xFF004D40)),
            const SizedBox(height: 24),
            const Text("أدخل الرمز التجريبي المرسل إلى:"),
            Text(
              phone ?? "",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, letterSpacing: 10),
              decoration: InputDecoration(
                hintText: "000000",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: _isLoading ? null : verifyOtp,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "تأكيد الرمز",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
