import 'package:flutter/material.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart';
import 'package:geolocator/geolocator.dart';
import '../../Constants/colorconstant.dart';

// This mixin adds the buildLocationAutocompleteField method to your state class
mixin LocationAutocompleteMixin<T extends StatefulWidget> on State<T>{
  // Abstract getters/setters that your state class must implement
  Position? get originPosition;
  Position? get destinationPosition;
  set originPosition(Position? value);
  set destinationPosition(Position? value);

  Widget buildLocationAutocompleteField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String hint,
    required bool isOrigin,
    required String helperText,
  }) {
    final Position? currentPosition = isOrigin ? originPosition : destinationPosition;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GooglePlacesAutoCompleteTextFormField(
          textEditingController: controller,
          config: const GoogleApiConfig(
            apiKey: 'AIzaSyBin4hsTqp0DSLCzjmQwuB78hBHZRhG_3Y',
            countries: ['in'],
            fetchPlaceDetailsWithCoordinates: true,
            debounceTime: 400,
          ),
          onPredictionWithCoordinatesReceived: (prediction) {  // ✅ Changed from onPlaceDetailsWithCoordinatesReceived
            // Extract coordinates from prediction
            if (prediction.lat != null && prediction.lng != null) {
              final position = Position(
                latitude: double.parse(prediction.lat.toString()),  // ✅ Convert to double
                longitude: double.parse(prediction.lng.toString()), // ✅ Convert to double
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
                if (isOrigin) {
                  originPosition = position;
                } else {
                  destinationPosition = position;
                }
              });

              _showLocationSnackBar(
                isOrigin
                    ? '✅ Origin coordinates saved'
                    : '✅ Destination coordinates saved',
                Colors.green,
              );
            }
          },
          onSuggestionClicked: (prediction) {
            final description = prediction.description ?? '';
            controller.text = description;
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: description.length),
            );
          },
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
            labelStyle: TextStyle(color: AppColors.primary),
          ),
        ),
        if (currentPosition != null) ...[
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
                    'Lat: ${currentPosition.latitude.toStringAsFixed(6)}, '
                        'Lng: ${currentPosition.longitude.toStringAsFixed(6)}',
                    style: TextStyle(color: Colors.green[700], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (helperText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            helperText,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  void _showLocationSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}