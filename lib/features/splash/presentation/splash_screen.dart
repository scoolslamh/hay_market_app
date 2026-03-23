import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/state/providers.dart';
import '../../../core/services/auth_storage.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/register_screen.dart';
import '../../location/presentation/neighborhood_screen.dart';
import '../../../core/navigation/main_navigation.dart';
import '../../merchant/presentation/merchant_home_screen.dart';
import '../../merchant/presentation/merchant_pending_screen.dart';
import '../../admin/presentation/admin_home_screen.dart';

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
    debugPrint("🔥 SPLASH STARTED 🔥");
    if (!mounted) return;

    try {
      final phone = await AuthStorage().getPhone();
      debugPrint("PHONE: $phone");

      if (phone == null || phone.isEmpty) {
        _navigateTo(const LoginScreen());
        return;
      }

      // ══════════════════════════════════════
      // 1️⃣ هل هو مدير؟
      // ══════════════════════════════════════
      final adminCheck = await Supabase.instance.client
          .from('admins')
          .select()
          .eq('phone', phone)
          .maybeSingle();

      if (adminCheck != null) {
        debugPrint("✅ ADMIN");
        _navigateTo(const AdminHomeScreen());
        return;
      }

      // ══════════════════════════════════════
      // 2️⃣ هل هو تاجر؟
      // ══════════════════════════════════════
      final marketCheck = await Supabase.instance.client
          .from('markets')
          .select()
          .eq('owner_phone', phone)
          .maybeSingle();

      debugPrint("MARKET CHECK: $marketCheck");

      if (marketCheck != null) {
        final marketStatus = marketCheck['status'] ?? 'pending';
        switch (marketStatus) {
          case 'active':
            _navigateTo(const MerchantHomeScreen());
            return;
          case 'pending':
          case 'rejected':
            _navigateTo(const MerchantPendingScreen());
            return;
          case 'frozen':
            _navigateTo(const MerchantPendingScreen());
            return;
        }
      }

      // ══════════════════════════════════════
      // 3️⃣ عميل عادي
      // ══════════════════════════════════════
      final userData = await Supabase.instance.client
          .from('users')
          .select()
          .eq('phone', phone)
          .maybeSingle();

      debugPrint("USER DATA: $userData");

      if (!mounted) return;

      final notifier = ref.read(appStateProvider.notifier);
      notifier.setUserPhone(phone);

      if (userData == null) {
        _navigateTo(RegisterScreen(phone: phone));
        return;
      }

      final String? nId = userData['neighborhood_id']?.toString();
      final String? mId = userData['market_id']?.toString();
      final String nName = userData['neighborhood_name']?.toString() ?? "";
      final String mName = userData['market_name']?.toString() ?? "";

      if (nId != null && nId.isNotEmpty && mId != null && mId.isNotEmpty) {
        notifier.setNeighborhood(nId, nName);
        notifier.setMarket(mId, mName);
        await notifier.loadInitialData();
      }

      // ✅ يذهب دائماً للرئيسية — ستعرض البقالات القريبة إذا لم يختر
      _navigateTo(const MainNavigation());
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
                width: 130,
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
                "سوق حارتكم في جوالك",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
