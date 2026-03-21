import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

/// نموذج عنصر السلة مع الكمية
class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get subtotal => product.price * quantity;

  /// تحويل لـ JSON للحفظ المحلي
  Map<String, dynamic> toJson() => {
    'id': product.id,
    'name': product.name,
    'price': product.price,
    'image': product.image,
    'categoryId': product.categoryId,
    'quantity': quantity,
  };

  /// استرجاع من JSON
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product(
        id: json['id'],
        name: json['name'],
        price: (json['price'] as num).toDouble(),
        image: json['image'],
        categoryId: json['categoryId'],
      ),
      quantity: json['quantity'] ?? 1,
    );
  }
}

class CartService extends ChangeNotifier {
  // Singleton
  static final CartService _instance = CartService._internal();
  static CartService get instance => _instance;

  factory CartService() => _instance;
  CartService._internal() {
    _loadFromStorage(); // ✅ استرجاع السلة عند بدء التطبيق
  }

  static const String _storageKey = 'cart_items';

  final List<CartItem> _items = [];

  /// قائمة العناصر للقراءة فقط
  List<CartItem> get items => List.unmodifiable(_items);

  /// عدد العناصر الفريدة
  int get count => _items.length;

  /// إجمالي الكميات
  int get totalQuantity => _items.fold(0, (sum, item) => sum + item.quantity);

  /// الإجمالي المالي
  double get total => _items.fold(0, (sum, item) => sum + item.subtotal);

  /// للتوافق مع الكود القديم
  List<Product> get cartItems => _items.map((e) => e.product).toList();

  // ══════════════════════════════════════
  // العمليات
  // ══════════════════════════════════════

  /// إضافة منتج — إذا موجود يزيد الكمية
  void addToCart(Product product) {
    final index = _items.indexWhere((e) => e.product.id == product.id);
    if (index >= 0) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(product: product));
    }
    notifyListeners();
    _saveToStorage();
  }

  /// زيادة كمية منتج
  void increaseQty(String productId) {
    final index = _items.indexWhere((e) => e.product.id == productId);
    if (index >= 0) {
      _items[index].quantity++;
      notifyListeners();
      _saveToStorage();
    }
  }

  /// تقليل كمية منتج — إذا وصلت 0 يُحذف
  void decreaseQty(String productId) {
    final index = _items.indexWhere((e) => e.product.id == productId);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
      _saveToStorage();
    }
  }

  /// حذف منتج بالكامل
  void removeFromCart(Product product) {
    _items.removeWhere((e) => e.product.id == product.id);
    notifyListeners();
    _saveToStorage();
  }

  /// تفريغ السلة
  void clearCart() {
    _items.clear();
    notifyListeners();
    _saveToStorage();
  }

  // ══════════════════════════════════════
  // الحفظ والاسترجاع
  // ══════════════════════════════════════

  /// حفظ السلة في SharedPreferences
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _items.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Cart save error: $e');
    }
  }

  /// استرجاع السلة من SharedPreferences
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        _items.clear();
        _items.addAll(jsonList.map((e) => CartItem.fromJson(e)));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Cart load error: $e');
    }
  }
}
