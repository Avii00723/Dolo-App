// lib/Screens/RouteMapScreen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../Constants/colorconstant.dart';
import '../Constants/ApiConstants.dart';

class RouteMapScreen extends StatefulWidget {
  final String originCity;
  final String destinationCity;
  final LatLng? originLatLng;
  final LatLng? destinationLatLng;

  const RouteMapScreen({
    Key? key,
    required this.originCity,
    required this.destinationCity,
    this.originLatLng,
    this.destinationLatLng,
  }) : super(key: key);

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<String> _citiesAlongRoute = [];
  String? _distance;
  String? _duration;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isCardMinimized = false;


  @override
  void initState() {
    super.initState();
    _initializeRoute();
  }

  Future<void> _initializeRoute() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Use provided coordinates or geocode addresses
      LatLng? origin = widget.originLatLng;
      LatLng? destination = widget.destinationLatLng;

      if (origin == null || destination == null) {
        throw Exception('Location coordinates not provided');
      }

      // Fetch route details from Google Directions API
      await _fetchRouteDetails(origin, destination);

      // Force a rebuild to show markers and polylines
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('🔄 UI rebuilt with ${_markers.length} markers and ${_polylines.length} polylines');
      }
    } catch (e) {
      print('❌ Error initializing route: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _fetchRouteDetails(LatLng origin, LatLng destination) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
            'origin=${origin.latitude},${origin.longitude}&'
            'destination=${destination.latitude},${destination.longitude}&'
            'key=${ApiConstants.googleMapsApiKey}',
      );

      print('🗺️  Fetching route from Google Directions API...');
      print('📍 Origin: ${origin.latitude}, ${origin.longitude}');
      print('📍 Destination: ${destination.latitude}, ${destination.longitude}');
      print('🔑 API Key configured: ${ApiConstants.googleMapsApiKey.isNotEmpty}');

      final response = await http.get(url);

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔍 API Status: ${data['status']}');

        if (data['status'] == 'OK' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          // Extract distance and duration
          _distance = leg['distance']['text'];
          _duration = leg['duration']['text'];

          print('✅ Route found: $_distance, $_duration');

          // Extract polyline points
          final polylinePoints = _decodePolyline(route['overview_polyline']['points']);
          print('📍 Decoded ${polylinePoints.length} polyline points');

          // Add markers for origin and destination
          setState(() {
            _markers.add(
              Marker(
                markerId: MarkerId('origin'),
                position: origin,
                infoWindow: InfoWindow(
                  title: widget.originCity,
                  snippet: 'Pickup Location',
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              ),
            );

            _markers.add(
              Marker(
                markerId: MarkerId('destination'),
                position: destination,
                infoWindow: InfoWindow(
                  title: widget.destinationCity,
                  snippet: 'Delivery Location',
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              ),
            );

            // Add polyline for the route
            _polylines.add(
              Polyline(
                polylineId: PolylineId('route'),
                points: polylinePoints,
                color: Colors.blue,
                width: 8,
                geodesic: true,
              ),
            );
          });

          print('✅ Added ${_markers.length} markers and ${_polylines.length} polylines');

          // Extract cities along the route
          await _extractCitiesAlongRoute(leg['steps']);

          // Move camera to show the entire route after a delay
          // to ensure map is fully loaded
          Future.delayed(Duration(milliseconds: 500), () {
            if (_mapController != null && mounted) {
              print('📷 Moving camera to show route bounds');
              try {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngBounds(
                    _boundsFromLatLngList([origin, destination]),
                    100,
                  ),
                );
              } catch (e) {
                print('❌ Error moving camera: $e');
                // Fallback: Just zoom to origin
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(origin, 8),
                );
              }
            }
          });
        } else {
          final errorMsg = data['error_message'] ?? 'Unknown error';
          print('❌ API returned status: ${data['status']}');
          print('❌ Error message: $errorMsg');
          throw Exception('No route found: ${data['status']} - $errorMsg');
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        print('❌ Response: ${response.body}');
        throw Exception('Failed to fetch route: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching route: $e');
      rethrow;
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  Future<void> _extractCitiesAlongRoute(List<dynamic> steps) async {
    Set<String> cities = {};

    // Sample some points along the route to find cities
    final sampleCount = steps.length > 5 ? 5 : steps.length;
    final sampleInterval = steps.length ~/ sampleCount;

    for (int i = 0; i < steps.length; i += sampleInterval) {
      if (i >= steps.length) break;

      final step = steps[i];
      final location = step['end_location'];
      final latLng = LatLng(location['lat'], location['lng']);

      // Reverse geocode to get city name
      final cityName = await _reverseGeocode(latLng);
      if (cityName != null && cityName.isNotEmpty) {
        cities.add(cityName);
      }
    }

    setState(() {
      _citiesAlongRoute = cities.toList();
    });
  }

  Future<String?> _reverseGeocode(LatLng position) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?'
            'latlng=${position.latitude},${position.longitude}&'
            'key=${ApiConstants.googleMapsApiKey}',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final components = data['results'][0]['address_components'] as List;

          // Find locality (city)
          for (var component in components) {
            final types = component['types'] as List;
            if (types.contains('locality') || types.contains('administrative_area_level_2')) {
              return component['long_name'];
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ Reverse geocoding error: $e');
      return null;
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;

    for (LatLng point in points) {
      if (minLat == null || point.latitude < minLat) {
        minLat = point.latitude;
      }
      if (maxLat == null || point.latitude > maxLat) {
        maxLat = point.latitude;
      }
      if (minLng == null || point.longitude < minLng) {
        minLng = point.longitude;
      }
      if (maxLng == null || point.longitude > maxLng) {
        maxLng = point.longitude;
      }
    }

    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Debug logging
    if (!_isLoading && _errorMessage == null) {
      print('🗺️ Building map with ${_markers.length} markers and ${_polylines.length} polylines');
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Google Map
            _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                ? _buildErrorState()
                : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.originLatLng ?? LatLng(0, 0),
                zoom: 6,
              ),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (controller) {
                _mapController = controller;
                print('✅ Map controller created');
                print('📌 Current markers: ${_markers.length}');
                print('📍 Current polylines: ${_polylines.length}');

                // Move camera to show route after map is created
                if (widget.originLatLng != null && widget.destinationLatLng != null) {
                  Future.delayed(Duration(milliseconds: 800), () {
                    if (_mapController != null && mounted) {
                      print('📷 Animating camera to show route');
                      try {
                        _mapController!.animateCamera(
                          CameraUpdate.newLatLngBounds(
                            _boundsFromLatLngList([widget.originLatLng!, widget.destinationLatLng!]),
                            100,
                          ),
                        );
                      } catch (e) {
                        print('⚠️ Camera animation failed, using fallback: $e');
                        _mapController!.animateCamera(
                          CameraUpdate.newLatLngZoom(widget.originLatLng!, 8),
                        );
                      }
                    }
                  });
                }
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              mapToolbarEnabled: true,
              compassEnabled: true,
            ),

            // Header
            _buildHeader(),

            // Floating Route Info Card
            if (!_isLoading && _errorMessage == null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildRouteInfoCard(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.white.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Route Preview',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${widget.originCity} → ${widget.destinationCity}',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildRouteInfoCard() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minimize/Maximize Handle
          GestureDetector(
            onTap: () {
              setState(() {
                _isCardMinimized = !_isCardMinimized;
              });
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 8),
                  Icon(
                    _isCardMinimized ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),

          // Route Summary - Always visible
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.1), AppColors.primary.withOpacity(0.05)],
              ),
            ),
            child: Row(
              children: [
                // Distance
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.straighten, color: AppColors.primary, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Distance',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        _distance ?? 'Calculating...',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey[300],
                ),
                // Duration
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(width: 16),
                          Icon(Icons.access_time, color: AppColors.primary, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Duration',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Padding(
                        padding: EdgeInsets.only(left: 16),
                        child: Text(
                          _duration ?? 'Calculating...',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Expandable content
          if (!_isCardMinimized) ...[
            // Cities Along Route
            if (_citiesAlongRoute.isNotEmpty)
              Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_city,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Cities Along Route',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildCitiesList(),
                  ],
                ),
              ),

            // Close Button
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCitiesList() {
    return Container(
      constraints: BoxConstraints(maxHeight: 200),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Origin
            _buildCityItem(widget.originCity, true, false),

            // Cities along the route
            ..._citiesAlongRoute.map((city) => _buildCityItem(city, false, false)),

            // Destination
            _buildCityItem(widget.destinationCity, false, true),
          ],
        ),
      ),
    );
  }

  Widget _buildCityItem(String city, bool isOrigin, bool isDestination) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isOrigin
                  ? Colors.green.withOpacity(0.15)
                  : isDestination
                  ? Colors.red.withOpacity(0.15)
                  : AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isOrigin
                  ? Icons.trip_origin
                  : isDestination
                  ? Icons.location_on
                  : Icons.circle,
              color: isOrigin
                  ? Colors.green[700]
                  : isDestination
                  ? Colors.red[700]
                  : AppColors.primary,
              size: isOrigin || isDestination ? 20 : 12,
            ),
          ),
          SizedBox(width: 12),
          // City name
          Expanded(
            child: Text(
              city,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: isOrigin || isDestination ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          // Label
          if (isOrigin || isDestination)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isOrigin
                    ? Colors.green.withOpacity(0.15)
                    : Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isOrigin ? 'Pickup' : 'Delivery',
                style: TextStyle(
                  color: isOrigin ? Colors.green[700] : Colors.red[700],
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
            SizedBox(height: 20),
            Text(
              'Loading route...',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please wait while we calculate the best route',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.red[700],
                  size: 48,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Unable to load route',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              Text(
                _errorMessage ?? 'An error occurred',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _initializeRoute,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(Icons.refresh),
                label: Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}