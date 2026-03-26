import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_storage.dart';
import '../../../core/utils/app_notification.dart';

class DaftarManagementScreen extends StatefulWidget {
  const DaftarManagementScreen({super.key});

  @override
  State<DaftarManagementScreen> createState() => _DaftarManagementScreenState();
}

class _DaftarManagementScreenState extends State<DaftarManagementScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);
  static const Color _daftar = Color(0xFF1565C0);

  final supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> pendingList = [];
  List<Map<String, dynamic>> approvedList = [];
  List<Map<String, dynamic>> frozenList = [];
  String? marketId;
  bool isLoading = true;

  // إجماليات
  double totalBalance = 0;
  int totalClients = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => isLoading = true);
      final phone = await AuthStorage().getPhone();
      if (phone == null) return;

      final market = await supabase
          .from('markets')
          .select()
          .eq('owner_phone', phone)
          .maybeSingle();
      if (market == null) return;

      marketId = market['id'];

      final data = await supabase
          .from('daftar')
          .select()
          .eq('market_id', marketId!)
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(data);

      if (mounted) {
        setState(() {
          pendingList = list.where((d) => d['status'] == 'pending').toList();
          approvedList = list.where((d) => d['status'] == 'approved').toList();
          frozenList = list.where((d) => d['status'] == 'frozen').toList();
          totalClients = approvedList.length + frozenList.length;
          totalBalance = list.fold(
            0,
            (sum, d) => sum + ((d['current_balance'] as num?)?.toDouble() ?? 0),
          );
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Load daftar error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ── اعتماد العميل ──
  Future<void> _approve(Map<String, dynamic> daftar) async {
    final limitController = TextEditingController(text: '300');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "اعتماد ${daftar['customer_name'] ?? daftar['customer_phone']}",
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("حدد الحد الائتماني ﷼", textAlign: TextAlign.right),
            const SizedBox(height: 12),
            TextField(
              controller: limitController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _daftar, width: 1.5),
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
              backgroundColor: _daftar,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("اعتماد"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final limit = double.tryParse(limitController.text.trim()) ?? 300;

    try {
      await supabase
          .from('daftar')
          .update({'status': 'approved', 'credit_limit': limit})
          .eq('id', daftar['id']);

      AppNotification.success(
        context,
        "✅ تم اعتماد ${daftar['customer_name'] ?? ''}",
      );
      _loadData();
    } catch (e) {
      AppNotification.error(context, "حدث خطأ: $e");
    }
  }

  // ── رفض العميل ──
  Future<void> _reject(Map<String, dynamic> daftar) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("رفض الطلب"),
        content: const Text("هل تريد رفض طلب الانضمام؟"),
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

    try {
      await supabase
          .from('daftar')
          .update({'status': 'rejected'})
          .eq('id', daftar['id']);
      AppNotification.info(context, "تم رفض الطلب");
      _loadData();
    } catch (e) {
      AppNotification.error(context, "حدث خطأ: $e");
    }
  }

  // ── تأكيد السداد ──
  Future<void> _confirmPayment(Map<String, dynamic> daftar) async {
    final balance = (daftar['current_balance'] as num?)?.toDouble() ?? 0;
    final balanceStr = balance % 1 == 0
        ? balance.toInt().toString()
        : balance.toStringAsFixed(1);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("تأكيد سداد ${daftar['customer_name'] ?? ''}"),
        content: Text(
          "المبلغ المستحق: $balanceStr ﷼\nهل تأكد استلام المبلغ كاملاً؟",
          textAlign: TextAlign.right,
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
            child: const Text("تأكيد السداد"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // تسجيل معاملة السداد
      await supabase.from('daftar_transactions').insert({
        'daftar_id': daftar['id'],
        'amount': balance,
        'type': 'payment',
        'note': 'سداد شهري مؤكد من التاجر',
      });

      // تصفير الرصيد وفك التجميد
      await supabase
          .from('daftar')
          .update({
            'current_balance': 0,
            'status': 'approved',
            'last_payment_date': DateTime.now().toIso8601String(),
            'frozen_at': null,
          })
          .eq('id', daftar['id']);

      AppNotification.success(context, "✅ تم تأكيد السداد وفك التجميد");
      _loadData();
    } catch (e) {
      AppNotification.error(context, "حدث خطأ: $e");
    }
  }

  // ── تعديل الحد ──
  Future<void> _editLimit(Map<String, dynamic> daftar) async {
    final controller = TextEditingController(
      text: daftar['credit_limit']?.toString() ?? '300',
    );

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("تعديل الحد الائتماني"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            labelText: "الحد الائتماني ﷼",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryDark,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newLimit = double.tryParse(controller.text.trim());
              if (newLimit == null) return;
              await supabase
                  .from('daftar')
                  .update({'credit_limit': newLimit})
                  .eq('id', daftar['id']);
              if (!mounted) return;
              Navigator.pop(context);
              AppNotification.success(context, "تم تحديث الحد الائتماني");
              _loadData();
            },
            child: const Text("حفظ"),
          ),
        ],
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
          "إدارة الدفتر 📒",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _daftar,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _daftar,
          tabs: [
            Tab(text: "طلبات (${pendingList.length})"),
            Tab(text: "نشط (${approvedList.length})"),
            Tab(text: "مجمد (${frozenList.length})"),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── إجماليات ──
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStat(
                          "${totalBalance.toStringAsFixed(1)} ﷼",
                          "إجمالي الذمم",
                          Icons.account_balance_wallet_outlined,
                          _daftar,
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[200]),
                      Expanded(
                        child: _buildStat(
                          "$totalClients",
                          "عملاء نشطون",
                          Icons.people_outline,
                          _primary,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(pendingList, 'pending'),
                      _buildList(approvedList, 'approved'),
                      _buildList(frozenList, 'frozen'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStat(String value, String label, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildList(List<Map<String, dynamic>> list, String type) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              "لا يوجد عملاء",
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _daftar,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildClientCard(list[i], type),
      ),
    );
  }

  Widget _buildClientCard(Map<String, dynamic> daftar, String type) {
    final balance = (daftar['current_balance'] as num?)?.toDouble() ?? 0;
    final limit = (daftar['credit_limit'] as num?)?.toDouble() ?? 300;
    final progress = limit > 0 ? (balance / limit).clamp(0.0, 1.0) : 0.0;
    final name = daftar['customer_name'] ?? daftar['customer_phone'] ?? '';

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
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // الاسم والرصيد
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // الرصيد
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${balance.toStringAsFixed(1)} ﷼",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: balance > 0 ? Colors.red : _primary,
                      ),
                    ),
                    Text(
                      "من ${limit.toStringAsFixed(0)} ﷼",
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                  ],
                ),
                // الاسم والهاتف
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      daftar['customer_phone'] ?? '',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),

            if (type == 'approved') ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[100],
                  color: progress > 0.8 ? Colors.red : _daftar,
                  minHeight: 5,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // الأزرار
            if (type == 'pending')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reject(daftar),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "رفض",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => _approve(daftar),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _daftar,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("اعتماد"),
                    ),
                  ),
                ],
              )
            else if (type == 'approved')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editLimit(daftar),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: Colors.grey,
                      ),
                      label: const Text(
                        "تعديل الحد",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              )
            else if (type == 'frozen')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmPayment(daftar),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text("تأكيد السداد"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
