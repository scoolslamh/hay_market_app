import 'package:supabase_flutter/supabase_flutter.dart';

class ProductService {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getProducts(String marketId) async {
    final response = await supabase
        .from('products')
        .select()
        .eq('market_id', marketId)
        // ✅ إخفاء المنتجات النافدة (stock = 0)
        // stock is null = منتج قديم قبل إضافة المخزون → يظهر
        // stock > 0 = منتج متوفر → يظهر
        // stock = 0 = نفذ المخزون → يختفي
        .or('stock.gt.0,stock.is.null')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}
