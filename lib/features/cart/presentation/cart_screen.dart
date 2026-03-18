import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/order_service.dart';
import '../../../core/state/providers.dart';
import '../../../core/models/product.dart';
import '../../../core/services/cart_service.dart'; // ✅ تأكد من الاستيراد

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final OrderService orderService = OrderService();
  bool isSending = false;

  Future<void> sendOrder() async {
    final cartService = ref.read(cartServiceProvider);

    if (cartService.cartItems.isEmpty) return;

    final appState = ref.read(appStateProvider);
    final phone = appState.userPhone;
    final marketId = appState.marketId;

    if (phone == null || marketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("بيانات المستخدم أو المتجر غير مكتملة")),
      );
      return;
    }

    try {
      setState(() => isSending = true);

      // إرسال الطلب لـ Supabase
      await orderService.createOrder(marketId: marketId);

      // ✅ استدعاء الدالة بعد تعريفها في ملف الخدمة
      cartService.clearCart();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚀 تم إرسال طلبك لـ دكان الحي بنجاح!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("حدث خطأ أثناء إرسال الطلب: $e")));
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartService = ref.watch(cartServiceProvider);
    final items = cartService.cartItems;

    return Scaffold(
      appBar: AppBar(title: const Text("سلة المشتريات"), centerTitle: true),
      body: items.isEmpty
          ? _buildEmptyCart()
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final product = items[index];
                      return _buildCartItem(product, cartService);
                    },
                  ),
                ),
                _buildOrderSummary(cartService),
              ],
            ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_basket_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            "سلتك فارغة.. ابدأ التسوق الآن",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Product product, CartService cartService) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: product.image != null && product.image!.isNotEmpty
            ? Image.network(
                product.image!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              )
            : const Icon(Icons.image),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("${product.price} ريال"),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => cartService.removeFromCart(product),
        ),
      ),
    );
  }

  Widget _buildOrderSummary(CartService cartService) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("إجمالي المبلغ:", style: TextStyle(fontSize: 18)),
                Text(
                  "${cartService.total} ريال",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isSending ? null : sendOrder,
                child: isSending
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "تأكيد وإرسال الطلب",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
