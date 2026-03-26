import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../../../core/state/providers.dart';
import '../../../core/utils/app_notification.dart';
import '../../../core/services/auth_storage.dart';

class NearbyMarketsSheet extends ConsumerStatefulWidget {
  const NearbyMarketsSheet({super.key});

  @override
  ConsumerState<NearbyMarketsSheet> createState() => _NearbyMarketsSheetState();
}

class _NearbyMarketsSheetState extends ConsumerState<NearbyMarketsSheet> {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> markets = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _calcDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final data = await supabase
          .from('markets')
          .select('id, name, neighborhood_name, lat, lng, status')
          .eq('status', 'active');

      final list = List<Map<String, dynamic>>.from(data);

      // جلب موقع المستخدم
      double? userLat;
      double? userLng;
      try {
        final phone = ref.read(appStateProvider).userPhone;
        if (phone != null) {
          final saved = await supabase
              .from('addresses')
              .select('lat, lng')
              .eq('phone', phone)
              .maybeSingle();
          if (saved != null && saved['lat'] != null) {
            userLat = (saved['lat'] as num).toDouble();
            userLng = (saved['lng'] as num).toDouble();
          }
        }
      } catch (_) {}

      // إضافة المسافة
      final result = list.map((m) {
        double dist = 0;
        if (userLat != null && userLng != null) {
          final lat = (m['lat'] as num?)?.toDouble();
          final lng = (m['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            dist = _calcDistance(userLat, userLng, lat, lng);
          }
        }
        return {...m, 'distance': dist};
      }).toList();

      result.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );

      if (mounted) {
        setState(() {
          markets = List<Map<String, dynamic>>.from(result);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("NearbyMarketsSheet error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _select(Map<String, dynamic> market) async {
    final notifier = ref.read(appStateProvider.notifier);
    final marketId = market['id'] as String;
    final marketName = market['name']?.toString() ?? '';

    // ✅ حفظ في الـ State
    notifier.setMarket(marketId, marketName);
    notifier.loadInitialData();

    // ✅ حفظ في SharedPreferences للجلسات القادمة
    try {
      await AuthStorage().saveUserSelection(
        neighborhoodId: '',
        marketId: marketId,
        marketName: marketName,
      );
    } catch (e) {
      debugPrint("Save market error: $e");
    }

    if (!mounted) return;
    Navigator.pop(context, marketName);
    AppNotification.success(context, "✅ تم اختيار $marketName");
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── شريط السحب ──
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // ── العنوان ──
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "اختر بقالتك",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF004D40),
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.store_outlined, color: Color(0xFF004D40)),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── المحتوى ──
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Color(0xFF004D40)),
            )
          else if (markets.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                "لا توجد بقالات متاحة حالياً",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: markets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final m = markets[i];
                  final dist = m['distance'] as double;
                  final distStr = dist > 0
                      ? (dist < 1
                            ? "${(dist * 1000).toInt()} م"
                            : "${dist.toStringAsFixed(1)} كم")
                      : "";
                  final isSelected =
                      ref.read(appStateProvider).marketId == m['id'];

                  return Material(
                    color: isSelected
                        ? _primary.withValues(alpha: 0.08)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _select(m),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            // زر الاختيار أو علامة صح
                            isSelected
                                ? const Icon(
                                    Icons.check_circle,
                                    color: _primary,
                                    size: 22,
                                  )
                                : const Icon(
                                    Icons.radio_button_unchecked,
                                    color: Colors.grey,
                                    size: 22,
                                  ),
                            const SizedBox(width: 10),

                            // معلومات المتجر
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    m['name']?.toString() ?? '',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isSelected
                                          ? _primaryDark
                                          : Colors.black87,
                                    ),
                                  ),
                                  if (m['neighborhood_name'] != null &&
                                      m['neighborhood_name']
                                          .toString()
                                          .isNotEmpty)
                                    Text(
                                      m['neighborhood_name'],
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (distStr.isNotEmpty)
                                    Text(
                                      distStr,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        color: _primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),

                            // أيقونة
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _primary.withValues(alpha: 0.1)
                                    : const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.store_outlined,
                                color: isSelected ? _primary : _primaryDark,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
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
