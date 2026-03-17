import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart'; // تأكد من وجود هذه المكتبة في pubspec.yaml

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng selectedLocation = const LatLng(24.7136, 46.6753); // الرياض افتراضياً
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _determinePosition(); // طلب الموقع عند فتح الشاشة
  }

  // دالة لطلب الإذن والحصول على الموقع الحالي
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    // الحصول على الموقع وتحريك الكاميرا إليه
    Position position = await Geolocator.getCurrentPosition();
    LatLng currentLatLng = LatLng(position.latitude, position.longitude);

    setState(() {
      selectedLocation = currentLatLng;
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(currentLatLng, 15),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("اختيار الموقع")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: selectedLocation,
          zoom: 14,
        ),
        myLocationEnabled: true, // إظهار النقطة الزرقاء
        myLocationButtonEnabled: true, // إظهار زر "موقعي"
        onMapCreated: (controller) => _mapController = controller,
        onTap: (location) {
          setState(() {
            selectedLocation = location;
          });
        },
        markers: {
          Marker(
            markerId: const MarkerId("selected"),
            position: selectedLocation,
          ),
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.check),
        onPressed: () {
          Navigator.pop(
            context,
            "${selectedLocation.latitude}, ${selectedLocation.longitude}",
          );
        },
      ),
    );
  }
}
