import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/providers.dart';
import '../../../core/services/auth_storage.dart';

import '../../auth/presentation/login_screen.dart';
import '../../welcome/presentation/welcome_screen.dart';
import '../../../core/navigation/main_navigation.dart'; // ✅ مهم

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

    Timer(const Duration(seconds: 2), goNext);
  }

  Future<void> goNext() async {
    final storage = AuthStorage();

    final phone = await storage.getPhone();
    final selection = await storage.getUserSelection();

    if (!mounted) return;

    /// ❌ غير مسجل دخول
    if (phone == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    /// ✅ حفظ رقم الجوال
    ref.read(appStateProvider.notifier).setUserPhone(phone);

    final neighborhoodId = selection["neighborhoodId"];
    final marketId = selection["marketId"];

    final neighborhoodName = selection["neighborhoodName"];
    final marketName = selection["marketName"];

    /// 🔥 مستخدم مكتمل → دخول للرئيسية (مو الطلبات)
    if (neighborhoodId != null && marketId != null) {
      ref
          .read(appStateProvider.notifier)
          .setNeighborhood(neighborhoodId, neighborhoodName ?? "");

      ref.read(appStateProvider.notifier).setMarket(marketId, marketName ?? "");

      /// ✅ هنا التعديل المهم
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    } else {
      /// 👇 المستخدم جديد أو غير مكتمل
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
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
              /// شعار التطبيق
              Image.asset("assets/logo.png", width: 140),

              const SizedBox(height: 20),

              /// اسم التطبيق
              const Text(
                "تموينات الحي",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),

              const SizedBox(height: 8),

              /// وصف التطبيق
              const Text(
                "سوق حيك في هاتفك",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
