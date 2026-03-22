class OrderModel {
  final String id;
  final String phone;
  final double total;
  final String status;
  final DateTime createdAt;
  final List products;
  final String? paymentMethod; // ✅ طريقة الدفع

  OrderModel({
    required this.id,
    required this.phone,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.products,
    this.paymentMethod,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'].toString(),
      phone: map['phone'] ?? '',
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'new',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      products: map['products'] as List? ?? [],
      paymentMethod: map['payment_method'],
    );
  }
}
