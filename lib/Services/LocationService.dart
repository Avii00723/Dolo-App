// lib/Services/LocationService.dart
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  // Enhanced method to handle both permissions and location service
  static Future<bool> handleLocationPermissionAndService() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Step 1: Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Prompt user to enable location services - this shows system dialog
      try {
        bool opened = await Geolocator.openLocationSettings();
        if (!opened) {
          return false;
        }
        // Wait a bit and check again
        await Future.delayed(Duration(seconds: 1));
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          return false;
        }
      } catch (e) {
        print('Error opening location settings: $e');
        return false;
      }
    }

    // Step 2: Check and request location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Open app settings for permanent denial
      try {
        await Geolocator.openAppSettings();
      } catch (e) {
        print('Error opening app settings: $e');
      }
      return false;
    }

    return true;
  }

  // Keep the old method for backward compatibility
  static Future<bool> handleLocationPermission() async {
    return await handleLocationPermissionAndService();
  }

  static Future<Position?> getCurrentPosition() async {
    final hasPermission = await handleLocationPermissionAndService();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  static Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.name ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.postalCode ?? ''}'
            .replaceAll(RegExp(r'^,+|,+$'), '') // Remove leading/trailing commas
            .replaceAll(RegExp(r',+'), ', ') // Replace multiple commas with single
            .trim();
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    return null;
  }

  static Future<List<Location>?> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      return locations.isNotEmpty ? locations : null;
    } catch (e) {
      print('Error getting coordinates: $e');
      return null;
    }
  }
}
