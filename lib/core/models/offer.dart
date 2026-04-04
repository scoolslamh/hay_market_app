class Offer {
  final String id;
  final String title;
  final String imageUrl;
  final String? productId;
  final String? productName;
  final double? originalPrice;
  final double? discountedPrice;
  final String marketId;
  final DateTime? startDate;
  final DateTime? endDate;

  Offer({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.marketId,
    this.productId,
    this.productName,
    this.originalPrice,
    this.discountedPrice,
    this.startDate,
    this.endDate,
  });

  double? get discountPercent {
    if (originalPrice == null || discountedPrice == null) return null;
    if (originalPrice! <= 0) return null;
    return ((originalPrice! - discountedPrice!) / originalPrice!) * 100;
  }

  /// هل العرض ساري الآن؟
  bool get isActiveNow {
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  factory Offer.fromMap(Map<String, dynamic> map) {
    return Offer(
      id: map['id'],
      title: map['title'] ?? '',
      imageUrl: map['image_url'] ?? '',
      marketId: map['market_id'] ?? '',
      productId: map['product_id'],
      productName: map['product_name'],
      originalPrice: map['original_price'] != null
          ? (map['original_price'] as num).toDouble()
          : null,
      discountedPrice: map['discounted_price'] != null
          ? (map['discounted_price'] as num).toDouble()
          : null,
      startDate: map['start_date'] != null
          ? DateTime.tryParse(map['start_date'].toString())
          : null,
      endDate: map['end_date'] != null
          ? DateTime.tryParse(map['end_date'].toString())
          : null,
    );
  }
}
