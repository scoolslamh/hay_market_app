import 'package:flutter/material.dart';
import '../models/product.dart';

class CartService extends ChangeNotifier {
  // Singleton
  static final CartService _instance = CartService._internal();

  // ✅ إضافة instance للوصول المباشر
  static CartService get instance => _instance;

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

  void clearCart() {
    cartItems.clear();
    notifyListeners();
  }
}
