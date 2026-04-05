import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/models/offer.dart';
import '../../../core/services/offer_service.dart';
import '../../../core/utils/app_notification.dart';

class MerchantOffersScreen extends StatefulWidget {
  final String marketId;

  const MerchantOffersScreen({super.key, required this.marketId});

  @override
  State<MerchantOffersScreen> createState() => _MerchantOffersScreenState();
}

class _MerchantOffersScreenState extends State<MerchantOffersScreen> {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  final offerService = OfferService();
  final supabase = Supabase.instance.client;

  List<Offer> offers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    if (mounted) setState(() => isLoading = true);
    try {
      // جلب كل العروض (نشطة وغير نشطة) للتاجر
      final data = await supabase
          .from('offers')
          .select('*')
          .eq('market_id', widget.marketId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          offers = List<Map<String, dynamic>>.from(data)
              .map((e) => Offer.fromMap(e))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('MerchantOffers load error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _deleteOffer(String offerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("حذف العرض", textAlign: TextAlign.right),
        content: const Text("هل تريد حذف هذا العرض نهائياً؟",
            textAlign: TextAlign.right),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("حذف", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      // حذف مباشر من supabase مع التحقق
      await supabase.from('offers').delete().eq('id', offerId);

      // تحقق أن السجل حُذف فعلاً
      final check = await supabase
          .from('offers')
          .select('id')
          .eq('id', offerId)
          .maybeSingle();

      if (!mounted) return;

      if (check == null) {
        AppNotification.success(context, "تم حذف العرض");
        // إزالة من القائمة فوراً دون إعادة تحميل
        setState(() => offers.removeWhere((o) => o.id == offerId));
      } else {
        AppNotification.error(
            context, "لم يتم الحذف — تحقق من صلاحيات Supabase RLS");
      }
    } catch (e) {
      debugPrint('Delete offer error: $e');
      if (mounted) AppNotification.error(context, "حدث خطأ أثناء الحذف: $e");
    }
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddOfferSheet(
        marketId: widget.marketId,
        onSaved: _loadOffers,
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
        title: const Text(
          "إدارة العروض",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: _primaryDark,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade100, height: 1),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        backgroundColor: _primaryDark,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "إضافة عرض",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryDark))
          : offers.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadOffers,
                  color: _primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: offers.length,
                    itemBuilder: (context, index) =>
                        _buildOfferTile(offers[index]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_offer_outlined,
                size: 40, color: _primaryDark),
          ),
          const SizedBox(height: 16),
          const Text(
            "لا توجد عروض بعد",
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Text(
            "اضغط + لإضافة عرض جديد",
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferTile(Offer offer) {
    final hasPrice =
        offer.originalPrice != null && offer.discountedPrice != null;
    final discount = offer.discountPercent;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── صورة العرض ──
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(16),
            ),
            child: offer.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: offer.imageUrl,
                    width: 100,
                    height: 110,
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) => Container(
                      width: 100,
                      height: 110,
                      color: const Color(0xFFE8F5E9),
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: _primary, strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (ctx, url, err) => Container(
                      width: 100,
                      height: 110,
                      color: const Color(0xFFE8F5E9),
                      child: const Icon(Icons.local_offer_outlined,
                          color: _primary, size: 32),
                    ),
                  )
                : Container(
                    width: 100,
                    height: 110,
                    color: const Color(0xFFE8F5E9),
                    child: const Icon(Icons.local_offer_outlined,
                        color: _primary, size: 32),
                  ),
          ),

          // ── التفاصيل ──
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // العنوان
                  Text(
                    offer.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                  ),

                  // تاريخ العرض
                  if (offer.startDate != null || offer.endDate != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _buildDateRange(offer),
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[500]),
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.calendar_today_outlined,
                            size: 11, color: Colors.grey[400]),
                      ],
                    ),
                  ],

                  const SizedBox(height: 6),

                  // السعر
                  if (hasPrice)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (discount != null)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "${discount.toStringAsFixed(0)}%",
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        Text(
                          "${_fmt(offer.discountedPrice!)} ﷼",
                          style: const TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${_fmt(offer.originalPrice!)} ﷼",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 8),

                  // زر الحذف
                  GestureDetector(
                    onTap: () => _deleteOffer(offer.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("حذف",
                              style:
                                  TextStyle(color: Colors.red, fontSize: 12)),
                          SizedBox(width: 4),
                          Icon(Icons.delete_outline,
                              color: Colors.red, size: 15),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildDateRange(Offer offer) {
    final start =
        offer.startDate != null ? _fmtDate(offer.startDate!) : null;
    final end = offer.endDate != null ? _fmtDate(offer.endDate!) : null;
    if (start != null && end != null) return "من $start حتى $end";
    if (start != null) return "يبدأ $start";
    if (end != null) return "ينتهي $end";
    return '';
  }

  String _fmtDate(DateTime d) =>
      "${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}";

  String _fmt(double price) =>
      price % 1 == 0 ? price.toInt().toString() : price.toStringAsFixed(2);
}

// ══════════════════════════════════════════════
// Bottom Sheet — إضافة عرض جديد
// ══════════════════════════════════════════════
class _AddOfferSheet extends StatefulWidget {
  final String marketId;
  final VoidCallback onSaved;

  const _AddOfferSheet({required this.marketId, required this.onSaved});

  @override
  State<_AddOfferSheet> createState() => _AddOfferSheetState();
}

class _AddOfferSheetState extends State<_AddOfferSheet> {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  final titleController = TextEditingController();
  final originalPriceController = TextEditingController();
  final discountedPriceController = TextEditingController();

  File? imageFile;
  String? _prefillImageUrl;
  bool isLoading = false;
  bool isUploadingImage = false;

  List<Map<String, dynamic>> products = [];
  String? selectedProductId;

  DateTime? startDate;
  DateTime? endDate;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    titleController.dispose();
    originalPriceController.dispose();
    discountedPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final data = await supabase
          .from('products')
          .select('id, name, price, image_url')
          .eq('market_id', widget.marketId)
          .order('name', ascending: true);
      if (mounted) {
        setState(() {
          products = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Load products error: $e');
    }
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryDark)),
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
            Icon(icon, color: _primaryDark, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: _primaryDark, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 900,
      );
      if (picked != null) setState(() => imageFile = File(picked.path));
    } catch (e) {
      debugPrint('Pick image error: $e');
    }
  }

  Future<String?> _uploadImage() async {
    if (imageFile == null) return null;
    setState(() => isUploadingImage = true);
    try {
      final fileName =
          "offer_${widget.marketId}_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final bytes = await imageFile!.readAsBytes();
      await supabase.storage.from('offers').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
                upsert: true, contentType: 'image/jpeg'),
          );
      return supabase.storage.from('offers').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Upload offer image error: $e');
      return null;
    } finally {
      if (mounted) setState(() => isUploadingImage = false);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart
        ? (startDate ?? now)
        : (endDate ?? (startDate ?? now).add(const Duration(days: 7)));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primaryDark,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        startDate = picked;
        // إذا كان تاريخ النهاية قبل البداية، ازله
        if (endDate != null && endDate!.isBefore(startDate!)) {
          endDate = null;
        }
      } else {
        endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      AppNotification.warning(context, "أدخل عنوان العرض");
      return;
    }
    if (imageFile == null && (_prefillImageUrl == null || _prefillImageUrl!.isEmpty)) {
      AppNotification.warning(context, "اختر صورة للعرض");
      return;
    }

    final origPrice = double.tryParse(originalPriceController.text.trim());
    final discPrice = double.tryParse(discountedPriceController.text.trim());

    if (origPrice != null && discPrice != null && discPrice >= origPrice) {
      AppNotification.warning(
          context, "السعر بعد الخصم يجب أن يكون أقل من الأصلي");
      return;
    }

    setState(() => isLoading = true);

    try {
      String? uploadedUrl;
      if (imageFile != null) {
        uploadedUrl = await _uploadImage();
        if (uploadedUrl == null) {
          if (mounted) AppNotification.error(context, "فشل رفع الصورة");
          setState(() => isLoading = false);
          return;
        }
      } else {
        uploadedUrl = _prefillImageUrl ?? '';
      }

      String? productName;
      if (selectedProductId != null) {
        productName = products
            .firstWhere((p) => p['id'] == selectedProductId)['name']
            ?.toString();
      }

      await OfferService().addOffer(
        marketId: widget.marketId,
        title: title,
        imageUrl: uploadedUrl,
        productId: selectedProductId,
        productName: productName,
        originalPrice: origPrice,
        discountedPrice: discPrice,
        startDate: startDate,
        endDate: endDate,
      );

      if (mounted) {
        AppNotification.success(context, "تمت إضافة العرض");
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      debugPrint('Save offer error: $e');
      if (mounted) AppNotification.error(context, "حدث خطأ: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 20,
        left: 16,
        right: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // شريط السحب
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "إضافة عرض جديد",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _primaryDark,
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 20),

            // ── اختيار الصورة ──
            GestureDetector(
              onTap: isLoading ? null : _showImageSourceSheet,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: imageFile != null || _prefillImageUrl != null ? _primary : Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: isUploadingImage
                      ? const Center(
                          child:
                              CircularProgressIndicator(color: _primary))
                      : imageFile != null
                          ? Image.file(imageFile!,
                              fit: BoxFit.cover, width: double.infinity)
                          : _prefillImageUrl != null
                              ? Image.network(_prefillImageUrl!, fit: BoxFit.cover, width: double.infinity,
                                  errorBuilder: (_, url, err) => _buildImagePlaceholder())
                              : _buildImagePlaceholder(),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── عنوان العرض ──
            _buildField(
              controller: titleController,
              label: "عنوان العرض *",
              icon: Icons.local_offer_outlined,
            ),
            const SizedBox(height: 12),

            // ── ربط بمنتج ──
            if (products.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: selectedProductId,
                isExpanded: true,
                decoration: _fieldDecoration(
                    "ربط بمنتج (اختياري)", Icons.inventory_2_outlined),
                hint: const Text("اختر منتجاً للربط"),
                items: [
                  const DropdownMenuItem<String>(
                      value: null, child: Text("بدون ربط")),
                  ...products.map((p) => DropdownMenuItem<String>(
                        value: p['id'] as String,
                        child: Text(
                          "${p['name']} — ${p['price']} ﷼",
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
                onChanged: (val) {
                  setState(() {
                    selectedProductId = val;
                    if (val != null) {
                      final p =
                          products.firstWhere((p) => p['id'] == val);
                      originalPriceController.text =
                          p['price'].toString();
                      final productImageUrl = p['image_url']?.toString();
                      if (productImageUrl != null && productImageUrl.isNotEmpty) {
                        imageFile = null;
                        _prefillImageUrl = productImageUrl;
                      }
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
            ],

            // ── السعرين ──
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    controller: discountedPriceController,
                    label: "سعر بعد الخصم ﷼",
                    icon: Icons.price_check,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildField(
                    controller: originalPriceController,
                    label: "السعر الأصلي ﷼",
                    icon: Icons.payments_outlined,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── تاريخ البداية والنهاية ──
            Row(
              children: [
                // تاريخ النهاية (يمين في RTL = يسار في UI)
                Expanded(
                  child: _buildDateButton(
                    label: "تاريخ الانتهاء",
                    date: endDate,
                    onTap: () => _pickDate(false),
                    icon: Icons.event_busy_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                // تاريخ البداية
                Expanded(
                  child: _buildDateButton(
                    label: "تاريخ البداية",
                    date: startDate,
                    onTap: () => _pickDate(true),
                    icon: Icons.event_available_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

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
                onPressed: isLoading ? null : _save,
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        "إضافة العرض",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined, size: 44, color: Colors.grey[400]),
        const SizedBox(height: 8),
        Text("اضغط لاختيار أو التقاط صورة",
            style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      ],
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    final hasDate = date != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasDate ? _primary : Colors.grey.shade200,
            width: hasDate ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                hasDate ? _fmtDate(date) : label,
                style: TextStyle(
                  fontSize: 12,
                  color: hasDate ? Colors.black87 : Colors.grey[500],
                  fontWeight:
                      hasDate ? FontWeight.w600 : FontWeight.normal,
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Icon(icon,
                size: 18,
                color: hasDate ? _primaryDark : Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      textInputAction: textInputAction,
      decoration: _fieldDecoration(label, icon),
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _primaryDark, size: 20),
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
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    return "${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}";
  }
}
