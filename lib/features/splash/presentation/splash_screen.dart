import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/providers.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/register_screen.dart';
import '../../location/presentation/neighborhood_screen.dart';
import '../../../core/navigation/main_navigation.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> scaleAnimation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));

    controller.forward();

    // تأخير لمدة ثانيتين لعرض الشعار ثم بدء التحقق
    Timer(const Duration(seconds: 2), _checkAuthAndNavigate);
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;

    // 1. جلب رقم الجوال من الحالة المحلية (AppState)
    final phone = ref.read(appStateProvider).userPhone;

    if (phone == null || phone.isEmpty) {
      _navigateTo(const LoginScreen());
      return;
    }

    try {
      final userService = ref.read(userServiceProvider);
      final userData = await userService.getUserByPhone(phone);

      if (!mounted) return;

      // ✅ حالة: المستخدم موجود في قاعدة البيانات
      if (userData != null && userData['name'] != null) {
        // استخراج المعرفات (تأكد من مطابقة مسميات الأعمدة في Supabase)
        final String? nId = userData['neighborhood_id']?.toString();
        final String? mId = userData['market_id']?.toString();

        // استخراج الأسماء للعرض
        final String nName =
            userData['neighborhood_name']?.toString() ??
            userData['neighborhood']?.toString() ??
            "";
        final String mName = userData['market_name']?.toString() ?? "";

        // 🛑 التحقق الجوهري: هل لديه حي ومتجر مختاران؟
        if (nId != null && nId.isNotEmpty && mId != null && mId.isNotEmpty) {
          // تحديث الحالة المحلية فوراً قبل الانتقال
          final notifier = ref.read(appStateProvider.notifier);
          notifier.setNeighborhood(nId, nName);
          notifier.setMarket(mId, mName);

          _navigateTo(const MainNavigation());
        } else {
          // مسجل بياناته لكنه لم يكمل اختيار الموقع/المتجر
          _navigateTo(const NeighborhoodScreen());
        }
      } else {
        // الرقم موجود محلياً لكن لا يوجد سجل في Supabase (مستخدم جديد)
        _navigateTo(RegisterScreen(phone: phone));
      }
    } catch (e) {
      debugPrint("Splash Error: $e");
      // في حال خطأ الشبكة، نعود للأمان (شاشة تسجيل الدخول)
      _navigateTo(const LoginScreen());
    }
  }

  void _navigateTo(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ScaleTransition(
          scale: scaleAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ تم إزالة كلمة const من هنا لأن errorBuilder دالة ديناميكية لا يمكن جعلها ثابتة
              Image.asset(
                "assets/logo.png",
                width: 140,
                errorBuilder: (context, error, stackTrace) {
                  // ✅ تم تغيير المسمى من shopping_store إلى store لأن الأخير هو الصحيح في Material Icons
                  return const Icon(Icons.store, size: 80, color: Colors.green);
                },
              ),
              const SizedBox(height: 20),
              const Text(
                "تموينات الحي",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "سوق حيك في هاتفك",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
