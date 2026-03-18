import 'package:flutter/material.dart';
import '../models/product.dart';

class CartService extends ChangeNotifier {
  // استخدام الـ Singleton (اختياري مع Riverpod ولكن نتركه كما فضلته أنت)
  static final CartService _instance = CartService._internal();

  factory CartService() {
    return _instance;
  }

  CartService._internal();

  final List<Product> cartItems = [];

  int get count => cartItems.length;

  double get total => cartItems.fold(0, (sum, item) => sum + item.price);

  void addToCart(Product product) {
    cartItems.add(product);
    notifyListeners();
  }

  void removeFromCart(Product product) {
    cartItems.remove(product);
    notifyListeners();
  }

  // ✅ تم تغيير الاسم من clear إلى clearCart ليطابق الاستدعاء في CartScreen
  void clearCart() {
    cartItems.clear();
    notifyListeners();
  }
}
