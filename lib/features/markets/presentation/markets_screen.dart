import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/models/market.dart';
import '../../../core/services/market_service.dart';
import '../../../core/services/auth_storage.dart';
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

  /// 🔥 جلب البقالات حسب موقع المستخدم
  Future<void> loadMarkets() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => isLoading = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition();

      final data = await marketService.getNearbyMarkets(
        position.latitude,
        position.longitude,
      );

      setState(() {
        markets = data;
        isLoading = false;
      });
    } catch (e) {
      print("Location error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("اختر الماركت")),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : markets.isEmpty
          ? const Center(child: Text("لا توجد ماركتات قريبة"))
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

                    onTap: () async {
                      ref
                          .read(appStateProvider.notifier)
                          .setMarket(market.id, market.name);

                      final neighborhoodId = ref
                          .read(appStateProvider)
                          .neighborhoodId;

                      final neighborhoodName = ref
                          .read(appStateProvider)
                          .neighborhoodName;

                      await AuthStorage().saveUserSelection(
                        neighborhoodId: neighborhoodId!,
                        marketId: market.id,
                        neighborhoodName: neighborhoodName,
                        marketName: market.name,
                      );

                      if (!context.mounted) return;

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
