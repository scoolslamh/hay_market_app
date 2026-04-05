import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/utils/app_notification.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddProductScreen extends StatefulWidget {
  final String marketId;
  final Map<String, dynamic>? product;

  const AddProductScreen({super.key, required this.marketId, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  final supabase = Supabase.instance.client;
  final nameController = TextEditingController();
  final priceController = TextEditingController();

  File? imageFile;
  String? imageUrl;
  bool isLoading = false;
  bool isUploadingImage = false;

  // ✅ الأقسام
  List<Map<String, dynamic>> categories = [];
  String? selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.product != null) {
      nameController.text = widget.product!['name'] ?? '';
      priceController.text = widget.product!['price']?.toString() ?? '';
      imageUrl = widget.product!['image_url'];
      selectedCategoryId = widget.product!['category_id'];
    }
  }

  Future<void> _loadCategories() async {
    try {
      final data = await supabase
          .from('categories')
          .select()
          .order('sort_order', ascending: true);
      if (mounted) {
        setState(() => categories = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      debugPrint("Load categories error: $e");
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    super.dispose();
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            const Text("اختر مصدر الصورة",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _sourceButton(
                  icon: Icons.camera_alt_outlined,
                  label: "الكاميرا",
                  onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
                )),
                const SizedBox(width: 12),
                Expanded(child: _sourceButton(
                  icon: Icons.photo_library_outlined,
                  label: "المعرض",
                  onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
                )),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sourceButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF004D40), size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 800,
      );
      if (picked != null) setState(() => imageFile = File(picked.path));
    } catch (e) {
      debugPrint("Pick image error: $e");
    }
  }

  Future<String?> uploadImage() async {
    if (imageFile == null) return imageUrl;

    setState(() => isUploadingImage = true);

    try {
      final fileName = "product_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final path = "${widget.marketId}/$fileName";
      final bytes = await imageFile!.readAsBytes();

      // ✅ uploadBinary أكثر استقراراً
      await supabase.storage
          .from('products')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final publicUrl = supabase.storage.from('products').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint("Upload error: $e");
      if (mounted) {
        AppNotification.warning(context, "فشل رفع الصورة — سيتم الحفظ بدونها");
      }
      // ✅ لا نخرج — نرجع الصورة القديمة
      return imageUrl;
    } finally {
      if (mounted) setState(() => isUploadingImage = false);
    }
  }

  Future<void> saveProduct() async {
    final name = nameController.text.trim();
    final price = double.tryParse(priceController.text.trim());

    if (name.isEmpty || price == null || price <= 0) {
      AppNotification.warning(context, "تأكد من إدخال الاسم والسعر بشكل صحيح");
      return;
    }

    setState(() => isLoading = true);

    try {
      final uploadedImage = await uploadImage();
      final imageToSave = uploadedImage ?? '';

      if (widget.product == null) {
        await supabase.from('products').insert({
          "name": name,
          "price": price,
          "market_id": widget.marketId,
          "image_url": imageToSave,
          "stock": 10,
          "category_id": selectedCategoryId,
        });
      } else {
        await supabase
            .from('products')
            .update({
              "name": name,
              "price": price,
              "image_url": imageToSave,
              "category_id": selectedCategoryId,
            })
            .eq('id', widget.product!['id']);
      }

      if (!mounted) return;

      AppNotification.success(
        context,
        widget.product == null ? "✅ تمت إضافة المنتج" : "✅ تم تحديث المنتج",
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint("Save error: $e");
      if (!mounted) return;
      AppNotification.error(context, "حدث خطأ: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isEdit ? "تعديل المنتج" : "إضافة منتج",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── الصورة ──
          GestureDetector(
            onTap: isLoading ? null : _showImageSourceSheet,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      imageFile != null ||
                          (imageUrl != null && imageUrl!.isNotEmpty)
                      ? _primary
                      : Colors.grey.shade200,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: isUploadingImage
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 10),
                            Text("جاري رفع الصورة..."),
                          ],
                        ),
                      )
                    : imageFile != null
                    ? Image.file(
                        imageFile!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : imageUrl != null && imageUrl!.isNotEmpty
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, _, _) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
          ),

          const SizedBox(height: 6),
          Center(
            child: Text(
              "اضغط لاختيار أو التقاط صورة",
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ),

          const SizedBox(height: 20),

          // ── اسم المنتج ──
          TextField(
            controller: nameController,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: "اسم المنتج",
              prefixIcon: const Icon(
                Icons.inventory_2_outlined,
                color: _primaryDark,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── السعر ──
          TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: "السعر ﷼",
              prefixIcon: const Icon(
                Icons.payments_outlined,
                color: _primaryDark,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── القسم ──
          DropdownButtonFormField<String>(
            initialValue: selectedCategoryId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: "القسم (اختياري)",
              prefixIcon: const Icon(
                Icons.category_outlined,
                color: _primaryDark,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
            ),
            hint: const Text("اختر القسم"),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text("بدون قسم"),
              ),
              ...categories.map(
                (cat) => DropdownMenuItem<String>(
                  value: cat['id'] as String,
                  child: Text("${cat['emoji'] ?? '📦'} ${cat['name']}"),
                ),
              ),
            ],
            onChanged: (val) => setState(() => selectedCategoryId = val),
          ),

          const SizedBox(height: 30),

          // ── زر الحفظ ──
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryDark,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: isLoading ? null : saveProduct,
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      isEdit ? "تحديث المنتج" : "إضافة المنتج",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 48,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 8),
        Text(
          "اضغط لإضافة صورة",
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
      ],
    );
  }
}
