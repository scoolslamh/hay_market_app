import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_state.dart';
import 'app_state_notifier.dart';
import '../services/user_service.dart';
import '../services/cart_service.dart'; // ✅ تأكد من إضافة هذا الاستيراد

// 1. مزود خدمة المستخدم
final userServiceProvider = Provider((ref) => UserService());

// 2. مزود حالة التطبيق (رقم الهاتف، الحي، المتجر)
final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((
  ref,
) {
  return AppStateNotifier();
});

// 3. ✅ مزود السلة (هذا هو السطر الناقص الذي يسبب الخطأ في شاشة السلة)
// استخدمنا ChangeNotifierProvider لأن CartService يستخدم notifyListeners()
final cartServiceProvider = ChangeNotifierProvider((ref) => CartService());
