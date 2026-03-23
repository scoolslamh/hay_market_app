import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_storage.dart';
import '../../../core/state/providers.dart';
import '../../../core/utils/app_notification.dart';
import '../../../core/navigation/main_navigation.dart';
import '../../merchant/presentation/merchant_home_screen.dart';
import '../../merchant/presentation/merchant_pending_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final String phone;
  const RegisterScreen({super.key, required this.phone});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  final supabase = Supabase.instance.client;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  String _buildEmail(String phone) => '${_normalizePhone(phone)}@haymarket.app';

  String _normalizePhone(String phone) {
    phone = phone
        .trim()
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('+', '');
    if (phone.startsWith('00966')) return phone.replaceFirst('00966', '966');
    if (phone.startsWith('966') && phone.length == 12) return phone;
    if (phone.startsWith('0')) return '966${phone.substring(1)}';
    if (!phone.startsWith('966')) return '966$phone';
    return phone;
  }

  // ── التحقق من كلمة المرور ──
  String? _validatePassword(String password) {
    if (password.length < 6) {
      return "كلمة المرور يجب أن تكون 6 أحرف على الأقل";
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return "يجب أن تحتوي على حرف كبير";
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return "يجب أن تحتوي على رقم";
    }
    return null;
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final confirm = _confirmPasswordCtrl.text.trim();

    // التحقق من الحقول
    if (name.isEmpty) {
      AppNotification.warning(context, "أدخل اسمك الكامل");
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      AppNotification.warning(context, "أدخل بريد إلكتروني صحيح");
      return;
    }

    final passwordError = _validatePassword(password);
    if (passwordError != null) {
      AppNotification.warning(context, passwordError);
      return;
    }

    if (password != confirm) {
      AppNotification.warning(context, "كلمة المرور غير متطابقة");
      return;
    }

    setState(() => _isLoading = true);

    // ✅ توحيد صيغة الرقم
    final normalizedPhone = _normalizePhone(widget.phone);

    try {
      // التحقق من عدم تكرار الإيميل
      final emailCheck = await supabase
          .from('users')
          .select('email')
          .eq('email', email)
          .maybeSingle();

      if (emailCheck != null) {
        if (!mounted) return;
        AppNotification.error(context, "البريد الإلكتروني مستخدم مسبقاً");
        setState(() => _isLoading = false);
        return;
      }

      // ✅ استخدام الإيميل الحقيقي في Auth
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'phone': normalizedPhone, 'name': name},
      );

      if (response.user == null) {
        if (!mounted) return;
        AppNotification.error(context, "فشل إنشاء الحساب");
        setState(() => _isLoading = false);
        return;
      }

      // ✅ التحقق هل هو تاجر
      final marketCheck = await supabase
          .from('markets')
          .select('id, status')
          .eq('owner_phone', normalizedPhone)
          .maybeSingle();

      final isMerchant = marketCheck != null;
      final userRole = isMerchant ? 'merchant' : 'customer';

      // ✅ حفظ في جدول users بالرقم الموحد
      final existingUser = await supabase
          .from('users')
          .select('id')
          .eq('phone', normalizedPhone)
          .maybeSingle();

      if (existingUser == null) {
        await supabase.from('users').insert({
          'auth_id': response.user!.id,
          'phone': normalizedPhone,
          'name': name,
          'email': email,
          'role': userRole,
        });
      } else {
        await supabase
            .from('users')
            .update({
              'auth_id': response.user!.id,
              'name': name,
              'email': email,
              'role': userRole,
            })
            .eq('phone', normalizedPhone);
      }

      await AuthStorage().savePhone(normalizedPhone);

      final notifier = ref.read(appStateProvider.notifier);
      notifier.setUserPhone(widget.phone);

      if (!mounted) return;

      // إظهار تنبيه تأكيد الإيميل
      AppNotification.success(
        context,
        "تم إنشاء حسابك! تحقق من بريدك لتأكيد الحساب",
      );

      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      // ✅ توجيه حسب الدور
      if (isMerchant) {
        final marketStatus = marketCheck['status'] ?? 'pending';
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => marketStatus == 'active'
                ? const MerchantHomeScreen()
                : const MerchantPendingScreen(),
          ),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (e.message.contains('already registered')) {
        AppNotification.error(context, "هذا الرقم مسجل مسبقاً");
      } else {
        AppNotification.error(context, "خطأ: ${e.message}");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppNotification.error(context, "حدث خطأ: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "إنشاء حساب جديد",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // رقم الجوال (للعرض فقط)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.check_circle, color: _primary, size: 18),
                  Text(
                    widget.phone,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _primaryDark,
                      fontSize: 15,
                    ),
                  ),
                  const Text(
                    "رقم الجوال",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // الاسم
            _buildLabel("الاسم الكامل *"),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _nameCtrl,
              hint: "أدخل اسمك الكامل",
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),

            // البريد الإلكتروني
            _buildLabel("البريد الإلكتروني *"),
            const SizedBox(height: 4),
            Text(
              "يُستخدم لاستعادة كلمة المرور",
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _emailCtrl,
              hint: "example@email.com",
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // كلمة المرور
            _buildLabel("كلمة المرور *"),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      "6 أحرف على الأقل + رقم + حرف كبير\nمثال: Market1",
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.info_outline, color: Colors.orange, size: 16),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildPasswordField(
              controller: _passwordCtrl,
              hint: "أدخل كلمة المرور",
              obscure: _obscurePassword,
              onToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            const SizedBox(height: 16),

            // تأكيد كلمة المرور
            _buildLabel("تأكيد كلمة المرور *"),
            const SizedBox(height: 8),
            _buildPasswordField(
              controller: _confirmPasswordCtrl,
              hint: "أعد إدخال كلمة المرور",
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "إنشاء الحساب",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.right,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.grey[50],
        prefixIcon: Icon(icon, color: _primaryDark, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.grey[50],
        prefixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: Colors.grey,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
      ),
    );
  }
}
