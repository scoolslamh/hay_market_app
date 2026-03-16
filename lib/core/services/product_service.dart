import 'package:supabase_flutter/supabase_flutter.dart';

class ProductService {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getProducts(String marketId) async {
    final response = await supabase
        .from('products')
        .select()
        .eq('market_id', marketId);

    return List<Map<String, dynamic>>.from(response);
  }
}
