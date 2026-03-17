import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // تأكد من استيراد سوبابيس

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng selectedLocation = const LatLng(24.7136, 46.6753); // الرياض افتراضياً
  String addressName = "جاري تحديد الموقع...";
  GoogleMapController? _mapController;
  bool _isLoading = false; // لإظهار مؤشر تحميل أثناء الحفظ

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  // طلب الموقع وتحريك الكاميرا وجلب اسم العنوان
  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    LatLng currentLatLng = LatLng(position.latitude, position.longitude);

    _updateLocation(currentLatLng);

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(currentLatLng, 16),
    );
  }

  // تحديث الإحداثيات واسم العنوان معاً
  Future<void> _updateLocation(LatLng location) async {
    setState(() {
      selectedLocation = location;
      addressName = "جاري تحميل العنوان...";
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
        localeIdentifier: "ar",
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          // تنسيق العنوان بشكل مرتب
          addressName =
              "${place.street}, ${place.subLocality}, ${place.locality}";
        });
      }
    } catch (e) {
      setState(() {
        addressName = "تعذر تحديد اسم الشارع";
      });
    }
  }

  // دالة حفظ العنوان في Supabase
  Future<void> _saveAddress() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى تسجيل الدخول لحفظ العنوان")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.from('addresses').insert({
        'user_id': user.id,
        'address_name': addressName,
        'lat': selectedLocation.latitude,
        'lng': selectedLocation.longitude,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم حفظ الموقع في دكان الحي بنجاح")),
        );
        // العودة مع البيانات
        Navigator.pop(context, {
          "lat": selectedLocation.latitude,
          "lng": selectedLocation.longitude,
          "address": addressName,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("خطأ أثناء الحفظ: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تحديد موقع التوصيل")),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: selectedLocation,
              zoom: 14,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onMapCreated: (controller) => _mapController = controller,
            onTap: (location) => _updateLocation(location),
            markers: {
              Marker(
                markerId: const MarkerId("selected"),
                position: selectedLocation,
              ),
            },
          ),
          Positioned(
            bottom: 20,
            left: 10,
            right: 10,
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "عنوان التوصيل المختار:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      addressName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 45),
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _saveAddress,
                            child: const Text("تأكيد وحفظ الموقع"),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
