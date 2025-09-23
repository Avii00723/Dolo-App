// lib/widgets/location_input_field.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../Services/LocationService.dart';

class LocationInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Function(Position?)? onLocationSelected;

  const LocationInputField({
    Key? key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.onLocationSelected,
  }) : super(key: key);

  @override
  State<LocationInputField> createState() => _LocationInputFieldState();
}

class _LocationInputFieldState extends State<LocationInputField> {
  Position? selectedPosition;
  bool isLoadingLocation = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: widget.controller,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              prefixIcon: Icon(widget.icon, color: Theme.of(context).primaryColor),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoadingLocation)
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.my_location),
                      onPressed: _getCurrentLocation,
                      tooltip: 'Use current location',
                    ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _searchLocation,
                    tooltip: 'Search location',
                  ),
                ],
              ),
            ),
            onChanged: (value) {
              // Clear position when user types manually
              if (selectedPosition != null) {
                setState(() {
                  selectedPosition = null;
                });
                widget.onLocationSelected?.call(null);
              }
            },
          ),
        ),
        if (selectedPosition != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, color: Colors.green[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lat: ${selectedPosition!.latitude.toStringAsFixed(6)}, Lng: ${selectedPosition!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      isLoadingLocation = true;
    });

    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        final address = await LocationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );

        setState(() {
          selectedPosition = position;
          widget.controller.text = address ??
              'Current Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
        });

        widget.onLocationSelected?.call(position);
        _showSnackBar('Location obtained successfully!', Colors.green);
      } else {
        _showSnackBar('Please enable location services and grant permission.', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('Error getting location: $e', Colors.red);
    } finally {
      setState(() {
        isLoadingLocation = false;
      });
    }
  }

  Future<void> _searchLocation() async {
    if (widget.controller.text.trim().isEmpty) {
      _showSnackBar('Please enter a location to search', Colors.orange);
      return;
    }

    setState(() {
      isLoadingLocation = true;
    });

    try {
      final locations = await LocationService.getCoordinatesFromAddress(
          widget.controller.text.trim()
      );

      if (locations != null && locations.isNotEmpty) {
        final location = locations.first;
        // Create Position from Location
        final position = Position(
          latitude: location.latitude,
          longitude: location.longitude,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );

        setState(() {
          selectedPosition = position;
        });

        widget.onLocationSelected?.call(position);
        _showSnackBar('Location found successfully!', Colors.green);
      } else {
        _showSnackBar('Location not found. Please try a different search term.', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('Error searching location: $e', Colors.red);
    } finally {
      setState(() {
        isLoadingLocation = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}
