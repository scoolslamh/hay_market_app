import 'package:supabase_flutter/supabase_flutter.dart';

class NeighborhoodService {
  final supabase = Supabase.instance.client;

  Future<String?> getNeighborhoodName(String id) async {
    final response = await supabase
        .from('neighborhoods')
        .select('name')
        .eq('id', id)
        .single();

    return response['name'];
  }
}
