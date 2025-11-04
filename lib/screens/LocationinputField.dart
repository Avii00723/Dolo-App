// Enhanced Location Input Field with Full Screen Search
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart';
import '../Services/LocationService.dart';
import '../../Constants/colorconstant.dart';
import '../../Widgets/ModernInputField.dart';

class EnhancedLocationInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Function(Position?)? onLocationSelected;
  final bool isOrigin;

  const EnhancedLocationInputField({
    Key? key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.onLocationSelected,
    this.isOrigin = true,
  }) : super(key: key);

  @override
  State<EnhancedLocationInputField> createState() =>
      _EnhancedLocationInputFieldState();
}

class _EnhancedLocationInputFieldState
    extends State<EnhancedLocationInputField> {
  Position? selectedPosition;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _showLocationSearchScreen(context),
          child: AbsorbPointer(
            child: ModernInputField(
              controller: widget.controller,
              label: widget.label,
              hint: widget.hint,
              prefixIcon: widget.icon,
              readOnly: true,
              showClearButton: false,
              suffixIcon: Icon(
                Icons.arrow_drop_down,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        if (selectedPosition != null) ...[
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, color: Colors.green[700], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lat: ${selectedPosition!.latitude.toStringAsFixed(6)}, Lng: ${selectedPosition!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedPosition = null;
                      widget.controller.clear();
                    });
                    widget.onLocationSelected?.call(null);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.green[700],
                      size: 16,
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

  void _showLocationSearchScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => LocationSearchScreen(
          isOrigin: widget.isOrigin,
          onLocationSelected: (position, address) {
            setState(() {
              selectedPosition = position;
              widget.controller.text = address;
            });
            widget.onLocationSelected?.call(position);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

// Full Screen Location Search Screen
class LocationSearchScreen extends StatefulWidget {
  final Function(Position position, String address) onLocationSelected;
  final bool isOrigin;

  const LocationSearchScreen({
    Key? key,
    required this.onLocationSelected,
    this.isOrigin = true,
  }) : super(key: key);

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool isLoadingCurrentLocation = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    widget.isOrigin ? Icons.my_location : Icons.place,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.isOrigin
                          ? 'Select Origin Location'
                          : 'Select Destination Location',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Current Location Button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue[400]!,
                              Colors.blue[600]!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: isLoadingCurrentLocation
                                ? null
                                : _getCurrentLocation,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: isLoadingCurrentLocation
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.gps_fixed,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isLoadingCurrentLocation
                                              ? 'Getting your location...'
                                              : 'Use Current Location',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Auto-detect your current position',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.9),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white.withOpacity(0.7),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Divider with text
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Colors.grey[300],
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR SEARCH LOCATION',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Colors.grey[300],
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search Field with Autocomplete
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: GooglePlacesAutoCompleteTextFormField(
                              textEditingController: _searchController,
                              focusNode: _searchFocusNode,
                              config: const GoogleApiConfig(
                                apiKey:
                                    'AIzaSyBin4hsTqp0DSLCzjmQwuB78hBHZRhG_3Y',
                                countries: ['in'],
                                fetchPlaceDetailsWithCoordinates: true,
                                debounceTime: 400,
                              ),
                              onPredictionWithCoordinatesReceived:
                                  (prediction) {
                                if (prediction.lat != null &&
                                    prediction.lng != null) {
                                  final position = Position(
                                    latitude:
                                        double.parse(prediction.lat.toString()),
                                    longitude:
                                        double.parse(prediction.lng.toString()),
                                    timestamp: DateTime.now(),
                                    accuracy: 0.0,
                                    altitude: 0.0,
                                    altitudeAccuracy: 0.0,
                                    heading: 0.0,
                                    headingAccuracy: 0.0,
                                    speed: 0.0,
                                    speedAccuracy: 0.0,
                                  );

                                  final address = prediction.description ?? '';
                                  widget.onLocationSelected(position, address);

                                  _showSuccessSnackBar(
                                      context,
                                      widget.isOrigin
                                          ? '✅ Origin location selected'
                                          : '✅ Destination location selected');
                                }
                              },
                              onSuggestionClicked: (prediction) {
                                final description =
                                    prediction.description ?? '';
                                _searchController.text = description;
                                _searchController.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(offset: description.length),
                                );
                              },
                              decoration: InputDecoration(
                                hintText: 'Search for a location...',
                                hintStyle: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(
                                      left: 16, right: 12),
                                  child: Icon(
                                    Icons.search,
                                    color: Colors.grey[400],
                                    size: 22,
                                  ),
                                ),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear,
                                            color: Colors.grey[600]),
                                        onPressed: () {
                                          setState(() {
                                            _searchController.clear();
                                          });
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(
                                      color: Colors.grey[300]!, width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(
                                      color: Colors.grey[300]!, width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(
                                      color: AppColors.primary, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 17,
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Info Banner
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue[700],
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Type to see location suggestions. Select from the dropdown to auto-fill coordinates.',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Recent/Popular Locations Section (Optional)
                          // const SizedBox(height: 24),
                          // _buildPopularLocationsSection(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularLocationsSection() {
    final popularLocations = [
      {'name': 'Home', 'icon': Icons.home, 'color': Colors.orange},
      {'name': 'Work', 'icon': Icons.work, 'color': Colors.blue},
      {'name': 'Recent', 'icon': Icons.history, 'color': Colors.purple},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Access',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: popularLocations.map((location) {
            return Container(
              decoration: BoxDecoration(
                color: (location['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (location['color'] as Color).withOpacity(0.3),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    // Handle quick access tap
                    _showSnackBar(
                      context,
                      '${location['name']} location - Feature coming soon!',
                      Colors.blue,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          location['icon'] as IconData,
                          color: location['color'] as Color,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          location['name'] as String,
                          style: TextStyle(
                            color: location['color'] as Color,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      isLoadingCurrentLocation = true;
    });

    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        final address = await LocationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );

        final displayAddress = address ??
            'Current Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';

        widget.onLocationSelected(position, displayAddress);

        _showSuccessSnackBar(
          context,
          '✅ Current location obtained successfully!',
        );
      } else {
        _showSnackBar(
          context,
          'Please enable location services and grant permission.',
          Colors.orange,
        );
      }
    } catch (e) {
      _showSnackBar(
        context,
        'Error getting location: $e',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoadingCurrentLocation = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green
                  ? Icons.check_circle
                  : color == Colors.red
                      ? Icons.error_outline
                      : Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
