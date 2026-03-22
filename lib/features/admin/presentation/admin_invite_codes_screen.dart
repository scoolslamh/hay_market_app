import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/app_notification.dart';

class AdminInviteCodesScreen extends StatefulWidget {
  const AdminInviteCodesScreen({super.key});
  @override
  State<AdminInviteCodesScreen> createState() => _AdminInviteCodesScreenState();
}

class _AdminInviteCodesScreenState extends State<AdminInviteCodesScreen> {
  static const Color _primaryDark = Color(0xFF004D40);
  static const Color _primary = Color(0xFF4CAF50);

  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> codes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    final data = await supabase
        .from('invite_codes')
        .select()
        .order('created_at', ascending: false);
    if (mounted) {
      setState(() {
        codes = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    }
  }

  Future<void> _generateCode() async {
    final ts = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final code = "MARKET-$ts";
    await supabase.from('invite_codes').insert({
      'code': code,
      'created_by': 'admin',
    });
    _load();
    if (mounted) {
      AppNotification.success(context, "✅ تم إنشاء الكود");
    }
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
          "أكواد الدعوة",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _generateCode,
            child: const Text(
              "+ كود جديد",
              style: TextStyle(
                color: _primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: codes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final code = codes[i];
                final isUsed = code['is_used'] as bool? ?? false;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isUsed
                          ? Colors.grey.shade200
                          : _primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isUsed
                                ? "مستخدم من: ${code['used_by'] ?? '-'}"
                                : "متاح",
                            style: TextStyle(
                              color: isUsed ? Colors.grey : _primary,
                              fontSize: 11,
                            ),
                          ),
                          if (isUsed)
                            const Icon(
                              Icons.check_circle,
                              color: Colors.grey,
                              size: 16,
                            )
                          else
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: code['code']),
                                );
                                AppNotification.info(context, "تم نسخ الكود");
                              },
                              child: const Icon(
                                Icons.copy,
                                color: Color(0xFF004D40),
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        code['code'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: isUsed ? Colors.grey : _primaryDark,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
