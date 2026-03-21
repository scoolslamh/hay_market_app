import 'dart:io';
import 'package:flutter/material.dart';
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
  final supabase = Supabase.instance.client;

  final nameController = TextEditingController();
  final priceController = TextEditingController();

  File? imageFile;
  String? imageUrl;

  bool isLoading = false;
  double uploadProgress = 0;

  // ✅ الأقسام
  List<Map<String, dynamic>> categories = [];
  String? selectedCategoryId;
  bool loadingCategories = true;

  @override
  void initState() {
    super.initState();

    if (widget.product != null) {
      nameController.text = widget.product!['name'] ?? "";
      priceController.text = widget.product!['price']?.toString() ?? "";
      imageUrl = widget.product!['image_url'];
      selectedCategoryId = widget.product!['category_id'];
    }

    _loadCategories();
  }

  /// ✅ جلب الأقسام من Supabase
  Future<void> _loadCategories() async {
    try {
      final data = await supabase
          .from('categories')
          .select()
          .order('sort_order', ascending: true);

      if (mounted) {
        setState(() {
          categories = List<Map<String, dynamic>>.from(data);
          loadingCategories = false;
        });
      }
    } catch (e) {
      debugPrint("Load categories error: $e");
      if (mounted) setState(() => loadingCategories = false);
    }
  }

  /// 📸 اختيار صورة
  Future<void> pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
        maxWidth: 800,
      );

      if (picked != null) {
        setState(() {
          imageFile = File(picked.path);
        });
      }
    } catch (e) {
      debugPrint("Pick image error: $e");
    }
  }

  /// ☁️ رفع الصورة
  Future<String?> uploadImage() async {
    try {
      if (imageFile == null) return imageUrl;

      setState(() => uploadProgress = 0.2);

      final fileName = "product_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final path = "${widget.marketId}/$fileName";

      await supabase.storage.from('products').upload(path, imageFile!);

      setState(() => uploadProgress = 0.9);

      final publicUrl = supabase.storage.from('products').getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      debugPrint("🔥 UPLOAD ERROR: $e");

      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("خطأ رفع الصورة: $e")));

      return null;
    }
  }

  /// 💾 حفظ المنتج
  Future<void> saveProduct() async {
    final name = nameController.text.trim();
    final price = double.tryParse(priceController.text.trim());

    if (name.isEmpty || price == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("تحقق من البيانات")));
      return;
    }

    try {
      setState(() {
        isLoading = true;
        uploadProgress = 0.1;
      });

      final uploadedImage = await uploadImage();
      final imageToSave = uploadedImage ?? imageUrl ?? "";

      if (widget.product == null) {
        // ✅ إضافة منتج جديد مع القسم
        await supabase.from('products').insert({
          "name": name,
          "price": price,
          "market_id": widget.marketId,
          "image_url": imageToSave,
          "category_id": selectedCategoryId,
        });
      } else {
        // ✅ تعديل منتج موجود مع القسم
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
      Navigator.pop(context);
    } catch (e) {
      debugPrint("🔥 SAVE ERROR: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          uploadProgress = 0;
        });
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? "تعديل المنتج" : "إضافة منتج")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            /// 🖼️ الصورة
            GestureDetector(
              onTap: isLoading ? null : pickImage,
              child: Stack(
                children: [
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.grey[200],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: imageFile != null
                          ? Image.file(imageFile!, fit: BoxFit.cover)
                          : imageUrl != null
                          ? Image.network(imageUrl!, fit: BoxFit.cover)
                          : const Center(
                              child: Icon(Icons.camera_alt, size: 40),
                            ),
                    ),
                  ),
                  if (isLoading)
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: Colors.black45,
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: uploadProgress,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// اسم المنتج
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "اسم المنتج",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            /// السعر
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "السعر",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            /// ✅ القسم
            loadingCategories
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<String>(
                    value: selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: "القسم",
                      border: const OutlineInputBorder(),
                      prefixIcon: selectedCategoryId != null
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                categories.firstWhere(
                                      (c) => c['id'] == selectedCategoryId,
                                      orElse: () => {'emoji': ''},
                                    )['emoji'] ??
                                    '',
                                style: const TextStyle(fontSize: 20),
                              ),
                            )
                          : null,
                    ),
                    hint: const Text("اختر القسم"),
                    items: categories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat['id'] as String,
                        child: Text("${cat['emoji'] ?? ''} ${cat['name']}"),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedCategoryId = value);
                    },
                  ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: isLoading ? null : saveProduct,
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(isEdit ? "تحديث المنتج" : "إضافة المنتج"),
            ),
          ],
        ),
      ),
    );
  }
}
