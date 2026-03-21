import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/state/providers.dart';

class EditLocationScreen extends ConsumerStatefulWidget {
  const EditLocationScreen({super.key});

  @override
  ConsumerState<EditLocationScreen> createState() => _EditLocationScreenState();
}

class _EditLocationScreenState extends ConsumerState<EditLocationScreen> {
  /// 📍 البيانات من القاعدة
  List<Map<String, dynamic>> neighborhoods = [];
  List<Map<String, dynamic>> markets = [];

  /// 📍 الاختيارات
  String? selectedNeighborhoodId;
  String? selectedNeighborhoodName;

  String? selectedMarketId;
  String? selectedMarketName;

  /// 🔄 تحميل الأحياء
  Future<void> loadNeighborhoods() async {
    try {
      final data = await Supabase.instance.client
          .from('neighborhoods')
          .select();

      if (!mounted) return;

      setState(() {
        neighborhoods = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint("Load neighborhoods error: $e");
    }
  }

  /// 🔄 تحميل الماركتات حسب الحي
  Future<void> loadMarkets(String neighborhoodId) async {
    try {
      final data = await Supabase.instance.client
          .from('markets')
          .select()
          .eq('neighborhood_id', neighborhoodId);

      if (!mounted) return;

      setState(() {
        markets = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint("Load markets error: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    loadNeighborhoods();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("موقعي")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            /// 📍 اختيار الحي
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "الحي"),
              items: neighborhoods.map((n) {
                return DropdownMenuItem<String>(
                  value: n['id'] as String,
                  child: Text(n['name'] ?? ""),
                );
              }).toList(),
              onChanged: (value) async {
                final selected = neighborhoods.firstWhere(
                  (n) => n['id'] == value,
                );

                setState(() {
                  selectedNeighborhoodId = selected['id'];
                  selectedNeighborhoodName = selected['name'];
                  selectedMarketId = null;
                });

                await loadMarkets(selectedNeighborhoodId!);
              },
            ),

            const SizedBox(height: 15),

            /// 🏪 اختيار المتجر
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "المتجر"),
              items: markets.map((m) {
                return DropdownMenuItem<String>(
                  value: m['id'] as String,
                  child: Text(m['name'] ?? ""),
                );
              }).toList(),
              onChanged: (value) {
                final selected = markets.firstWhere((m) => m['id'] == value);

                setState(() {
                  selectedMarketId = selected['id'];
                  selectedMarketName = selected['name'];
                });
              },
            ),

            const SizedBox(height: 30),

            /// 💾 حفظ
            ElevatedButton(
              onPressed: () async {
                final notifier = ref.read(appStateProvider.notifier);
                final phone = ref.read(appStateProvider).userPhone;
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                if (phone == null) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text("المستخدم غير معروف")),
                  );
                  return;
                }

                try {
                  /// 🔥 حفظ في Supabase
                  await Supabase.instance.client
                      .from('users')
                      .update({
                        "neighborhood_id": selectedNeighborhoodId,
                        "market_id": selectedMarketId,
                        "neighborhood_name": selectedNeighborhoodName,
                        "market_name": selectedMarketName,
                      })
                      .eq('phone', phone);

                  /// 🔥 تحديث الحالة
                  notifier.setNeighborhood(
                    selectedNeighborhoodId ?? "",
                    selectedNeighborhoodName ?? state.neighborhoodName ?? "",
                  );

                  notifier.setMarket(
                    selectedMarketId ?? "",
                    selectedMarketName ?? state.marketName ?? "",
                  );

                  if (!mounted) return;

                  navigator.pop();

                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text("تم حفظ الموقع بنجاح"),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  debugPrint("Save location error: $e");

                  if (!mounted) return;

                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text("حدث خطأ أثناء الحفظ"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text("حفظ"),
            ),
          ],
        ),
      ),
    );
  }
}
