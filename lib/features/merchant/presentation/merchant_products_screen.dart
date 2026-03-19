import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_storage.dart';
import 'add_product_screen.dart';

class MerchantProductsScreen extends StatefulWidget {
  const MerchantProductsScreen({super.key});

  @override
  State<MerchantProductsScreen> createState() => _MerchantProductsScreenState();
}

class _MerchantProductsScreenState extends State<MerchantProductsScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> products = [];
  bool isLoading = true;

  String? marketId;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  /// 🔥 تحميل المنتجات
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

      if (marketId == null) {
        setState(() => isLoading = false);
        return;
      }

      final data = await supabase
          .from('products')
          .select()
          .eq('market_id', marketId!)
          .order('created_at', ascending: false);

      setState(() {
        products = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Load products error: $e");
      setState(() => isLoading = false);
    }
  }

  /// 🗑 حذف منتج
  Future<void> _deleteProduct(String id) async {
    try {
      await supabase.from('products').delete().eq('id', id);

      setState(() {
        products.removeWhere((p) => p['id'].toString() == id);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("تم حذف المنتج")));
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("منتجاتي"),
        backgroundColor: Colors.green,
      ),

      /// ➕ إضافة
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (marketId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("لم يتم العثور على المتجر")),
            );
            return;
          }

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddProductScreen(marketId: marketId!),
            ),
          );

          _loadProducts();
        },
        child: const Icon(Icons.add),
      ),

      /// 🔄 تحديث بالسحب
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : products.isEmpty
            ? const Center(child: Text("لا توجد منتجات"))
            : ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: products.length,
                itemBuilder: (context, i) {
                  final p = products[i];

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(10),

                      /// 🖼️ صورة المنتج
                      leading:
                          p['image_url'] != null &&
                              p['image_url'].toString().isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                p['image_url'],
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.image, size: 40),

                      /// 📝 الاسم
                      title: Text(
                        p['name']?.toString() ?? "",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      /// 💰 السعر
                      subtitle: Text("${p['price']?.toString() ?? "0"} ريال"),

                      /// ✏️ + 🗑
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          /// ✏️ تعديل
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () async {
                              if (marketId == null) return;

                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddProductScreen(
                                    marketId: marketId!,
                                    product: p,
                                  ),
                                ),
                              );

                              _loadProducts();
                            },
                          ),

                          /// 🗑 حذف
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteProduct(p['id'].toString()),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
