import 'package:flutter/material.dart';
import '../../../core/utils/app_notification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  final supabase = Supabase.instance.client;
  late Map<String, dynamic> order;

  // ✅ مربعات تجميع المنتجات
  late List<bool> checkedItems;

  // ✅ مراحل الحالة بالترتيب
  static const List<Map<String, dynamic>> _stages = [
    {
      'key': 'new',
      'label': 'قيد المراجعة',
      'icon': Icons.hourglass_empty_rounded,
      'color': Colors.orange,
    },
    {
      'key': 'processing',
      'label': 'جاري التجهيز',
      'icon': Icons.restaurant_rounded,
      'color': Colors.blue,
    },
    {
      'key': 'delivery_dining',
      'label': 'جاري التوصيل',
      'icon': Icons.delivery_dining_rounded,
      'color': Colors.purple,
    },
    {
      'key': 'delivered',
      'label': 'تم التوصيل',
      'icon': Icons.check_circle_rounded,
      'color': Color(0xFF4CAF50),
    },
  ];

  String? customerName;

  @override
  void initState() {
    super.initState();
    order = Map<String, dynamic>.from(widget.order);
    final products = (order['products'] as List?) ?? [];
    checkedItems = List<bool>.filled(products.length, false);
    _loadCustomerName();
  }

  String _formatDateTime(String? createdAt) {
    if (createdAt == null) return '-';
    final dt = DateTime.tryParse(createdAt)?.toLocal();
    if (dt == null) return '-';
    const months = [
      '',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month]} — $h:$m';
  }

  Future<void> _loadCustomerName() async {
    try {
      final phone = order['phone'];
      if (phone == null) return;
      final data = await supabase
          .from('users')
          .select('name')
          .eq('phone', phone)
          .maybeSingle();
      if (mounted && data != null) {
        setState(() => customerName = data['name']);
      }
    } catch (e) {
      debugPrint("Load customer name: $e");
    }
  }

  int get _currentStageIndex {
    final status = order['status'] ?? 'new';
    return _stages.indexWhere((s) => s['key'] == status);
  }

  bool get _allChecked =>
      checkedItems.isNotEmpty && checkedItems.every((c) => c);

  bool get _isCanceled => order['status'] == 'canceled';
  bool get _isDelivered => order['status'] == 'delivered';
  bool get _isArchived => _isCanceled || _isDelivered;

  Future<void> _advanceStatus() async {
    final currentIdx = _currentStageIndex;
    if (currentIdx < 0 || currentIdx >= _stages.length - 1) return;

    final nextStatus = _stages[currentIdx + 1]['key'] as String;

    try {
      await supabase
          .from('orders')
          .update({'status': nextStatus})
          .eq('id', order['id']);

      if (!mounted) return;
      setState(() => order['status'] = nextStatus);

      AppNotification.success(
        context,
        "✅ تم التحديث: ${_stages[currentIdx + 1]['label']}",
      );
    } catch (e) {
      debugPrint("Update error: $e");
    }
  }

  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("إلغاء الطلب"),
        content: const Text("هل أنت متأكد من إلغاء هذا الطلب؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("لا"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "نعم، إلغاء",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase
          .from('orders')
          .update({'status': 'canceled'})
          .eq('id', order['id']);
      if (!mounted) return;
      setState(() => order['status'] = 'canceled');
    } catch (e) {
      debugPrint("Cancel error: $e");
    }
  }

  Future<void> _callCustomer() async {
    final phone = order['phone'] ?? '';
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = (order['products'] as List?) ?? [];
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final totalStr = total % 1 == 0
        ? total.toInt().toString()
        : total.toStringAsFixed(1);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "طلب #${order['id'].toString().substring(0, 8).toUpperCase()}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [
          // زر اتصال
          IconButton(
            icon: const Icon(Icons.phone_outlined, color: _primaryDark),
            onPressed: _callCustomer,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── معلومات العميل ──
          _buildSection(
            title: "معلومات العميل",
            child: Column(
              children: [
                if (customerName != null && customerName!.isNotEmpty)
                  _buildInfoRow(Icons.person_outline, "الاسم", customerName!),
                _buildInfoRow(
                  Icons.phone_outlined,
                  "الهاتف",
                  order['phone'] ?? '-',
                ),
                // ✅ وقت الطلب
                if (order['created_at'] != null)
                  _buildInfoRow(
                    Icons.access_time_outlined,
                    "وقت الطلب",
                    _formatDateTime(order['created_at']),
                  ),
                if (order['address'] != null &&
                    order['address'].toString().isNotEmpty)
                  _buildInfoRow(
                    Icons.location_on_outlined,
                    "العنوان",
                    order['address'],
                  ),
                if (order['customer_notes'] != null &&
                    order['customer_notes'].toString().isNotEmpty)
                  _buildInfoRow(
                    Icons.notes_outlined,
                    "ملاحظات",
                    order['customer_notes'],
                  ),
                _buildInfoRow(
                  Icons.payment_outlined,
                  "طريقة الدفع",
                  order['payment_method'] == 'cash'
                      ? 'كاش 💵'
                      : order['payment_method'] == 'mada'
                      ? 'مدى 💳'
                      : 'دفتر 📒',
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── حالة الطلب التدريجية ──
          if (!_isArchived)
            _buildSection(
              title: "مراحل الطلب",
              child: Column(
                children: List.generate(_stages.length, (i) {
                  final stage = _stages[i];
                  final isDone = i <= _currentStageIndex;
                  final isCurrent = i == _currentStageIndex;
                  final color = stage['color'] as Color;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        // خط رأسي
                        if (i < _stages.length - 1)
                          Padding(
                            padding: const EdgeInsets.only(right: 15),
                            child: Column(
                              children: [
                                const SizedBox(height: 28),
                                Container(
                                  width: 2,
                                  height: 20,
                                  color: isDone ? color : Colors.grey[200],
                                ),
                              ],
                            ),
                          ),

                        // المحتوى
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? color.withValues(alpha: 0.08)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCurrent ? color : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                // مربع الحالة
                                GestureDetector(
                                  onTap: isCurrent ? _advanceStatus : null,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: isDone ? color : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDone
                                            ? color
                                            : Colors.grey.shade300,
                                        width: 2,
                                      ),
                                    ),
                                    child: isDone
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 16,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // الأيقونة والنص
                                Icon(
                                  stage['icon'] as IconData,
                                  color: isDone ? color : Colors.grey[400],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    stage['label'] as String,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isDone
                                          ? Colors.black87
                                          : Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (isCurrent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "الحالية",
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
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
                }),
              ),
            ),

          // ── حالة المؤرشف ──
          if (_isArchived)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isDelivered
                    ? _primary.withValues(alpha: 0.08)
                    : Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isDelivered ? _primary : Colors.red,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isDelivered ? Icons.check_circle : Icons.cancel,
                    color: _isDelivered ? _primary : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isDelivered ? "تم التوصيل" : "ملغي",
                    style: TextStyle(
                      color: _isDelivered ? _primary : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // ── قائمة المنتجات مع مربعات التجميع ──
          _buildSection(
            title: "تجميع المنتجات",
            trailing: Text(
              "${checkedItems.where((c) => c).length}/${products.length}",
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            child: Column(
              children: [
                ...List.generate(products.length, (i) {
                  final p = products[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        // ✅ مربع التجميع
                        GestureDetector(
                          onTap: () => setState(
                            () => checkedItems[i] = !checkedItems[i],
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: checkedItems[i] ? _primary : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: checkedItems[i]
                                    ? _primary
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: checkedItems[i]
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // السعر
                              Text(
                                "${(p['subtotal'] ?? p['price'] ?? 0)} ﷼",
                                style: TextStyle(
                                  color: _primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  decoration: checkedItems[i]
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              // الاسم والكمية
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    p['name'] ?? '',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: checkedItems[i]
                                          ? Colors.grey
                                          : Colors.black87,
                                      decoration: checkedItems[i]
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  if ((p['quantity'] ?? 1) > 1)
                                    Text(
                                      "× ${p['quantity']}",
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
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
                }),

                // شريط التقدم
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: products.isEmpty
                        ? 0
                        : checkedItems.where((c) => c).length / products.length,
                    backgroundColor: Colors.grey[200],
                    color: _primary,
                    minHeight: 6,
                  ),
                ),
                if (_allChecked)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "✅ تم تجميع جميع المنتجات",
                      style: TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── الإجمالي ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _primaryDark,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      totalStr,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      " ﷼",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const Text(
                  "الإجمالي",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── أزرار العمل ──
          if (!_isArchived) ...[
            // زر التقدم للمرحلة التالية
            if (_currentStageIndex < _stages.length - 1)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _stages[_currentStageIndex + 1]['color'] as Color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _advanceStatus,
                  icon: Icon(
                    _stages[_currentStageIndex + 1]['icon'] as IconData,
                  ),
                  label: Text(
                    "التالي: ${_stages[_currentStageIndex + 1]['label']}",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // زر إلغاء
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _cancelOrder,
                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                label: const Text(
                  "إلغاء الطلب",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                trailing ?? const SizedBox(),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[100]),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(width: 8),
          Icon(icon, color: const Color(0xFF004D40), size: 18),
        ],
      ),
    );
  }
}
