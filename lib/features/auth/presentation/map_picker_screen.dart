import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng selectedLocation = const LatLng(24.7136, 46.6753); // الرياض

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("اختيار الموقع")),

      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: selectedLocation,
          zoom: 14,
        ),

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
