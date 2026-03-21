class Product {
  final String id;
  final String name;
  final double price;
  final String? image;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.image,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      price: (map['price'] as num).toDouble(),
      // ✅ إصلاح: القاعدة تحفظ الصورة في 'image_url' وليس 'image'
      image: map['image_url'] ?? map['image'],
    );
  }
}
