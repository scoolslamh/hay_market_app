import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/market.dart';
import '../../../core/services/market_service.dart';
import '../../../core/state/providers.dart';
import '../../../core/navigation/main_navigation.dart';

class MarketsScreen extends ConsumerStatefulWidget {
  const MarketsScreen({super.key});

  @override
  ConsumerState<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends ConsumerState<MarketsScreen> {
  final marketService = MarketService();

  List<Market> markets = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadMarkets();
  }

  Future<void> loadMarkets() async {
    final neighborhoodId = ref.read(appStateProvider).neighborhoodId;

    if (neighborhoodId == null) {
      setState(() => isLoading = false);
      return;
    }

    final data = await marketService.getMarketsByNeighborhood(neighborhoodId);

    setState(() {
      markets = data;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("اختر الماركت")),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : markets.isEmpty
          ? const Center(child: Text("لا توجد ماركتات في هذا الحي"))
          : ListView.builder(
              itemCount: markets.length,
              itemBuilder: (context, index) {
                final market = markets[index];

                return Card(
                  margin: const EdgeInsets.all(10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: ListTile(
                    leading: market.image != null && market.image!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              market.image!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.store, size: 40),

                    title: Text(
                      market.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    trailing: const Icon(Icons.arrow_forward_ios),

                    onTap: () {
                      /// حفظ الماركت
                      ref
                          .read(appStateProvider.notifier)
                          .setMarket(market.id, market.name);

                      /// فتح التطبيق الرئيسي مع الشريط السفلي
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MainNavigation(),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
