import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WarehouseScreen extends StatefulWidget {
  final String? marketId;
  const WarehouseScreen({super.key, this.marketId});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  final supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> allItems = [];
  List<Map<String, dynamic>> filteredItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWarehouse();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouse() async {
    try {
      setState(() => isLoading = true);
      final data = await supabase
          .from('warehouse')
          .select()
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          allItems = List<Map<String, dynamic>>.from(data);
          filteredItems = allItems;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Warehouse error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _search(String query) {
    setState(() {
      filteredItems = query.isEmpty
          ? allItems
          : allItems
                .where(
                  (item) => (item['name'] ?? '').toLowerCase().contains(
                    query.toLowerCase(),
                  ),
                )
                .toList();
    });
  }

  // إضافة منتج من المستودع للمتجر
  void _addToMarket(Map<String, dynamic> item) {
    if (widget.marketId == null) return;

    final priceController = TextEditingController();
    final stockController = TextEditingController(text: '10');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "إضافة \"${item['name']}\" لمتجرك",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // السعر
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: "السعر ﷼",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // المخزون
            TextField(
              controller: stockController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: "الكمية في المخزون",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  final price = double.tryParse(priceController.text.trim());
                  final stock = int.tryParse(stockController.text.trim()) ?? 0;

                  if (price == null || price <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("أدخل سعراً صحيحاً")),
                    );
                    return;
                  }

                  try {
                    await supabase.from('products').insert({
                      'name': item['name'],
                      'price': price,
                      'market_id': widget.marketId,
                      'image_url': item['image_url'] ?? '',
                      'category_id': item['category_id'],
                      'stock': stock,
                    });

                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("✅ تمت إضافة \"${item['name']}\" لمتجرك"),
                        backgroundColor: _primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("خطأ: $e")));
                  }
                },
                child: const Text(
                  "إضافة للمتجر",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // إضافة منتج جديد للمستودع
  void _addToWarehouse() {
    final nameController = TextEditingController();
    final imageController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "إضافة منتج للمستودع",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: "اسم المنتج",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: imageController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: "رابط الصورة (اختياري)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  try {
                    await supabase.from('warehouse').insert({
                      'name': name,
                      'image_url': imageController.text.trim(),
                    });
                    if (!mounted) return;
                    Navigator.pop(context);
                    _loadWarehouse();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("خطأ: $e")));
                  }
                },
                child: const Text(
                  "حفظ في المستودع",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
          "المستودع (${allItems.length})",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryDark,
        onPressed: _addToWarehouse,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // شريط البحث
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              textAlign: TextAlign.right,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: "ابحث عن منتج...",
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          _search('');
                        },
                        child: const Icon(Icons.close, size: 18),
                      )
                    : null,
                suffixIcon: Container(
                  margin: const EdgeInsets.all(6),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),

          // القائمة
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "لا توجد نتائج",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _buildWarehouseItem(filteredItems[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseItem(Map<String, dynamic> item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 52,
            height: 52,
            color: const Color(0xFFF0F0F0),
            child:
                item['image_url'] != null &&
                    item['image_url'].toString().isNotEmpty
                ? Image.network(item['image_url'], fit: BoxFit.cover)
                : const Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.grey,
                    size: 26,
                  ),
          ),
        ),
        title: Text(
          item['name'] ?? '',
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        trailing: widget.marketId != null
            ? GestureDetector(
                onTap: () => _addToMarket(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _primaryDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "إضافة لمتجري",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
