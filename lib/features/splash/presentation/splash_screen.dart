import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/providers.dart';
import '../../../core/services/auth_storage.dart';

import '../../auth/presentation/login_screen.dart';
import '../../welcome/presentation/welcome_screen.dart';

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

    if (!mounted) return;

    /// المستخدم غير مسجل دخول
    if (phone == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
    /// المستخدم مسجل دخول
    else {
      /// حفظ الرقم في Riverpod
      ref.read(appStateProvider.notifier).setUserPhone(phone);

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
