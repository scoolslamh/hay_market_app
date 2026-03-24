import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

import 'core/theme/app_theme.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/auth/presentation/reset_password_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kcxzsnrqdzgfkbvshsgu.supabase.co',
    anonKey: 'sb_publishable_WepRrjtL2rmjKgrPYDHtjg_Pijn_NTe',
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;
  StreamSubscription? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initDeepLinks() async {
    _appLinks = AppLinks();

    // ✅ استقبال الروابط عند فتح التطبيق من رابط
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleLink(initialLink);
      }
    } catch (e) {
      debugPrint("Initial link error: $e");
    }

    // ✅ استقبال الروابط أثناء تشغيل التطبيق
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleLink(uri);
      },
      onError: (e) {
        debugPrint("Link stream error: $e");
      },
    );
  }

  void _handleLink(Uri uri) {
    debugPrint("🔗 Deep link received: $uri");

    // ✅ رابط استعادة كلمة المرور
    if (uri.toString().contains('reset-password') ||
        uri.toString().contains('type=recovery')) {
      // Supabase يتعامل مع الـ token تلقائياً
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دكان الحارة',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
