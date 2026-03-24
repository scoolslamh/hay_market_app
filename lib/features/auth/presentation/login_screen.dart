import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/auth_storage.dart';
import '../../../core/state/providers.dart';
import '../../../core/utils/app_notification.dart';
import '../../../core/navigation/main_navigation.dart';
import '../../merchant/presentation/market_registration_screen.dart';
import '../../merchant/presentation/merchant_home_screen.dart';
import '../../merchant/presentation/merchant_pending_screen.dart';
import '../../admin/presentation/admin_home_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  final supabase = Supabase.instance.client;
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _phoneExists = false;
  bool _phoneChecked = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ✅ توحيد صيغة الرقم دائماً بـ 966
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

  // ── التحقق من وجود الرقم ──
  Future<void> _checkPhone() async {
    final raw = _phoneCtrl.text.trim();
    final phone = _normalizePhone(raw);
    if (phone.length < 12) {
      AppNotification.warning(context, "أدخل رقم جوال صحيح");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // التحقق من المدير
      final adminCheck = await supabase
          .from('admins')
          .select()
          .eq('phone', phone)
          .maybeSingle();

      if (adminCheck != null) {
        setState(() {
          _phoneExists = true;
          _phoneChecked = true;
          _isLoading = false;
        });
        return;
      }

      // ✅ التحقق من وجود الرقم في جدول users مباشرة
      final userCheck = await supabase
          .from('users')
          .select('phone')
          .eq('phone', phone)
          .maybeSingle();

      if (userCheck != null) {
        // رقم موجود → اطلب كلمة المرور
        setState(() {
          _phoneExists = true;
          _phoneChecked = true;
          _isLoading = false;
        });
      } else {
        // رقم جديد → اذهب للتسجيل
        setState(() => _isLoading = false);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RegisterScreen(phone: phone)),
        );
      }
    } catch (e) {
      debugPrint("Check phone error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        AppNotification.error(context, "حدث خطأ، حاول مجدداً");
      }
    }
  }

  // ── تسجيل الدخول ──
  Future<void> _login() async {
    final raw = _phoneCtrl.text.trim();
    final phone = _normalizePhone(raw);
    final password = _passwordCtrl.text.trim();

    if (password.isEmpty) {
      AppNotification.warning(context, "أدخل كلمة المرور");
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? realEmail;

      // ✅ تحقق من المدير
      final adminCheck = await supabase
          .from('admins')
          .select('phone')
          .eq('phone', phone)
          .maybeSingle();

      if (adminCheck != null) {
        final adminUser = await supabase
            .from('users')
            .select('email')
            .eq('phone', phone)
            .maybeSingle();
        realEmail = adminUser?['email'] as String?;
      } else {
        final userCheck = await supabase
            .from('users')
            .select('email')
            .eq('phone', phone)
            .maybeSingle();

        if (userCheck != null) {
          final storedEmail = userCheck['email']?.toString() ?? '';
          // ✅ إذا الإيميل وهمي (haymarket.app) أو فارغ → ابنه من الرقم
          if (storedEmail.contains('@haymarket.app') || storedEmail.isEmpty) {
            realEmail = '${phone}@haymarket.app';
          } else {
            realEmail = storedEmail; // ✅ إيميل حقيقي
          }
        }
      }

      if (realEmail == null || realEmail.isEmpty) {
        AppNotification.error(context, "الرقم غير مسجل");
        setState(() => _isLoading = false);
        return;
      }

      final response = await supabase.auth.signInWithPassword(
        email: realEmail,
        password: password,
      );

      if (response.user == null) {
        AppNotification.error(context, "كلمة المرور غير صحيحة");
        setState(() => _isLoading = false);
        return;
      }

      if (!mounted) return;
      await _navigateAfterLogin(phone);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (e.message.contains('Email not confirmed')) {
        AppNotification.warning(context, "يرجى تأكيد بريدك الإلكتروني أولاً");
      } else if (e.message.contains('Invalid login') ||
          e.message.contains('Invalid email or password')) {
        AppNotification.error(context, "كلمة المرور غير صحيحة");
      } else {
        AppNotification.error(context, "حدث خطأ: ${e.message}");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppNotification.error(context, "حدث خطأ، حاول مجدداً");
    }
  }

  // ── التوجيه بعد الدخول ──
  Future<void> _navigateAfterLogin(String phone) async {
    // المدير
    final adminCheck = await supabase
        .from('admins')
        .select()
        .eq('phone', phone)
        .maybeSingle();

    if (adminCheck != null) {
      await AuthStorage().savePhone(phone);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
        (route) => false,
      );
      return;
    }

    // التاجر
    final marketResults = await supabase
        .from('markets')
        .select()
        .or('owner_phone.eq.$phone,owner_phone.eq.0${phone.substring(3)}')
        .limit(1);
    final marketCheck = marketResults.isNotEmpty ? marketResults.first : null;

    if (marketCheck != null) {
      await AuthStorage().savePhone(phone);
      if (!mounted) return;
      final status = marketCheck['status'] ?? 'pending';
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => status == 'active'
              ? const MerchantHomeScreen()
              : const MerchantPendingScreen(),
        ),
        (route) => false,
      );
      return;
    }

    // العميل
    final userData = await supabase
        .from('users')
        .select()
        .eq('phone', phone)
        .maybeSingle();

    await AuthStorage().savePhone(phone);
    if (!mounted) return;

    final notifier = ref.read(appStateProvider.notifier);
    notifier.setUserPhone(phone);

    if (userData != null) {
      // ✅ حاول تحميل البقالة من قاعدة البيانات
      final mId = userData['market_id']?.toString();
      final mName = userData['market_name']?.toString() ?? '';
      if (mId != null && mId.isNotEmpty) {
        notifier.setMarket(mId, mName);
      } else {
        // ✅ حاول من SharedPreferences
        final saved = await AuthStorage().getUserSelection();
        final savedId = saved['marketId'];
        final savedName = saved['marketName'] ?? '';
        if (savedId != null && savedId.isNotEmpty) {
          notifier.setMarket(savedId, savedName);
        }
      }
    }

    // ✅ دائماً للرئيسية — ستعرض البقالات إذا لم يختر
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigation()),
      (route) => false,
    );
  }

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
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _primaryDark.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.vpn_key_outlined,
                    color: _primaryDark,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "أدخل كود الدعوة",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  "تواصل مع الإدارة للحصول على الكود",
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
                const SizedBox(height: 20),
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
                      borderSide: const BorderSide(color: _primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                    onPressed: isChecking
                        ? null
                        : () async {
                            final code = codeCtrl.text.trim().toUpperCase();
                            if (code.isEmpty) return;
                            setSheetState(() => isChecking = true);
                            try {
                              final data = await supabase
                                  .from('invite_codes')
                                  .select()
                                  .eq('code', code)
                                  .eq('is_used', false)
                                  .maybeSingle();
                              if (!ctx.mounted) return;
                              if (data != null) {
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
                                setSheetState(() => isChecking = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text("الكود غير صحيح أو مستخدم"),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(height: 40),

              // ── الشعار ──
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      width: 80,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.store,
                        size: 80,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "تموينات الحي",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "سوق حارتكم في جوالك",
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ── رقم الجوال ──
              const Text(
                "رقم الجوال",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textAlign: TextAlign.right,
                enabled: !_phoneChecked,
                onChanged: (_) {
                  if (_phoneChecked) {
                    setState(() {
                      _phoneChecked = false;
                      _phoneExists = false;
                      _passwordCtrl.clear();
                    });
                  }
                },
                decoration: InputDecoration(
                  hintText: "05XXXXXXXX",
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: _phoneChecked ? Colors.grey[50] : Colors.white,
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
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade100),
                  ),
                  suffixIcon: _phoneChecked
                      ? GestureDetector(
                          onTap: () => setState(() {
                            _phoneChecked = false;
                            _phoneExists = false;
                            _passwordCtrl.clear();
                          }),
                          child: const Icon(
                            Icons.edit_outlined,
                            color: _primaryDark,
                            size: 20,
                          ),
                        )
                      : null,
                ),
              ),

              // ── كلمة المرور ──
              if (_phoneChecked && _phoneExists) ...[
                const SizedBox(height: 16),
                const Text(
                  "كلمة المرور",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: "أدخل كلمة المرور",
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.white,
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
                    prefixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    ),
                    child: const Text(
                      "نسيت كلمة المرور؟",
                      style: TextStyle(color: _primaryDark, fontSize: 13),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── الزر الرئيسي ──
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
                  onPressed: _isLoading
                      ? null
                      : (_phoneChecked && _phoneExists)
                      ? _login
                      : _checkPhone,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          (_phoneChecked && _phoneExists) ? "دخول" : "التالي",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 30),
              Divider(color: Colors.grey[200]),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _showInviteCodeSheet,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _primaryDark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.store_outlined, color: _primaryDark),
                  label: const Text(
                    "تسجيل متجر جديد",
                    style: TextStyle(
                      color: _primaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

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
                    color: _primaryDark.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _primaryDark.withValues(alpha: 0.15),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.store_outlined, color: _primaryDark, size: 18),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "لطلب الانضمام كمتجر تموينات تواصل على الرقم 0552134846",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _primaryDark,
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
      ),
    );
  }
}
