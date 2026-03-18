import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'app_state_notifier.dart';
import '../services/user_service.dart';
import '../services/cart_service.dart';

/// 🔹 Supabase Provider
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// 🔹 User Service Provider
final userServiceProvider = Provider<UserService>((ref) {
  final supabase = ref.read(supabaseProvider);

  return UserService(supabase: supabase);
});

/// 🔹 App State Provider
final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((
  ref,
) {
  final supabase = ref.read(supabaseProvider);

  return AppStateNotifier(supabase: supabase);
});

/// 🔹 Cart Provider
final cartServiceProvider = ChangeNotifierProvider<CartService>((ref) {
  return CartService();
});
