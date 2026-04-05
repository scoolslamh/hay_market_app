import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/state/providers.dart';
import '../../../core/utils/app_notification.dart';
import '../../markets/presentation/markets_screen.dart';

class DaftarScreen extends ConsumerStatefulWidget {
  const DaftarScreen({super.key});

  @override
  ConsumerState<DaftarScreen> createState() => _DaftarScreenState();
}

class _DaftarScreenState extends ConsumerState<DaftarScreen> {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _daftar = Color(0xFF1565C0); // أزرق للدفتر

  final supabase = Supabase.instance.client;

  Map<String, dynamic>? daftar;
  List<Map<String, dynamic>> transactions = [];
  bool isLoading = true;
  bool hasApplied = false;
  String? _selectedMonthKey;
  List<String> _monthKeys = [];

  @override
  void initState() {
    super.initState();
    _loadDaftar();
  }

  Future<void> _loadDaftar() async {
    final phone = ref.read(appStateProvider).userPhone;
    if (phone == null) return;

    try {
      setState(() => isLoading = true);

      final data = await supabase
          .from('daftar')
          .select()
          .eq('customer_phone', phone)
          .maybeSingle();

      List<Map<String, dynamic>> txList = [];
      if (data != null) {
        final tx = await supabase
            .from('daftar_transactions')
            .select()
            .eq('daftar_id', data['id'])
            .order('created_at', ascending: false)
            .limit(50);
        txList = List<Map<String, dynamic>>.from(tx);
      }

      // استخراج الأشهر
      final Set<String> months = {};
      for (final tx in txList) {
        final dt = DateTime.tryParse(tx['created_at'].toString())?.toLocal();
        if (dt != null) {
          months.add('${dt.year}-${dt.month.toString().padLeft(2, '0')}');
        }
      }
      final sorted = months.toList()..sort((a, b) => b.compareTo(a));
      final now = DateTime.now();
      final currentKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      _monthKeys = sorted;
      _selectedMonthKey = sorted.contains(currentKey)
          ? currentKey
          : (sorted.isNotEmpty ? sorted.first : currentKey);

      if (mounted) {
        setState(() {
          daftar = data;
          transactions = txList;
          hasApplied = data != null;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Load daftar error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _applyForDaftar() async {
    final phone = ref.read(appStateProvider).userPhone;
    final marketId = ref.read(appStateProvider).marketId;
    final marketName = ref.read(appStateProvider).marketName;
    final userName = await _getUserName(phone!);

    if (marketId == null) {
      AppNotification.warning(context, "الرجاء اختيار متجر أولاً");
      return;
    }

    try {
      await supabase.from('daftar').insert({
        'customer_phone': phone,
        'market_id': marketId,
        'market_name': marketName,
        'customer_name': userName,
        'status': 'pending',
        'credit_limit': 300,
        'current_balance': 0,
      });

      AppNotification.success(context, "✅ تم إرسال طلب الانضمام للدفتر");
      _loadDaftar();
    } catch (e) {
      if (e.toString().contains('unique')) {
        AppNotification.warning(context, "لديك دفتر مسجل مسبقاً");
      } else {
        AppNotification.error(context, "حدث خطأ: $e");
      }
    }
  }

  Future<String?> _getUserName(String phone) async {
    try {
      final data = await supabase
          .from('users')
          .select('name')
          .eq('phone', phone)
          .maybeSingle();
      return data?['name'];
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    if (_selectedMonthKey == null) return transactions;
    return transactions.where((tx) {
      final dt = DateTime.tryParse(tx['created_at'].toString())?.toLocal();
      if (dt == null) return false;
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}' == _selectedMonthKey;
    }).toList();
  }

  Map<String, double> get _monthSummary {
    double orders = 0, payments = 0;
    for (final tx in _filteredTransactions) {
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
      if (tx['type'] == 'order') {
        orders += amount;
      } else {
        payments += amount;
      }
    }
    return {'orders': orders, 'payments': payments};
  }

  String _statusText(String status) {
    switch (status) {
      case 'pending':
        return 'بانتظار موافقة التاجر ⏳';
      case 'approved':
        return 'نشط ✅';
      case 'frozen':
        return 'مجمد ❄️';
      case 'rejected':
        return 'مرفوض ❌';
      default:
        return status;
    }
  }

  String _formatDate(String? dt) {
    if (dt == null) return '-';
    final d = DateTime.tryParse(dt)?.toLocal();
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
    return '${d.day} ${months[d.month]}';
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
          "دفتري 📒",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDaftar,
              color: _daftar,
              child: daftar == null ? _buildApplyView() : _buildDaftarView(),
            ),
    );
  }

  // ══════════════════════════════════════
  // طلب الانضمام
  // ══════════════════════════════════════
  Widget _buildApplyView() {
    final marketName = ref.read(appStateProvider).marketName;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _daftar.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.book_outlined, color: _daftar, size: 50),
          ),
          const SizedBox(height: 20),
          const Text(
            "دفتر البقالة الرقمي",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "اشتر الآن وادفع في نهاية الشهر\nبنفس فكرة دفتر البقالة القديم — لكن رقمياً",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 30),

          // مميزات
          _buildFeature(Icons.shopping_cart_outlined, "اطلب بدون دفع فوري"),
          _buildFeature(
            Icons.calendar_today_outlined,
            "السداد في 28 من كل شهر",
          ),
          _buildFeature(
            Icons.receipt_long_outlined,
            "كشف حساب واضح لكل معاملة",
          ),
          _buildFeature(Icons.verified_outlined, "يحتاج موافقة التاجر"),

          const SizedBox(height: 30),

          if (marketName != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _daftar.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _daftar.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    marketName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _daftar,
                    ),
                  ),
                  const Text(
                    "المتجر المختار",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MarketsScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.arrow_back_ios, size: 14, color: Colors.orange),
                    Text(
                      "اختر متجراً أولاً",
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(Icons.store_outlined, color: Colors.orange),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _daftar,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: marketName != null ? _applyForDaftar : null,
              child: const Text(
                "طلب الانضمام للدفتر",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Spacer(),
          Text(
            text,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(width: 10),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _daftar.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _daftar, size: 18),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // عرض الدفتر
  // ══════════════════════════════════════
  Widget _buildDaftarView() {
    final status = daftar!['status'] ?? 'pending';
    final balance = (daftar!['current_balance'] as num?)?.toDouble() ?? 0;
    final limit = (daftar!['credit_limit'] as num?)?.toDouble() ?? 300;
    final remaining = limit - balance;
    final progress = limit > 0 ? (balance / limit).clamp(0.0, 1.0) : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── بطاقة الرصيد ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusText(status),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  const Text(
                    "📒 دفتري",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                daftar!['market_name'] ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${remaining.toStringAsFixed(1)} ﷼",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const Text(
                        "متبقي",
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${balance.toStringAsFixed(1)} ﷼",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        "الرصيد الحالي",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // شريط التقدم
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  color: progress > 0.8 ? Colors.red[300] : Colors.white,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "الحد: ${limit.toStringAsFixed(0)} ﷼",
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  Text(
                    "السداد في اليوم 28 من كل شهر",
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── تبويبات الأشهر ──
        if (_monthKeys.isNotEmpty) ...[
          const Align(
            alignment: Alignment.centerRight,
            child: Text('الأشهر',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              reverse: true,
              physics: const BouncingScrollPhysics(),
              itemCount: _monthKeys.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final key = _monthKeys[i];
                final isSelected = key == _selectedMonthKey;
                final parts = key.split('-');
                final month = int.parse(parts[1]);
                final year = int.parse(parts[0]);
                const names = ['','يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
                final now = DateTime.now();
                final currentKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
                final label = key == currentKey ? 'هذا الشهر' : (year == now.year ? names[month] : '${names[month]} $year');
                return GestureDetector(
                  onTap: () => setState(() => _selectedMonthKey = key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? _daftar : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? _daftar : Colors.grey.shade200),
                      boxShadow: isSelected ? [BoxShadow(color: _daftar.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0,3))] : [],
                    ),
                    child: Text(label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[600],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      )),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // ── ملخص الشهر ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0,2))],
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(child: Column(children: [
                  const Icon(Icons.shopping_bag_outlined, color: Colors.red, size: 20),
                  const SizedBox(height: 4),
                  Text('${_monthSummary['orders']!.toInt()} ﷼',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 14)),
                  Text('الطلبات', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                ])),
                Container(width: 1, height: 40, color: Colors.grey[200]),
                Expanded(child: Column(children: [
                  Icon(Icons.payments_outlined, color: _primary, size: 20),
                  const SizedBox(height: 4),
                  Text('${_monthSummary['payments']!.toInt()} ﷼',
                    style: TextStyle(color: _primary, fontWeight: FontWeight.w900, fontSize: 14)),
                  Text('المدفوع', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                ])),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // تنبيه التجميد
        if (status == 'frozen')
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    "دفترك مجمد — تواصل مع التاجر لتأكيد السداد",
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.ac_unit, color: Colors.blue),
              ],
            ),
          ),

        // تنبيه الاقتراب من الحد
        if (status == 'approved' && progress > 0.8)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "تبقى لك ${remaining.toStringAsFixed(1)} ﷼ فقط في دفترك",
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.warning_outlined, color: Colors.orange),
              ],
            ),
          ),

        // ── المعاملات ──
        const Align(
          alignment: Alignment.centerRight,
          child: Text(
            "سجل المعاملات",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 10),

        ...(_filteredTransactions.isEmpty
            ? [Center(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('لا توجد معاملات في هذا الشهر',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14))))]
            : _filteredTransactions.map((tx) => _buildTransactionItem(tx)).toList()),
      ],
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final isDebit = tx['type'] == 'order';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
    final amountStr = amount % 1 == 0
        ? amount.toInt().toString()
        : amount.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // المبلغ
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDebit ? "+ $amountStr ﷼" : "- $amountStr ﷼",
                style: TextStyle(
                  color: isDebit ? Colors.red : _primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              Text(
                _formatDate(tx['created_at']),
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          // النوع والملاحظة
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isDebit ? "طلب" : "سداد",
                style: TextStyle(
                  color: isDebit ? Colors.red : _primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (tx['note'] != null && tx['note'].toString().isNotEmpty)
                Text(
                  tx['note'],
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDebit
                  ? Colors.red.withValues(alpha: 0.1)
                  : _primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDebit ? Icons.shopping_bag_outlined : Icons.payments_outlined,
              color: isDebit ? Colors.red : _primary,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
