import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/app_notification.dart';

// ══════════════════════════════════════
// admin_users_screen.dart
// ══════════════════════════════════════
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const Color _primaryDark = Color(0xFF004D40);
  static const Color _primary = Color(0xFF4CAF50);

  final supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> filtered = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    final data = await supabase
        .from('users')
        .select()
        .order('created_at', ascending: false);
    if (mounted) {
      setState(() {
        users = List<Map<String, dynamic>>.from(data);
        filtered = users;
        isLoading = false;
      });
    }
  }

  void _search(String q) {
    setState(() {
      filtered = q.isEmpty
          ? users
          : users
                .where(
                  (u) =>
                      (u['name'] ?? '').toLowerCase().contains(
                        q.toLowerCase(),
                      ) ||
                      (u['phone'] ?? '').contains(q),
                )
                .toList();
    });
  }

  Future<void> _toggleBlock(Map<String, dynamic> user) async {
    final isBlocked = user['role'] == 'blocked';
    final newRole = isBlocked ? 'customer' : 'blocked';
    final msg = isBlocked ? "تفعيل الحساب؟" : "حظر الحساب؟";

    final confirm = await showDialog<bool>(
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
              isBlocked ? "تفعيل" : "حظر",
              style: TextStyle(color: isBlocked ? _primary : Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await supabase.from('users').update({'role': newRole}).eq('id', user['id']);
    _load();
    if (mounted) {
      AppNotification.info(
        context,
        isBlocked ? "تم تفعيل الحساب" : "تم حظر الحساب",
      );
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
        title: Text(
          "العملاء (${users.length})",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              textAlign: TextAlign.right,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: "ابحث بالاسم أو الجوال",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final u = filtered[i];
                      final isBlocked = u['role'] == 'blocked';
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: isBlocked
                              ? Border.all(
                                  color: Colors.red.withValues(alpha: 0.3),
                                )
                              : null,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isBlocked
                                ? Colors.red.withValues(alpha: 0.1)
                                : _primary.withValues(alpha: 0.1),
                            child: Text(
                              (u['name'] ?? 'م').substring(0, 1),
                              style: TextStyle(
                                color: isBlocked ? Colors.red : _primaryDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            u['name'] ?? 'مستخدم',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            u['phone'] ?? '',
                            textAlign: TextAlign.right,
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              isBlocked
                                  ? Icons.lock_open_outlined
                                  : Icons.block_outlined,
                              color: isBlocked ? _primary : Colors.red,
                            ),
                            onPressed: () => _toggleBlock(u),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
