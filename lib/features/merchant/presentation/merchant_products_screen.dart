import 'package:flutter/material.dart';
import '../../../core/utils/app_notification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_storage.dart';
import 'add_product_screen.dart';
import 'warehouse_screen.dart';

class MerchantProductsScreen extends StatefulWidget {
  const MerchantProductsScreen({super.key});

  @override
  State<MerchantProductsScreen> createState() => _MerchantProductsScreenState();
}

class _MerchantProductsScreenState extends State<MerchantProductsScreen> {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> products = [];
  bool isLoading = true;
  String? marketId;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      setState(() => isLoading = true);
      final phone = await AuthStorage().getPhone();
      if (phone == null) {
        setState(() => isLoading = false);
        return;
      }

      final market = await supabase
          .from('markets')
          .select()
          .eq('owner_phone', phone)
          .maybeSingle();
      if (market == null) {
        setState(() => isLoading = false);
        return;
      }

      marketId = market['id'];

      final data = await supabase
          .from('products')
          .select()
          .eq('market_id', marketId!)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          products = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Load products error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ✅ تأكيد قبل الحذف
  Future<void> _deleteProduct(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("تأكيد الحذف"),
        content: Text(
          "هل تريد حذف \"$name\"؟\nلا يمكن التراجع عن هذا الإجراء.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "حذف",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('products').delete().eq('id', id);
      if (!mounted) return;
      setState(() => products.removeWhere((p) => p['id'].toString() == id));
      AppNotification.error(context, "تم حذف المنتج");
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  // ✅ تحديث المخزون
  Future<void> _updateStock(String id, int currentStock, int delta) async {
    final newStock = (currentStock + delta).clamp(0, 9999);
    try {
      await supabase.from('products').update({'stock': newStock}).eq('id', id);
      if (!mounted) return;
      setState(() {
        final idx = products.indexWhere((p) => p['id'] == id);
        if (idx >= 0) products[idx]['stock'] = newStock;
      });
    } catch (e) {
      debugPrint("Stock update error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "المنتجات (${products.length})",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        actions: [
          // زر المستودع
          IconButton(
            icon: const Icon(Icons.warehouse_outlined, color: _primaryDark),
            tooltip: "المستودع",
            onPressed: () async {
              if (marketId == null) return;
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WarehouseScreen(marketId: marketId),
                ),
              );
              _loadProducts();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryDark,
        onPressed: () async {
          if (marketId == null) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddProductScreen(marketId: marketId!),
            ),
          );
          _loadProducts();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        color: _primary,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : products.isEmpty
            ? _buildEmpty()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _buildProductCard(products[i]),
              ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
    final stock = p['stock'] ?? 0;
    final isOutOfStock = stock == 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // أزرار + حذف
            Column(
              children: [
                // حذف
                GestureDetector(
                  onTap: () =>
                      _deleteProduct(p['id'].toString(), p['name'] ?? ''),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // تعديل
                GestureDetector(
                  onTap: () async {
                    if (marketId == null) return;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AddProductScreen(marketId: marketId!, product: p),
                      ),
                    );
                    _loadProducts();
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: Colors.blue,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 12),

            // الصورة
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 70,
                height: 70,
                color: const Color(0xFFF8F8F8),
                child: Stack(
                  children: [
                    p['image_url'] != null &&
                            p['image_url'].toString().isNotEmpty
                        ? Image.network(
                            p['image_url'],
                            fit: BoxFit.cover,
                            width: 70,
                            height: 70,
                          )
                        : const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey,
                            size: 32,
                          ),
                    // علامة نفاد المخزون
                    if (isOutOfStock)
                      Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: const Text(
                          "نفذ",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12),

            // الاسم والسعر
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    p['name'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${p['price'] ?? 0} ﷼",
                    style: const TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ✅ التحكم في المخزون
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // رقم المخزون
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isOutOfStock
                              ? Colors.red.withValues(alpha: 0.1)
                              : _primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "مخزون: $stock",
                          style: TextStyle(
                            color: isOutOfStock ? Colors.red : _primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // أزرار + و -
                      _buildStockButton(
                        Icons.remove,
                        () => _updateStock(p['id'], stock, -1),
                      ),
                      const SizedBox(width: 4),
                      _buildStockButton(
                        Icons.add,
                        () => _updateStock(p['id'], stock, 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _primaryDark.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: _primaryDark),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            "لا توجد منتجات",
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            "اضغط + لإضافة منتج أو ابحث في المستودع",
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }
}
