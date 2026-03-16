class OrderModel {
  final String id;
  final String phone;
  final double total;
  final String status;
  final DateTime createdAt;
  final List products;

  OrderModel({
    required this.id,
    required this.phone,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.products,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'],
      phone: map['user_phone'],
      total: (map['total'] as num).toDouble(),
      status: map['status'],
      createdAt: DateTime.parse(map['created_at']),
      products: map['products'] ?? [],
    );
  }
}
