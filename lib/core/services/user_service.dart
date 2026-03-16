import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final supabase = Supabase.instance.client;

  Future<bool> userExists(String phone) async {
    final data = await supabase
        .from('users')
        .select()
        .eq('phone', phone)
        .maybeSingle();

    return data != null;
  }
}
