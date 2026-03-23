class Market {
  final String id;
  final String name;
  final String? image;
  final double lat;
  final double lng;

  Market({
    required this.id,
    required this.name,
    this.image,
    required this.lat,
    required this.lng,
  });

  factory Market.fromMap(Map<String, dynamic> map) {
    return Market(
      id: map['id'].toString(),
      name: (map['name'] ?? "بدون اسم").toString(),
      image: map['store_image_url'] ?? map['image'],
      lat: (map['lat'] as num).toDouble(), // 🔥 مهم
      lng: (map['lng'] as num).toDouble(), // 🔥 مهم
    );
  }
}
