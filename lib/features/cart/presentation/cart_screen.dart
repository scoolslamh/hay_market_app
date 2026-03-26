import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/order_service.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/state/providers.dart';
import '../../../core/utils/app_notification.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final OrderService orderService = OrderService();
  bool isSending = false;

  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  void _startOrderFlow() {
    final cartService = ref.read(cartServiceProvider);
    if (cartService.items.isEmpty) return;

    final appState = ref.read(appStateProvider);
    if (appState.userPhone == null || appState.marketId == null) {
      AppNotification.warning(context, "بيانات المستخدم أو المتجر غير مكتملة");
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _OrderFlowSheet(cartService: cartService, onConfirm: _sendOrder),
    );
  }

  Future<void> _sendOrder(String notes, String paymentMethod) async {
    setState(() => isSending = true);
    try {
      await orderService.createOrder(
        ref: ref,
        customerNotes: notes,
        paymentMethod: paymentMethod,
      );
      ref.read(cartServiceProvider).clearCart();
      if (!mounted) return;
      AppNotification.success(context, "🚀 تم إرسال طلبك بنجاح!");
    } catch (e) {
      if (!mounted) return;
      AppNotification.error(context, "حدث خطأ: $e");
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartService = ref.watch(cartServiceProvider);
    final items = cartService.items;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "سلة المشتريات",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("تفريغ السلة"),
                  content: const Text("هل تريد حذف جميع المنتجات؟"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("إلغاء"),
                    ),
                    TextButton(
                      onPressed: () {
                        cartService.clearCart();
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "تفريغ",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              child: const Text(
                "تفريغ",
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
        ],
      ),
      body: items.isEmpty
          ? _buildEmptyCart()
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${cartService.totalQuantity} منتج",
                          style: const TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _buildCartItem(items[index], cartService),
                  ),
                ),
                _buildOrderSummary(cartService),
              ],
            ),
    );
  }

  Widget _buildCartItem(CartItem item, CartService cartService) {
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
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 70,
                height: 70,
                color: const Color(0xFFF8F8F8),
                child:
                    item.product.image != null && item.product.image!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.product.image ?? "",
                        fit: BoxFit.contain,
                        placeholder: (_, _) => const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primary,
                            ),
                          ),
                        ),
                        errorWidget: (_, _, _) => const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey,
                          size: 28,
                        ),
                      )
                    : const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey,
                        size: 28,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        item.product.price % 1 == 0
                            ? item.product.price.toInt().toString()
                            : item.product.price.toStringAsFixed(1),
                        style: const TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const Text(
                        " ﷼",
                        style: TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      if (item.quantity > 1) ...[
                        const SizedBox(width: 6),
                        Text(
                          "× ${item.quantity} = ${item.subtotal % 1 == 0 ? item.subtotal.toInt() : item.subtotal.toStringAsFixed(1)} ﷼",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                GestureDetector(
                  onTap: () => cartService.removeFromCart(item.product),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => cartService.decreaseQty(item.product.id),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(9),
                            ),
                          ),
                          child: const Icon(
                            Icons.remove,
                            size: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        child: Text(
                          item.quantity.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => cartService.increaseQty(item.product.id),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _primary,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(9),
                            ),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 90, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "سلتك فارغة",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "أضف منتجات من الصفحة الرئيسية",
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(CartService cartService) {
    final total = cartService.total;
    final totalStr = total % 1 == 0
        ? total.toInt().toString()
        : total.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${cartService.totalQuantity} منتج",
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
                Row(
                  children: [
                    Text(
                      totalStr,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _primaryDark,
                      ),
                    ),
                    const Text(
                      " ﷼",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
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
                onPressed: isSending ? null : _startOrderFlow,
                child: isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "تأكيد وإرسال الطلب",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// Bottom Sheet — خطوات تأكيد الطلب
// ══════════════════════════════════════════════════
class _OrderFlowSheet extends StatefulWidget {
  final CartService cartService;
  final Future<void> Function(String notes, String paymentMethod) onConfirm;

  const _OrderFlowSheet({required this.cartService, required this.onConfirm});

  @override
  State<_OrderFlowSheet> createState() => _OrderFlowSheetState();
}

class _OrderFlowSheetState extends State<_OrderFlowSheet> {
  int _step = 0;
  String _selectedPayment = '';
  final _notesController = TextEditingController();
  bool _isSending = false;
  String? _address;
  bool _loadingAddress = true;

  // ✅ بيانات الدفتر
  Map<String, dynamic>? _daftar;
  bool _loadingDaftar = true;

  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  @override
  void initState() {
    super.initState();
    _loadAddress();
    _loadDaftar();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // ✅ جلب بيانات الدفتر
  Future<void> _loadDaftar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone');
      if (phone == null) {
        setState(() => _loadingDaftar = false);
        return;
      }
      final data = await Supabase.instance.client
          .from('daftar')
          .select()
          .eq('customer_phone', phone)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _daftar = data;
          _loadingDaftar = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingDaftar = false);
    }
  }

  Future<void> _loadAddress() async {
    try {
      final data = await Supabase.instance.client
          .from('addresses')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _address = data?['address_name'] ?? "لم يتم تحديد عنوان";
          _loadingAddress = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  Future<void> _confirm() async {
    setState(() => _isSending = true);
    await widget.onConfirm(_notesController.text.trim(), _selectedPayment);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // شريط سحب
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
              const SizedBox(height: 20),

              _buildStepIndicator(),
              const SizedBox(height: 24),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildStepContent(),
              ),

              const SizedBox(height: 20),
              _buildNavButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['الموقع', 'ملاحظات', 'الدفع'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i == _step;
        final isDone = i < _step;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDone
                            ? _primary
                            : isActive
                            ? _primaryDark
                            : Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : Colors.grey[500],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[i],
                      style: TextStyle(
                        fontSize: 11,
                        color: isActive ? _primaryDark : Colors.grey[400],
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 20),
                    color: i < _step ? _primary : Colors.grey[200],
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildLocationStep();
      case 1:
        return _buildNotesStep();
      case 2:
        return _buildPaymentStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildLocationStep() {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "عنوان التوصيل",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on, color: _primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _loadingAddress
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _address ?? "لم يتم تحديد عنوان",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.right,
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "إذا أردت تغيير العنوان اذهب لصفحة الحساب",
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  Widget _buildNotesStep() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "ملاحظات للتوصيل",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          "اختياري — أي تعليمات خاصة للموصّل",
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 3,
          maxLength: 200,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: "مثال: اتصل قبل التوصيل، الطابق الثاني...",
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            filled: true,
            fillColor: Colors.grey[50],
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
      ],
    );
  }

  Widget _buildPaymentStep() {
    final daftarStatus = _daftar?['status'];
    final daftarBalance =
        (_daftar?['current_balance'] as num?)?.toDouble() ?? 0;
    final daftarReserved =
        (_daftar?['reserved_balance'] as num?)?.toDouble() ?? 0;
    final daftarLimit = (_daftar?['credit_limit'] as num?)?.toDouble() ?? 0;
    final orderTotal = widget.cartService.total;
    // ✅ الرصيد المتاح = الحد - (الفعلي + المحجوز)
    final daftarAvailable = daftarLimit - daftarBalance - daftarReserved;
    final canUseDaftar =
        daftarStatus == 'approved' && orderTotal <= daftarAvailable;

    final methods = [
      {
        'id': 'cash',
        'label': 'كاش',
        'icon': Icons.payments_outlined,
        'soon': false,
        'disabled': false,
      },
      {
        'id': 'mada',
        'label': 'مدى',
        'icon': Icons.credit_card_outlined,
        'soon': false,
        'disabled': false,
      },
      {
        'id': 'daftar',
        'label': 'الدفتر',
        'icon': Icons.book_outlined,
        'soon': false,
        'disabled': _daftar == null || !canUseDaftar,
      },
    ];

    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "طريقة الدفع",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),

        // ✅ حالة الدفتر
        if (_loadingDaftar)
          const Center(child: CircularProgressIndicator())
        else if (_daftar == null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "لا يوجد دفتر مفعّل — يمكن التقديم من صفحة الحساب",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.right,
                ),
                SizedBox(width: 6),
                Icon(Icons.info_outline, color: Colors.grey, size: 16),
              ],
            ),
          )
        else if (daftarStatus == 'approved')
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF1565C0).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  canUseDaftar
                      ? "متاح: ${daftarAvailable.toStringAsFixed(1)} ﷼"
                      : "تجاوز الحد ❌",
                  style: TextStyle(
                    color: canUseDaftar ? const Color(0xFF1565C0) : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Text(
                  "📒 رصيد الدفتر",
                  style: TextStyle(color: Color(0xFF1565C0), fontSize: 12),
                ),
              ],
            ),
          )
        else if (daftarStatus == 'frozen')
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "دفترك مجمد — تواصل مع التاجر",
                  style: TextStyle(color: Colors.blue, fontSize: 12),
                ),
                SizedBox(width: 6),
                Icon(Icons.ac_unit, color: Colors.blue, size: 16),
              ],
            ),
          ),

        ...methods.map((m) {
          final isSoon = m['soon'] as bool;
          final isDisabled = m['disabled'] as bool;
          final isSelected = _selectedPayment == m['id'];
          final isDaftar = m['id'] == 'daftar';

          return GestureDetector(
            onTap: (isSoon || isDisabled)
                ? null
                : () => setState(() => _selectedPayment = m['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDaftar
                          ? const Color(0xFF1565C0).withValues(alpha: 0.06)
                          : _primaryDark.withValues(alpha: 0.06))
                    : isDisabled
                    ? Colors.grey[50]
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? (isDaftar ? const Color(0xFF1565C0) : _primaryDark)
                      : Colors.grey.shade200,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    m['icon'] as IconData,
                    color: isDisabled
                        ? Colors.grey[300]
                        : isDaftar
                        ? const Color(0xFF1565C0)
                        : _primaryDark,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      m['label'] as String,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDisabled ? Colors.grey[400] : Colors.black87,
                      ),
                    ),
                  ),
                  if (isDisabled && isDaftar && _daftar != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "تجاوز الحد",
                        style: TextStyle(fontSize: 11, color: Colors.red),
                      ),
                    )
                  else if (isDisabled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "غير متاح",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    )
                  else if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: isDaftar ? const Color(0xFF1565C0) : _primaryDark,
                      size: 20,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNavButtons() {
    final isLastStep = _step == 2;
    final canProceed = _step == 2 ? _selectedPayment.isNotEmpty : true;

    return Row(
      children: [
        if (_step > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _step--),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "رجوع",
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: !canProceed || _isSending
                ? null
                : isLastStep
                ? _confirm
                : () => setState(() => _step++),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryDark,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSending
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    isLastStep ? "إرسال الطلب 🚀" : "التالي",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
