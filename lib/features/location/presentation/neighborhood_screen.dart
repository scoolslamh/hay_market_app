import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/state/providers.dart';
import '../../../core/services/auth_storage.dart'; // ✅ التخزين الموحد
import '../../markets/presentation/markets_screen.dart';

class NeighborhoodScreen extends ConsumerStatefulWidget {
  const NeighborhoodScreen({super.key});

  @override
  ConsumerState<NeighborhoodScreen> createState() => _NeighborhoodScreenState();
}

class _NeighborhoodScreenState extends ConsumerState<NeighborhoodScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> neighborhoods = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadNeighborhoods();
  }

  Future<void> loadNeighborhoods() async {
    try {
      final data = await supabase.from('neighborhoods').select();

      setState(() {
        neighborhoods = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("حدث خطأ أثناء تحميل الأحياء")),
      );
    }
  }

  Future<void> selectNeighborhood(Map<String, dynamic> neighborhood) async {
    try {
      /// ✅ حفظ في AppState
      ref
          .read(appStateProvider.notifier)
          .setNeighborhood(neighborhood["id"], neighborhood["name"]);

      /// 🔥 حفظ في الجهاز (بدون ماركت حالياً)
      await AuthStorage().saveUserSelection(
        neighborhoodId: neighborhood["id"],
        marketId: null,
        neighborhoodName: neighborhood["name"],
        marketName: null,
      );

      if (!mounted) return;

      /// الانتقال للماركت
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MarketsScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("حدث خطأ أثناء اختيار الحي")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("اختر الحي"), centerTitle: true),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : neighborhoods.isEmpty
          ? const Center(child: Text("لا توجد أحياء متاحة"))
          : ListView.builder(
              itemCount: neighborhoods.length,
              itemBuilder: (context, index) {
                final neighborhood = neighborhoods[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.green),

                    title: Text(
                      neighborhood["name"],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),

                    onTap: () => selectNeighborhood(neighborhood),
                  ),
                );
              },
            ),
    );
  }
}
