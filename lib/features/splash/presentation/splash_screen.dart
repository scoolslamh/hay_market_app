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
      /// 📱 1. جلب رقم الجوال
      final phone = await AuthStorage().getPhone();

      if (phone == null || phone.isEmpty) {
        _navigateTo(const LoginScreen());
        return;
      }

      /// 🔥 2. التحقق من التاجر أولاً
      final marketCheck = await Supabase.instance.client
          .from('markets')
          .select()
          .eq('owner_phone', phone);

      if (marketCheck.isNotEmpty) {
        _navigateTo(const MerchantHomeScreen());
        return;
      }

      /// 👤 3. التحقق من المستخدم
      final userData = await Supabase.instance.client
          .from('users')
          .select()
          .eq('phone', phone)
          .maybeSingle();

      if (!mounted) return;

      final notifier = ref.read(appStateProvider.notifier);
      notifier.setUserPhone(phone);

      /// ❗ مستخدم جديد
      if (userData == null) {
        _navigateTo(RegisterScreen(phone: phone));
        return;
      }

      /// 📍 الخطوة الأهم: قراءة الحي والمتجر من AuthStorage المحلي أولاً
      final savedSelection = await AuthStorage().getUserSelection();

      final String? localNId = savedSelection['neighborhoodId'];
      final String? localMId = savedSelection['marketId'];
      final String? localNName = savedSelection['neighborhoodName'];
      final String? localMName = savedSelection['marketName'];

      /// 📍 ثم من Supabase كـ fallback
      final String? remoteNId = userData['neighborhood_id']?.toString();
      final String? remoteMId = userData['market_id']?.toString();
      final String? remoteNName = userData['neighborhood_name']?.toString();
      final String? remoteMName = userData['market_name']?.toString();

      /// ✅ الأولوية: المحلي أولاً، ثم السيرفر
      final String? finalNId = (localNId != null && localNId.isNotEmpty)
          ? localNId
          : remoteNId;
      final String? finalMId = (localMId != null && localMId.isNotEmpty)
          ? localMId
          : remoteMId;
      final String finalNName = (localNName != null && localNName.isNotEmpty)
          ? localNName
          : (remoteNName ?? "");
      final String finalMName = (localMName != null && localMName.isNotEmpty)
          ? localMName
          : (remoteMName ?? "");

      /// ✅ إذا مكتمل → ادخل مباشرة
      if (finalNId != null &&
          finalNId.isNotEmpty &&
          finalMId != null &&
          finalMId.isNotEmpty) {
        notifier.setNeighborhood(finalNId, finalNName);
        notifier.setMarket(finalMId, finalMName);

        await notifier.loadInitialData();

        _navigateTo(const MainNavigation());
      } else {
        /// ❗ لم يختر بعد → اذهب لاختيار الحي
        _navigateTo(const NeighborhoodScreen());
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
