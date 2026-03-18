import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/providers.dart';
import '../../../core/services/auth_storage.dart';
import '../../../core/navigation/main_navigation.dart'; // ✅ مهم
import 'register_screen.dart';

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

  String normalizePhone(String input) {
    String phone = input.replaceAll(" ", "");

    if (phone.startsWith("05")) {
      phone = "966${phone.substring(1)}";
    } else if (phone.startsWith("+966")) {
      phone = phone.replaceAll("+", "");
    }

    return phone;
  }

  Future<void> loginDirectly() async {
    if (isLoading) return;

    final rawPhone = phoneController.text.trim();

    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("الرجاء إدخال رقم الجوال")));
      return;
    }

    final phone = normalizePhone(rawPhone);

    setState(() => isLoading = true);

    try {
      final userService = ref.read(userServiceProvider);

      final user = await userService.getUserByPhone(phone);

      if (user == null) {
        await userService.ensureUserExists(phone);
      }

      await AuthStorage().savePhone(phone);

      ref.read(appStateProvider.notifier).setUserPhone(phone);

      if (!mounted) return;

      // 🔥 هنا التعديل المهم
      if (user != null &&
          user['name'] != null &&
          user['name'].toString().isNotEmpty) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const MainNavigation(initialIndex: 0),
          ),
          (route) => false,
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RegisterScreen(phone: phone)),
        );
      }
    } catch (e, stack) {
      debugPrint("LOGIN ERROR: $e");
      debugPrint("STACK: $stack");

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("حدث خطأ، حاول مرة أخرى")));
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
                hintText: "05XXXXXXXX",
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
