import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/market.dart';

class MarketService {
  final supabase = Supabase.instance.client;

  Future<List<Market>> getMarketsByNeighborhood(String neighborhoodId) async {
    final response = await supabase
        .from('markets')
        .select()
        .eq('neighborhood_id', neighborhoodId);

    return (response as List).map((market) => Market.fromMap(market)).toList();
  }
}
