import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/state/providers.dart';
import '../../../core/services/auth_storage.dart';
import '../../../core/navigation/main_navigation.dart';
import 'register_screen.dart';
import '../../merchant/presentation/market_registration_screen.dart';

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

  // ✅ التحقق من كود الدعوة قبل فتح التسجيل
  void _showInviteCodeSheet() {
    final codeCtrl = TextEditingController();
    bool isChecking = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // شريط علوي
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),

                // أيقونة
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF004D40).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.vpn_key_outlined,
                    color: Color(0xFF004D40),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  "أدخل كود الدعوة",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "تواصل مع الإدارة للحصول على الكود",
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
                const SizedBox(height: 20),

                // حقل الكود
                TextField(
                  controller: codeCtrl,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                  decoration: InputDecoration(
                    hintText: "MARKET-XXXX",
                    hintStyle: TextStyle(
                      color: Colors.grey[300],
                      letterSpacing: 2,
                      fontSize: 16,
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF4CAF50),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // زر التحقق
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004D40),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: isChecking
                        ? null
                        : () async {
                            final code = codeCtrl.text.trim().toUpperCase();
                            if (code.isEmpty) return;

                            setSheetState(() => isChecking = true);

                            try {
                              // التحقق من الكود في القاعدة
                              final data = await Supabase.instance.client
                                  .from('invite_codes')
                                  .select()
                                  .eq('code', code)
                                  .eq('is_used', false)
                                  .maybeSingle();

                              if (!ctx.mounted) return;

                              if (data != null) {
                                // ✅ الكود صحيح
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MarketRegistrationScreen(
                                      inviteCode: code,
                                    ),
                                  ),
                                );
                              } else {
                                // ❌ الكود خطأ
                                setSheetState(() => isChecking = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "الكود غير صحيح أو مستخدم مسبقاً",
                                    ),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              setSheetState(() => isChecking = false);
                            }
                          },
                    child: isChecking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "تحقق من الكود",
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

            const SizedBox(height: 40),
            Divider(color: Colors.grey[200]),
            const SizedBox(height: 16),

            // ✅ زر تسجيل متجر جديد
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _showInviteCodeSheet(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF004D40)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(
                  Icons.store_outlined,
                  color: Color(0xFF004D40),
                ),
                label: const Text(
                  "تسجيل متجر جديد",
                  style: TextStyle(
                    color: Color(0xFF004D40),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ✅ رابط التواصل لطلب الانضمام
            GestureDetector(
              onTap: () async {
                final url = Uri.parse('https://wa.me/966552134846');
                if (await canLaunchUrl(url)) {
                  launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF004D40).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF004D40).withValues(alpha: 0.15),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.store_outlined,
                      color: Color(0xFF004D40),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "لطلب الانضمام كمتجر تموينات تواصل على الرقم 0552134846",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF004D40),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
