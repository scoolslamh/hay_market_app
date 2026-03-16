import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/cart_service.dart';
import '../../../core/models/product.dart';
import '../../../core/services/order_service.dart';
import '../../../core/state/providers.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final CartService cartService = CartService();
  final OrderService orderService = OrderService();

  bool isSending = false;

  Future<void> sendOrder() async {
    if (cartService.cartItems.isEmpty) return;

    final appState = ref.read(appStateProvider);

    final phone = appState.userPhone;
    final marketId = appState.marketId;

    if (phone == null || marketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("بيانات المستخدم غير مكتملة")),
      );

      return;
    }

    try {
      setState(() {
        isSending = true;
      });

      await orderService.createOrder(phone: phone, marketId: marketId);

      cartService.cartItems.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("تم إرسال الطلب بنجاح")));

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("حدث خطأ أثناء إرسال الطلب: $e")));
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("السلة")),

      body: AnimatedBuilder(
        animation: cartService,

        builder: (context, _) {
          final List<Product> items = cartService.cartItems;

          if (items.isEmpty) {
            return const Center(child: Text("السلة فارغة"));
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,

                  itemBuilder: (context, index) {
                    final product = items[index];

                    return ListTile(
                      title: Text(product.name),

                      subtitle: Text("${product.price} ريال"),

                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          cartService.removeFromCart(product);
                        },
                      ),
                    );
                  },
                ),
              ),

              Container(
                padding: const EdgeInsets.all(20),

                child: Column(
                  children: [
                    Text(
                      "المجموع: ${cartService.total} ريال",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,

                      child: ElevatedButton(
                        onPressed: isSending ? null : sendOrder,

                        child: isSending
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("إرسال الطلب"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
