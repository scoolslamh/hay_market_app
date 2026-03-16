class Market {
  final String id;
  final String name;
  final String? image;

  Market({required this.id, required this.name, this.image});

  factory Market.fromMap(Map<String, dynamic> map) {
    return Market(id: map['id'], name: map['name'], image: map['image']);
  }
}
