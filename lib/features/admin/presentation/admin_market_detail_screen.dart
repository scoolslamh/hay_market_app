import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/app_notification.dart';

class AdminMarketDetailScreen extends StatefulWidget {
  final Map<String, dynamic> market;
  const AdminMarketDetailScreen({super.key, required this.market});

  @override
  State<AdminMarketDetailScreen> createState() =>
      _AdminMarketDetailScreenState();
}

class _AdminMarketDetailScreenState extends State<AdminMarketDetailScreen> {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  final supabase = Supabase.instance.client;
  late Map<String, dynamic> market;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    market = Map<String, dynamic>.from(widget.market);
  }

  // ── قبول المتجر ──
  Future<void> _approveMarket() async {
    final subEndCtrl = TextEditingController();
    final feeCtrl = TextEditingController(text: '100');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("قبول المتجر"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text("رسوم الاشتراك الشهرية ﷼"),
            const SizedBox(height: 8),
            TextField(
              controller: feeCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("قبول"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => isLoading = true);

    try {
      final fee = double.tryParse(feeCtrl.text.trim()) ?? 100;
      final now = DateTime.now();
      final endDate = DateTime(now.year, now.month + 1, now.day);

      // تحديث المتجر
      await supabase
          .from('markets')
          .update({
            'status': 'active',
            'subscription_fee': fee,
            'subscription_start': now.toIso8601String(),
            'subscription_end': endDate.toIso8601String(),
            'subscription_plan': 'monthly',
          })
          .eq('id', market['id']);

      // تسجيل الاشتراك
      await supabase.from('subscriptions').insert({
        'market_id': market['id'],
        'plan': 'monthly',
        'fee': fee,
        'start_date': now.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'paid_at': now.toIso8601String(),
        'note': 'اشتراك أولي عند القبول',
      });

      // تحديث role المستخدم
      if (market['owner_phone'] != null) {
        await supabase
            .from('users')
            .update({'role': 'merchant'})
            .eq('phone', market['owner_phone']);
      }

      if (!mounted) return;
      setState(() {
        market['status'] = 'active';
        isLoading = false;
      });
      AppNotification.success(context, "✅ تم قبول المتجر بنجاح");
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      AppNotification.error(context, "حدث خطأ: $e");
    }
  }

  // ── رفض المتجر ──
  Future<void> _rejectMarket() async {
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("رفض المتجر"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text("سبب الرفض"),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              textAlign: TextAlign.right,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "أدخل سبب الرفض...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("رفض", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => isLoading = true);

    try {
      await supabase
          .from('markets')
          .update({
            'status': 'rejected',
            'rejection_reason': reasonCtrl.text.trim(),
          })
          .eq('id', market['id']);

      if (!mounted) return;
      setState(() {
        market['status'] = 'rejected';
        isLoading = false;
      });
      AppNotification.info(context, "تم رفض المتجر");
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      AppNotification.error(context, "حدث خطأ: $e");
    }
  }

  // ── تجميد / تفعيل ──
  Future<void> _toggleFreeze() async {
    final isActive = market['status'] == 'active';
    final newStatus = isActive ? 'frozen' : 'active';
    final msg = isActive ? "تجميد المتجر؟" : "تفعيل المتجر؟";

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isActive ? "تجميد" : "تفعيل",
              style: TextStyle(color: isActive ? Colors.blue : _primary),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await supabase
          .from('markets')
          .update({'status': newStatus})
          .eq('id', market['id']);
      if (!mounted) return;
      setState(() => market['status'] = newStatus);
      AppNotification.success(
        context,
        isActive ? "تم تجميد المتجر" : "تم تفعيل المتجر",
      );
    } catch (e) {
      AppNotification.error(context, "حدث خطأ: $e");
    }
  }

  // ── تجديد الاشتراك ──
  Future<void> _renewSubscription() async {
    final feeCtrl = TextEditingController(
      text: market['subscription_fee']?.toString() ?? '100',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("تجديد الاشتراك"),
        content: TextField(
          controller: feeCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            labelText: "رسوم الاشتراك ﷼",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryDark,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("تجديد"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final fee = double.tryParse(feeCtrl.text.trim()) ?? 100;
      final now = DateTime.now();
      final endDate = DateTime(now.year, now.month + 1, now.day);

      await supabase
          .from('markets')
          .update({
            'subscription_fee': fee,
            'subscription_start': now.toIso8601String(),
            'subscription_end': endDate.toIso8601String(),
          })
          .eq('id', market['id']);

      await supabase.from('subscriptions').insert({
        'market_id': market['id'],
        'plan': 'monthly',
        'fee': fee,
        'start_date': now.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'paid_at': now.toIso8601String(),
      });

      if (!mounted) return;
      AppNotification.success(context, "✅ تم تجديد الاشتراك");
      setState(() {
        market['subscription_fee'] = fee;
        market['subscription_end'] = endDate.toIso8601String();
      });
    } catch (e) {
      AppNotification.error(context, "حدث خطأ: $e");
    }
  }

  String _formatDate(String? dt) {
    if (dt == null) return '-';
    final d = DateTime.tryParse(dt);
    if (d == null) return '-';
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
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final status = market['status'] ?? 'pending';

    Color statusColor;
    String statusText;
    switch (status) {
      case 'active':
        statusColor = _primary;
        statusText = 'نشط ✅';
        break;
      case 'frozen':
        statusColor = Colors.blue;
        statusText = 'مجمد ❄️';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'مرفوض ❌';
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'بانتظار القبول ⏳';
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          market['name'] ?? '',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Colors.black87,
          ),
        ),
        actions: [
          if (status == 'active' || status == 'frozen')
            IconButton(
              icon: Icon(
                status == 'active'
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                color: status == 'active' ? Colors.blue : _primary,
              ),
              onPressed: _toggleFreeze,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── الحالة ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── بيانات المتجر ──
          _buildSection("بيانات المتجر", [
            _buildInfoRow(
              Icons.store_outlined,
              "اسم المتجر",
              market['name'] ?? '-',
            ),
            _buildInfoRow(
              Icons.person_outline,
              "صاحب المتجر",
              market['owner_name'] ?? '-',
            ),
            _buildInfoRow(
              Icons.phone_outlined,
              "الجوال",
              market['owner_phone'] ?? '-',
              onTap: () async {
                final url = Uri.parse('tel:${market['owner_phone']}');
                if (await canLaunchUrl(url)) launchUrl(url);
              },
            ),
            _buildInfoRow(
              Icons.badge_outlined,
              "رقم الترخيص",
              market['license_number'] ?? '-',
            ),
            _buildInfoRow(
              Icons.location_city_outlined,
              "الحي",
              market['neighborhood_name'] ?? '-',
            ),
          ]),

          const SizedBox(height: 12),

          // ── الصور ──
          if (market['license_image_url'] != null ||
              market['store_image_url'] != null)
            _buildImagesSection(),

          const SizedBox(height: 12),

          // ── الاشتراك ──
          if (status == 'active')
            _buildSection(
              "بيانات الاشتراك",
              [
                _buildInfoRow(
                  Icons.payments_outlined,
                  "الرسوم الشهرية",
                  "${market['subscription_fee'] ?? 0} ﷼",
                ),
                _buildInfoRow(
                  Icons.calendar_today_outlined,
                  "بداية الاشتراك",
                  _formatDate(market['subscription_start']),
                ),
                _buildInfoRow(
                  Icons.event_outlined,
                  "نهاية الاشتراك",
                  _formatDate(market['subscription_end']),
                ),
              ],
              action: TextButton(
                onPressed: _renewSubscription,
                child: const Text(
                  "تجديد",
                  style: TextStyle(
                    color: _primaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 20),

          // ── أزرار الإجراءات ──
          if (status == 'pending') ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: isLoading ? null : _approveMarket,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  "قبول المتجر",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
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
                onPressed: isLoading ? null : _rejectMarket,
                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                label: const Text(
                  "رفض الطلب",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> rows, {Widget? action}) {
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
                action ?? const SizedBox(),
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
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (onTap != null)
              const Icon(Icons.touch_app, size: 14, color: Colors.green),
            const Spacer(),
            Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                color: onTap != null ? Colors.green : Colors.black87,
                fontWeight: onTap != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: const Color(0xFF004D40), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesSection() {
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                "الصور المرفقة",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          Divider(height: 1, color: Colors.grey[100]),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                if (market['license_image_url'] != null &&
                    market['license_image_url'].toString().isNotEmpty)
                  Expanded(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            market['license_image_url'],
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(Icons.error),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "السجل التجاري",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                if (market['store_image_url'] != null &&
                    market['store_image_url'].toString().isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            market['store_image_url'],
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(Icons.error),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "واجهة المتجر",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
