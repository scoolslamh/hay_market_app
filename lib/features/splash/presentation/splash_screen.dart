import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    Timer(const Duration(seconds: 2), _checkAuthAndNavigate);
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;

    try {
      /// 🔥 1. التحقق من الجلسة (Auto Login)
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        _navigateTo(const LoginScreen());
        return;
      }

      /// 🔥 2. استخراج رقم الجوال
      final phone = user.phone ?? user.userMetadata?['phone'];

      if (phone == null || phone.toString().isEmpty) {
        _navigateTo(const LoginScreen());
        return;
      }

      /// 🔥 3. جلب بيانات المستخدم
      final userService = ref.read(userServiceProvider);
      final userData = await userService.getUserByPhone(phone);

      if (!mounted) return;

      /// 🔥 4. الحصول على notifier
      final notifier = ref.read(appStateProvider.notifier);

      /// ✅ حفظ رقم المستخدم (مهم جدًا)
      notifier.setUserPhone(phone);

      /// ✅ المستخدم موجود
      if (userData != null && userData['name'] != null) {
        final String? nId = userData['neighborhood_id']?.toString();
        final String? mId = userData['market_id']?.toString();

        final String nName = userData['neighborhood_name']?.toString() ?? "";
        final String mName = userData['market_name']?.toString() ?? "";

        /// 🔥 5. التحقق من اختيار الحي والمتجر
        if (nId != null && nId.isNotEmpty && mId != null && mId.isNotEmpty) {
          notifier.setNeighborhood(nId, nName);
          notifier.setMarket(mId, mName);

          /// 🔥🔥🔥 تحميل المنتجات
          await notifier.loadInitialData();

          _navigateTo(const MainNavigation());
        } else {
          _navigateTo(const NeighborhoodScreen());
        }
      } else {
        /// مستخدم جديد
        _navigateTo(RegisterScreen(phone: phone));
      }
    } catch (e) {
      debugPrint("Splash Error: $e");

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
              Image.asset(
                "assets/logo.png",
                width: 140,
                errorBuilder: (context, error, stackTrace) {
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
