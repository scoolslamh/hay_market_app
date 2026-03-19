import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/providers.dart';

class EditLocationScreen extends ConsumerStatefulWidget {
  const EditLocationScreen({super.key});

  @override
  ConsumerState<EditLocationScreen> createState() => _EditLocationScreenState();
}

class _EditLocationScreenState extends ConsumerState<EditLocationScreen> {
  String? selectedNeighborhood;
  String? selectedMarket;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("موقعي")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: state.neighborhoodName,
              decoration: const InputDecoration(labelText: "الحي"),
              items: [
                "حي الروابي",
                "حي الشفاء",
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => selectedNeighborhood = val,
            ),

            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: state.marketName,
              decoration: const InputDecoration(labelText: "المتجر"),
              items: [
                "ماركت الخير",
                "ماركت المدينة",
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => selectedMarket = val,
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                final notifier = ref.read(appStateProvider.notifier);

                notifier.setNeighborhood(
                  "1",
                  selectedNeighborhood ?? state.neighborhoodName ?? "",
                );

                notifier.setMarket(
                  "1",
                  selectedMarket ?? state.marketName ?? "",
                );

                Navigator.pop(context);
              },
              child: const Text("حفظ"),
            ),
          ],
        ),
      ),
    );
  }
}
