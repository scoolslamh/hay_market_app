import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/offer.dart';

class OfferService {
  final supabase = Supabase.instance.client;

  Future<List<Offer>> getOffers(String marketId) async {
    try {
      final now = DateTime.now().toIso8601String();

      final data = await supabase
          .from('offers')
          .select('*')
          .eq('market_id', marketId)
          .eq('is_active', true)
          .or('start_date.is.null,start_date.lte.$now')
          .or('end_date.is.null,end_date.gte.$now')
          .order('created_at', ascending: false);

      debugPrint('OfferService.getOffers: ${data.length} offers for $marketId');

      return List<Map<String, dynamic>>.from(data)
          .map((e) => Offer.fromMap(e))
          .toList();
    } catch (e) {
      debugPrint('OfferService.getOffers error: $e');
      // إرجاع قائمة فارغة بدل رمي exception حتى لا تفشل الصفحة
      return [];
    }
  }

  Future<void> addOffer({
    required String marketId,
    required String title,
    required String imageUrl,
    String? productId,
    String? productName,
    double? originalPrice,
    double? discountedPrice,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await supabase.from('offers').insert({
      'market_id': marketId,
      'title': title,
      'image_url': imageUrl,
      'product_id': productId,
      'product_name': productName,
      'original_price': originalPrice,
      'discounted_price': discountedPrice,
      'is_active': true,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
    });
  }

  /// حذف العرض — يرجع true عند النجاح
  Future<bool> deleteOffer(String offerId) async {
    try {
      await supabase.from('offers').delete().eq('id', offerId);
      // تحقق أن السجل فعلاً حُذف
      final check = await supabase
          .from('offers')
          .select('id')
          .eq('id', offerId)
          .maybeSingle();
      return check == null; // null يعني تم الحذف
    } catch (e) {
      debugPrint('OfferService.deleteOffer error: $e');
      return false;
    }
  }

  Future<void> toggleOffer(String offerId, bool isActive) async {
    await supabase
        .from('offers')
        .update({'is_active': isActive})
        .eq('id', offerId);
  }
}
