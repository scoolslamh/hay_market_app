import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// استيراد ملف الثيم الجديد
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kcxzsnrqdzgfkbvshsgu.supabase.co',
    anonKey: 'sb_publishable_WepRrjtL2rmjKgrPYDHtjg_Pijn_NTe',
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // تم تحديث الاسم ليتطابق مع الشعار "دكان الحارة"
      title: 'دكان الحارة',
      debugShowCheckedModeBanner: false,

      // استخدام الثيم الاحترافي الجديد بدلاً من ThemeData الافتراضي
      theme: AppTheme.lightTheme,

      /// بداية التطبيق
      home: const SplashScreen(),
    );
  }
}
