import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/models/offer.dart';
import '../../../core/models/product.dart';
import '../../../core/services/offer_service.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/state/providers.dart';
import '../../../core/utils/app_notification.dart';

class OffersScreen extends ConsumerStatefulWidget {
  const OffersScreen({super.key});

  @override
  ConsumerState<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends ConsumerState<OffersScreen> {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  List<Offer> offers = [];
  bool isLoading = true;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    final marketId = ref.read(appStateProvider).marketId;
    if (marketId == null) {
      setState(() {
        isLoading = false;
        errorMsg = "لم يتم اختيار متجر";
      });
      return;
    }
    setState(() {
      isLoading = true;
      errorMsg = null;
    });
    try {
      final data = await OfferService().getOffers(marketId);
      if (mounted) setState(() => offers = data);
    } catch (e) {
      if (mounted) setState(() => errorMsg = "تعذّر تحميل العروض");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartService = ref.read(cartServiceProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: _primaryDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "العروض والخصومات",
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryDark))
          : errorMsg != null
              ? _buildError()
              : offers.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _loadOffers,
                      color: _primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: offers.length,
                        itemBuilder: (context, index) =>
                            _buildOfferCard(offers[index], cartService),
                      ),
                    ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_outlined, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(errorMsg!,
              style: const TextStyle(color: Colors.grey, fontSize: 15)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _loadOffers,
            icon: const Icon(Icons.refresh, color: _primaryDark),
            label: const Text("إعادة المحاولة",
                style: TextStyle(color: _primaryDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text(
            "لا توجد عروض متاحة حالياً",
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(Offer offer, CartService cartService) {
    final hasPrice =
        offer.originalPrice != null && offer.discountedPrice != null;
    final discount = offer.discountPercent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── صورة العرض ──
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
            child: Stack(
              children: [
                offer.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: offer.imageUrl,
                        height: 190,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (ctx, url) => Container(
                          height: 190,
                          color: const Color(0xFFE8F5E9),
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: _primary, strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (ctx, url, err) => Container(
                          height: 190,
                          color: const Color(0xFFE8F5E9),
                          child: const Icon(Icons.local_offer_outlined,
                              size: 48, color: _primary),
                        ),
                      )
                    : Container(
                        height: 190,
                        color: const Color(0xFFE8F5E9),
                        child: const Center(
                          child: Icon(Icons.local_offer_outlined,
                              size: 48, color: _primary),
                        ),
                      ),

                // شارة الخصم
                if (discount != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${discount.toStringAsFixed(0)}% خصم",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                // تدرج سفلي
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18)),
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),

                // عنوان العرض فوق الصورة
                Positioned(
                  bottom: 12,
                  right: 14,
                  left: 14,
                  child: Text(
                    offer.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          // ── تاريخ العرض ──
          if (offer.startDate != null || offer.endDate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _buildDateRange(offer),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.calendar_today_outlined,
                      size: 13, color: Colors.grey[400]),
                ],
              ),
            ),

          // ── تفاصيل السعر والزر ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // زر إضافة للسلة
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text(
                    "أضف للسلة",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () {
                    final effectivePrice = offer.discountedPrice ??
                        offer.originalPrice ??
                        0.0;
                    final product = Product(
                      id: offer.productId ?? offer.id,
                      name: offer.productName ?? offer.title,
                      price: effectivePrice,
                      image: offer.imageUrl,
                    );
                    cartService.addToCart(product);
                    AppNotification.success(
                      context,
                      "تمت إضافة ${product.name} للسلة",
                    );
                  },
                ),

                // السعر
                if (hasPrice)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Text("﷼",
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough)),
                          const SizedBox(width: 2),
                          Text(
                            _fmt(offer.originalPrice!),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text("﷼",
                              style: TextStyle(
                                color: _primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              )),
                          const SizedBox(width: 2),
                          Text(
                            _fmt(offer.discountedPrice!),
                            style: const TextStyle(
                              color: _primary,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else if (offer.discountedPrice != null ||
                    offer.originalPrice != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text("﷼",
                          style: TextStyle(
                            color: _primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(width: 2),
                      Text(
                        _fmt(offer.discountedPrice ?? offer.originalPrice!),
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildDateRange(Offer offer) {
    final start = offer.startDate != null ? _fmtDate(offer.startDate!) : null;
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
