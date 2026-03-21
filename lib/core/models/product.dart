class Product {
  final String id;
  final String name;
  final double price;
  final String? image;
  final String? categoryId; // ✅ ربط بجدول categories

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.image,
    this.categoryId,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      price: (map['price'] as num).toDouble(),
      image: map['image_url'] ?? map['image'],
      categoryId: map['category_id'],
    );
  }
}
