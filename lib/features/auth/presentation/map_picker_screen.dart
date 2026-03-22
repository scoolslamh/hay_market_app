import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const MapPickerScreen({super.key, this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF004D40);

  late LatLng selectedLocation;
  String addressName = "اضغط على الخريطة أو استخدم زر موقعي";
  String neighborhood = "";
  String street = "";
  bool isLoadingAddress = false;

  // ✅ كلاهما اختياري
  final TextEditingController _houseController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    selectedLocation = widget.initialLocation ?? const LatLng(24.7136, 46.6753);
    if (widget.initialLocation != null) {
      _updateLocation(selectedLocation);
    }
  }

  @override
  void dispose() {
    _houseController.dispose();
    _detailsController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ✅ زر تحديد الموقع الحالي — واضح للأندرويد
  Future<void> _goToMyLocation() async {
    setState(() => isLoadingAddress = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("فعّل خدمة الموقع في إعدادات الجهاز"),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("اسمح للتطبيق بالوصول للموقع من الإعدادات"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final current = LatLng(position.latitude, position.longitude);

      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(current, 17));

      await _updateLocation(current);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تعذر تحديد موقعك الحالي"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoadingAddress = false);
    }
  }

  Future<void> _updateLocation(LatLng location) async {
    setState(() {
      selectedLocation = location;
      isLoadingAddress = true;
      addressName = "جاري تحميل العنوان...";
    });

    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
        localeIdentifier: "ar",
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        setState(() {
          neighborhood = place.subLocality?.isNotEmpty == true
              ? place.subLocality!
              : place.locality ?? '';

          street = place.thoroughfare?.isNotEmpty == true
              ? place.thoroughfare!
              : place.street ?? '';

          addressName = [
            neighborhood,
            street,
          ].where((s) => s.isNotEmpty).join('، ');

          if (addressName.isEmpty) addressName = "تعذر تحديد العنوان";
        });
      }
    } catch (e) {
      setState(() => addressName = "تعذر تحديد العنوان");
    } finally {
      if (mounted) setState(() => isLoadingAddress = false);
    }
  }

  void _confirm() {
    final parts = [
      if (neighborhood.isNotEmpty) neighborhood,
      if (street.isNotEmpty) street,
      if (_houseController.text.trim().isNotEmpty) _houseController.text.trim(),
      if (_detailsController.text.trim().isNotEmpty)
        _detailsController.text.trim(),
    ];

    final fullAddress = parts.isNotEmpty ? parts.join('، ') : addressName;

    Navigator.pop(context, {
      "lat": selectedLocation.latitude,
      "lng": selectedLocation.longitude,
      "address": fullAddress,
    });
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
          "تحديد موقع التوصيل",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Colors.black87,
          ),
        ),
      ),
      body: Column(
        children: [
          // ══════════════════════════════════════
          // ✅ العنوان أعلى الشاشة دائماً
          // ══════════════════════════════════════
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: isLoadingAddress
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              "جاري تحديد العنوان...",
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _primary,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          addressName,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: neighborhood.isNotEmpty
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: neighborhood.isNotEmpty
                                ? _primaryDark
                                : Colors.grey[500],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: _primary,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[200]),

          // ══════════════════════════════════════
          // الخريطة
          // ══════════════════════════════════════
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: selectedLocation,
                    zoom: 15,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false, // نخفي زر Google
                  onMapCreated: (c) => _mapController = c,
                  onTap: _updateLocation,
                  markers: {
                    Marker(
                      markerId: const MarkerId("selected"),
                      position: selectedLocation,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen,
                      ),
                    ),
                  },
                ),

                // ✅ زر موقعي الحالي — بارز وواضح
                Positioned(
                  top: 16,
                  left: 16,
                  child: GestureDetector(
                    onTap: isLoadingAddress ? null : _goToMyLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryDark,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: isLoadingAddress
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.my_location,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "موقعي الحالي",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ══════════════════════════════════════
          // الحقول وزر التأكيد
          // ══════════════════════════════════════
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 14,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // رقم المنزل — اختياري
                TextField(
                  controller: _houseController,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: "رقم المنزل / العمارة (اختياري)",
                    hintText: "مثال: فيلا 5 أو عمارة B",
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primary, width: 1.5),
                    ),
                    prefixIcon: const Icon(
                      Icons.home_outlined,
                      color: _primaryDark,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // تفاصيل — اختياري
                TextField(
                  controller: _detailsController,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: "تفاصيل إضافية (اختياري)",
                    hintText: "مثال: الدور الثاني، بجانب المسجد...",
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primary, width: 1.5),
                    ),
                    prefixIcon: const Icon(
                      Icons.info_outline,
                      color: _primaryDark,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // زر التأكيد
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: isLoadingAddress ? null : _confirm,
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text(
                      "تأكيد وحفظ الموقع",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
