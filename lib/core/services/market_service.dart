import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/market.dart';

class MarketService {
  final supabase = Supabase.instance.client;

  /// 🔥 جلب البقالات القريبة
  Future<List<Market>> getNearbyMarkets(double userLat, double userLng) async {
    final response = await supabase.from('markets').select();

    final markets = (response as List).map((e) => Market.fromMap(e)).toList();

    markets.sort((a, b) {
      final distA = Geolocator.distanceBetween(userLat, userLng, a.lat, a.lng);

      final distB = Geolocator.distanceBetween(userLat, userLng, b.lat, b.lng);

      return distA.compareTo(distB);
    });

    return markets;
  }
}
