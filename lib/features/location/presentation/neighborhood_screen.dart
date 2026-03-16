import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/state/providers.dart';
import '../../../core/services/local_storage_service.dart';
import '../../markets/presentation/markets_screen.dart';

class NeighborhoodScreen extends ConsumerStatefulWidget {
  const NeighborhoodScreen({super.key});

  @override
  ConsumerState<NeighborhoodScreen> createState() => _NeighborhoodScreenState();
}

class _NeighborhoodScreenState extends ConsumerState<NeighborhoodScreen> {
  final supabase = Supabase.instance.client;
  final storage = LocalStorageService();

  List<Map<String, dynamic>> neighborhoods = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadNeighborhoods();
  }

  Future<void> loadNeighborhoods() async {
    final data = await supabase.from('neighborhoods').select();

    setState(() {
      neighborhoods = List<Map<String, dynamic>>.from(data);
      isLoading = false;
    });
  }

  Future<void> selectNeighborhood(Map<String, dynamic> neighborhood) async {
    /// حفظ الحي في AppState
    ref
        .read(appStateProvider.notifier)
        .setNeighborhood(neighborhood["id"], neighborhood["name"]);

    /// حفظ الحي في الجهاز
    await storage.saveNeighborhood(neighborhood["id"]);

    /// الانتقال لصفحة الماركتات
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MarketsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("اختر الحي")),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: neighborhoods.length,
              itemBuilder: (context, index) {
                final neighborhood = neighborhoods[index];

                return Card(
                  margin: const EdgeInsets.all(10),
                  child: ListTile(
                    title: Text(neighborhood["name"]),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => selectNeighborhood(neighborhood),
                  ),
                );
              },
            ),
    );
  }
}
