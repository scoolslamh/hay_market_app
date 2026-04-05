import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DaftarClientDetailScreen extends StatefulWidget {
  final Map<String, dynamic> daftar;
  const DaftarClientDetailScreen({super.key, required this.daftar});

  @override
  State<DaftarClientDetailScreen> createState() =>
      _DaftarClientDetailScreenState();
}

class _DaftarClientDetailScreenState
    extends State<DaftarClientDetailScreen> {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _daftar = Color(0xFF1565C0);

  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> allTransactions = [];
  bool isLoading = true;
  String? selectedMonthKey;
  List<String> monthKeys = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => isLoading = true);
    try {
      final data = await supabase
          .from('daftar_transactions')
          .select()
          .eq('daftar_id', widget.daftar['id'])
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(data);

      final Set<String> months = {};
      for (final tx in list) {
        final dt =
            DateTime.tryParse(tx['created_at'].toString())?.toLocal();
        if (dt != null) {
          months.add(
              '${dt.year}-${dt.month.toString().padLeft(2, '0')}');
        }
      }
      final sorted = months.toList()..sort((a, b) => b.compareTo(a));

      final now = DateTime.now();
      final currentKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';

      if (mounted) {
        setState(() {
          allTransactions = list;
          monthKeys = sorted;
          selectedMonthKey = sorted.contains(currentKey)
              ? currentKey
              : (sorted.isNotEmpty ? sorted.first : currentKey);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Load client transactions error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _monthTxs {
    if (selectedMonthKey == null) return [];
    return allTransactions.where((tx) {
      final dt =
          DateTime.tryParse(tx['created_at'].toString())?.toLocal();
      if (dt == null) return false;
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}' ==
          selectedMonthKey;
    }).toList();
  }

  Map<String, double> get _summary {
    double orders = 0, payments = 0;
    for (final tx in _monthTxs) {
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
      if (tx['type'] == 'order') {
        orders += amount;
      } else {
        payments += amount;
      }
    }
    return {'orders': orders, 'payments': payments, 'net': orders - payments};
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    const names = [
      '',
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    final now = DateTime.now();
    final currentKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    if (key == currentKey) return 'هذا الشهر';
    if (year == now.year) return names[month];
    return '${names[month]} $year';
  }

  String _fmtDate(String? dt) {
    if (dt == null) return '-';
    final d = DateTime.tryParse(dt)?.toLocal();
    if (d == null) return '-';
    const names = [
      '',
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return '${d.day} ${names[d.month]}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final name = widget.daftar['customer_name'] ??
        widget.daftar['customer_phone'] ??
        '';
    final balance =
        (widget.daftar['current_balance'] as num?)?.toDouble() ?? 0;
    final limit =
        (widget.daftar['credit_limit'] as num?)?.toDouble() ?? 300;
    final summary = _summary;
    final txs = _monthTxs;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: _daftar, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87),
            ),
            Text(
              widget.daftar['customer_phone'] ?? '',
              style:
                  const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade100, height: 1),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _daftar))
          : RefreshIndicator(
              onRefresh: _loadTransactions,
              color: _daftar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── بطاقة الرصيد الكلي ──
                  _buildAccountCard(balance, limit),
                  const SizedBox(height: 16),

                  // ── تبويبات الأشهر ──
                  if (monthKeys.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text('الأشهر',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black54)),
                    ),
                    const SizedBox(height: 8),
                    _buildMonthTabs(),
                    const SizedBox(height: 16),
                  ],

                  // ── ملخص الشهر ──
                  _buildMonthlySummary(summary),
                  const SizedBox(height: 16),

                  // ── قائمة المعاملات ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${txs.length} عملية',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                      const Text('المعاملات',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (txs.isEmpty)
                    Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 30),
                        child: Text('لا توجد معاملات في هذا الشهر',
                            style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14)),
                      ),
                    )
                  else
                    ...txs.map((tx) => _buildTxItem(tx)),
                ],
              ),
            ),
    );
  }

  Widget _buildAccountCard(double balance, double limit) {
    final progress =
        limit > 0 ? (balance / limit).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('إجمالي الرصيد الحالي',
              style:
                  TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Text('${_fmt(balance)} ﷼',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الحد: ${_fmt(limit)} ﷼',
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 12)),
              Text('المتبقي: ${_fmt(limit - balance)} ﷼',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor:
                  Colors.white.withValues(alpha: 0.2),
              color: progress > 0.8
                  ? Colors.red[300]
                  : Colors.white,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthTabs() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        physics: const BouncingScrollPhysics(),
        itemCount: monthKeys.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final key = monthKeys[i];
          final isSelected = key == selectedMonthKey;
          return GestureDetector(
            onTap: () => setState(() => selectedMonthKey = key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _daftar : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? _daftar
                      : Colors.grey.shade200,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: _daftar.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ]
                    : [],
              ),
              child: Text(
                _monthLabel(key),
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.grey[600],
                  fontWeight: isSelected
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthlySummary(Map<String, double> summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
              child: _summaryItem('إجمالي الطلبات',
                  _fmt(summary['orders']!), Colors.red,
                  Icons.shopping_bag_outlined)),
          Container(
              width: 1, height: 50, color: Colors.grey[200]),
          Expanded(
              child: _summaryItem('المدفوع',
                  _fmt(summary['payments']!), _primary,
                  Icons.payments_outlined)),
          Container(
              width: 1, height: 50, color: Colors.grey[200]),
          Expanded(
              child: _summaryItem('الصافي',
                  _fmt(summary['net']!), _daftar,
                  Icons.account_balance_outlined)),
        ],
      ),
    );
  }

  Widget _summaryItem(
      String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text('$value ﷼',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 14)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Colors.grey[500], fontSize: 10)),
      ],
    );
  }

  Widget _buildTxItem(Map<String, dynamic> tx) {
    final isOrder = tx['type'] == 'order';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0;

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
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isOrder
                  ? Colors.red.withValues(alpha: 0.1)
                  : _primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOrder
                  ? Icons.shopping_bag_outlined
                  : Icons.payments_outlined,
              color: isOrder ? Colors.red : _primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isOrder ? 'طلب' : 'سداد',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isOrder ? Colors.red : _primary),
                ),
                if (tx['note'] != null &&
                    tx['note'].toString().isNotEmpty)
                  Text(tx['note'],
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isOrder ? '+' : '-'} ${_fmt(amount)} ﷼',
                style: TextStyle(
                    color: isOrder ? Colors.red : _primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15),
              ),
              Text(_fmtDate(tx['created_at']),
                  style: TextStyle(
                      color: Colors.grey[400], fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
