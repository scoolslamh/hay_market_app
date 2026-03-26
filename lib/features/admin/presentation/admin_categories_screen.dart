// ══════════════════════════════════════
// admin_categories_screen.dart
// ══════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/app_notification.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});
  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  static const Color _primaryDark = Color(0xFF004D40);
  static const Color _primary = Color(0xFF4CAF50);
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> categories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    final data = await supabase.from('categories').select().order('sort_order');
    if (mounted) {
      setState(() {
        categories = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    }
  }

  void _addCategory() {
    final nameCtrl = TextEditingController();
    final emojiCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "إضافة قسم جديد",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emojiCtrl,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 30),
                decoration: InputDecoration(
                  labelText: "الإيموجي",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: "اسم القسم",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    await supabase.from('categories').insert({
                      'name': nameCtrl.text.trim(),
                      'emoji': emojiCtrl.text.trim(),
                      'sort_order': categories.length + 1,
                    });
                    if (!mounted) return;
                    Navigator.pop(context);
                    _load();
                    AppNotification.success(context, "✅ تم إضافة القسم");
                  },
                  child: const Text("إضافة"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCategory(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("حذف القسم"),
        content: Text("هل تريد حذف قسم \"$name\"؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("حذف", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await supabase.from('categories').delete().eq('id', id);
    _load();
    if (mounted) AppNotification.info(context, "تم حذف القسم");
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
          "إدارة الأقسام",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryDark,
        onPressed: _addCategory,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : categories.isEmpty
          ? const Center(child: Text("لا توجد أقسام"))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final cat = categories[i];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Text(
                      cat['emoji'] ?? '📦',
                      style: const TextStyle(fontSize: 28),
                    ),
                    title: Text(
                      cat['name'] ?? '',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteCategory(cat['id'], cat['name']),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
