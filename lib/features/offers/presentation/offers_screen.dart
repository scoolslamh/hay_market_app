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
    final marketName =
        ref.read(appStateProvider).marketName ?? "المتجر";

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── الجزء العلوي بتدرج ──
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF004D40), Color(0xFF00796B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(36),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 48),
            child: Column(
              children: [
                // شعار المتجر
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Image.asset(
                      'assets/tamenat.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // اسم المتجر
                Text(
                  marketName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 6),

                // شريط زخرفي
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        width: 30,
                        height: 2,
                        color: Colors.white.withValues(alpha: 0.4)),
                    const SizedBox(width: 8),
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        )),
                    const SizedBox(width: 8),
                    Container(
                        width: 30,
                        height: 2,
                        color: Colors.white.withValues(alpha: 0.4)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // ── بطاقة العبارة الرئيسية ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // أيقونة ساعة رملية مع لون
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      size: 36,
                      color: Color(0xFF004D40),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "انتظروا عروضنا",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF004D40),
                      letterSpacing: 1,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "نعمل على تحضير أفضل العروض والخصومات\nخصيصاً لكم، ترقّبوا المفاجآت!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      height: 1.7,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // شريط زخرفي سفلي
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final isMiddle = i == 2;
                      return Container(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 3),
                        width: isMiddle ? 20 : 8,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isMiddle
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFB2DFDB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
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
          Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── الأسعار ──
                  if (hasPrice) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // السعر بعد الخصم
                        Text(
                          "${_fmt(offer.discountedPrice!)} ﷼",
                          style: const TextStyle(
                            color: _primary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // السعر الأصلي مشطوب
                        Text(
                          "${_fmt(offer.originalPrice!)} ﷼",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ] else if (offer.originalPrice != null ||
                      offer.discountedPrice != null) ...[
                    Text(
                      "${_fmt(offer.discountedPrice ?? offer.originalPrice!)} ﷼",
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ── زر إضافة للسلة ──
                  SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text(
                        "أضف للسلة",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
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
