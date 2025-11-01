// lib/screens/CustomRouteMapScreen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../Constants/colorconstant.dart';
import '../Constants/ApiConstants.dart';

class CustomRouteMapScreen extends StatefulWidget {
  final String originCity;
  final String destinationCity;
  final double? originLatitude;
  final double? originLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final List<Map<String, dynamic>>? stopovers; // Accept stopovers

  const CustomRouteMapScreen({
    Key? key,
    required this.originCity,
    required this.destinationCity,
    this.originLatitude,
    this.originLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
    this.stopovers, // Optional stopovers parameter
  }) : super(key: key);

  @override
  State<CustomRouteMapScreen> createState() => _CustomRouteMapScreenState();
}

class CityWaypoint {
  final String name;
  final String type; // 'through' or 'nearby'
  final String category; // 'city', 'district', 'town', or 'area'
  final double latitude;
  final double longitude;

  CityWaypoint({
    required this.name,
    required this.type,
    required this.category,
    required this.latitude,
    required this.longitude,
  });
}

class RouteInfo {
  final List<CityWaypoint> cities;
  final String distance;
  final String duration;
  final String summary;
  final List<dynamic> steps;

  RouteInfo({
    required this.cities,
    required this.distance,
    required this.duration,
    required this.summary,
    required this.steps,
  });
}

class _CustomRouteMapScreenState extends State<CustomRouteMapScreen>
    with SingleTickerProviderStateMixin {
  List<RouteInfo> _availableRoutes = [];
  int _selectedRouteIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isCardMinimized = true; // Start minimized
  late AnimationController _animationController;
  late Animation<double> _animation;
  List<dynamic> _currentStopovers = []; // Store stopovers when navigating back from map

  // Map related variables
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _initializeRoute();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeRoute() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      if (widget.originLatitude == null || widget.destinationLatitude == null) {
        throw Exception('Location coordinates not provided');
      }

      // Fetch route details from Google Directions API
      await _fetchRouteDetails();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _animationController.forward();

        // Create markers and draw route after loading
        _createMarkers();
        _drawSelectedRoute();
      }
    } catch (e) {
      print('❌ Error initializing route: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _fetchRouteDetails() async {
    try {
      // Build waypoints string if stopovers are present
      String waypointsParam = '';
      if (widget.stopovers != null && widget.stopovers!.isNotEmpty) {
        final waypointsString = widget.stopovers!
            .map((s) => '${s['latitude']},${s['longitude']}')
            .join('|');
        waypointsParam = '&waypoints=$waypointsString';
        print('🗺️  Fetching routes with ${widget.stopovers!.length} stopovers...');
        print('📍 Waypoints: $waypointsString');
      } else {
        print('🗺️  Fetching alternative routes from Google Directions API...');
      }

      // Fetch multiple route options by making separate API calls
      final routeRequests = [
        // 1. Default with alternatives
        {
          'url': Uri.parse(
            'https://maps.googleapis.com/maps/api/directions/json?'
            'origin=${widget.originLatitude},${widget.originLongitude}&'
            'destination=${widget.destinationLatitude},${widget.destinationLongitude}'
            '$waypointsParam&'
            'alternatives=true&'
            'key=${ApiConstants.googleMapsApiKey}',
          ),
          'label': 'default routes'
        },
        // 2. Avoid tolls (only if no stopovers, as waypoints override avoid params)
        if (widget.stopovers == null || widget.stopovers!.isEmpty)
          {
            'url': Uri.parse(
              'https://maps.googleapis.com/maps/api/directions/json?'
              'origin=${widget.originLatitude},${widget.originLongitude}&'
              'destination=${widget.destinationLatitude},${widget.destinationLongitude}&'
              'avoid=tolls&'
              'key=${ApiConstants.googleMapsApiKey}',
            ),
            'label': 'avoiding tolls'
          },
        // 3. Avoid highways (only if no stopovers)
        if (widget.stopovers == null || widget.stopovers!.isEmpty)
          {
            'url': Uri.parse(
              'https://maps.googleapis.com/maps/api/directions/json?'
              'origin=${widget.originLatitude},${widget.originLongitude}&'
              'destination=${widget.destinationLatitude},${widget.destinationLongitude}&'
              'avoid=highways&'
              'key=${ApiConstants.googleMapsApiKey}',
            ),
            'label': 'avoiding highways'
          },
      ];

      Set<String> uniqueRouteSummaries = {};

      for (var request in routeRequests) {
        try {
          print('   Fetching ${request['label']}...');
          final response = await http.get(request['url'] as Uri);

          if (response.statusCode == 200) {
            final data = json.decode(response.body);

            if (data['status'] == 'OK' &&
                data['routes'] != null &&
                data['routes'].isNotEmpty) {

              // Process all routes from this request
              for (var route in data['routes']) {
                final summary = route['summary'] ?? 'via ${widget.originCity}';

                // Skip duplicate routes based on summary
                if (uniqueRouteSummaries.contains(summary)) {
                  continue;
                }
                uniqueRouteSummaries.add(summary);

                // Calculate total distance and duration across all legs (for routes with stopovers)
                String totalDistance;
                String totalDuration;
                List<dynamic> allSteps = [];

                if (route['legs'] != null && route['legs'].isNotEmpty) {
                  int totalDistanceMeters = 0;
                  int totalDurationSeconds = 0;

                  // Sum up distance and duration from all legs
                  for (var leg in route['legs']) {
                    if (leg['distance'] != null && leg['distance']['value'] != null) {
                      totalDistanceMeters += (leg['distance']['value'] as num).toInt();
                    }
                    if (leg['duration'] != null && leg['duration']['value'] != null) {
                      totalDurationSeconds += (leg['duration']['value'] as num).toInt();
                    }
                    if (leg['steps'] != null) {
                      allSteps.addAll(leg['steps']);
                    }
                  }

                  // Format distance
                  if (totalDistanceMeters >= 1000) {
                    totalDistance = '${(totalDistanceMeters / 1000).toStringAsFixed(1)} km';
                  } else {
                    totalDistance = '$totalDistanceMeters m';
                  }

                  // Format duration
                  int hours = totalDurationSeconds ~/ 3600;
                  int minutes = (totalDurationSeconds % 3600) ~/ 60;
                  if (hours > 0) {
                    totalDuration = '$hours hour $minutes mins';
                  } else {
                    totalDuration = '$minutes mins';
                  }
                } else {
                  totalDistance = 'Unknown';
                  totalDuration = 'Unknown';
                }

                // Extract cities along this route
                // COMMENTED OUT: City detection not needed for basic route display
                // final cities = await _extractCitiesAlongRoute(allSteps);
                final cities = <CityWaypoint>[]; // Empty list - no intermediate cities

                _availableRoutes.add(RouteInfo(
                  cities: cities,
                  distance: totalDistance,
                  duration: totalDuration,
                  summary: summary,
                  steps: allSteps,
                ));

                print('   ✓ Route ${_availableRoutes.length}: $totalDistance, $totalDuration - $summary');
              }
            }
          }
        } catch (e) {
          print('   ⚠️  Error fetching ${request['label']}: $e');
          // Continue with other requests even if one fails
        }
      }

      if (_availableRoutes.isEmpty) {
        throw Exception('No routes found from any request');
      }

      print('✅ Total unique routes found: ${_availableRoutes.length}');
    } catch (e) {
      print('❌ Error fetching route: $e');
      rethrow;
    }
  }

  void _createMarkers() {
    Set<Marker> markers = {};

    // Origin marker (green)
    markers.add(
      Marker(
        markerId: MarkerId('origin'),
        position: LatLng(widget.originLatitude!, widget.originLongitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: widget.originCity,
          snippet: 'Pickup Location',
        ),
      ),
    );

    // Destination marker (red)
    markers.add(
      Marker(
        markerId: MarkerId('destination'),
        position: LatLng(widget.destinationLatitude!, widget.destinationLongitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: widget.destinationCity,
          snippet: 'Delivery Location',
        ),
      ),
    );

    // Add stopover markers if any
    if (widget.stopovers != null && widget.stopovers!.isNotEmpty) {
      for (int i = 0; i < widget.stopovers!.length; i++) {
        final stopover = widget.stopovers![i];
        markers.add(
          Marker(
            markerId: MarkerId('stopover_$i'),
            position: LatLng(stopover['latitude'], stopover['longitude']),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
              title: stopover['city'],
              snippet: 'Stopover ${i + 1}',
            ),
          ),
        );
      }
      print('✅ Created ${widget.stopovers!.length} stopover markers');
    }

    setState(() {
      _markers = markers;
    });
  }

  void _drawSelectedRoute() {
    if (_availableRoutes.isEmpty) return;

    final selectedRoute = _availableRoutes[_selectedRouteIndex];
    final polylinePoints = _decodePolyline(selectedRoute.steps);

    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: PolylineId('route_$_selectedRouteIndex'),
          points: polylinePoints,
          color: AppColors.primary,
          width: 6,
          geodesic: true,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    });

    _fitMapToRoute();
  }

  List<LatLng> _decodePolyline(List<dynamic> steps) {
    List<LatLng> points = [];

    for (var step in steps) {
      if (step['polyline'] != null && step['polyline']['points'] != null) {
        final encoded = step['polyline']['points'];
        points.addAll(_decodePolylineString(encoded));
      }
    }

    return points;
  }

  List<LatLng> _decodePolylineString(String encoded) {
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

  void _fitMapToRoute() {
    if (_markers.isEmpty || _mapController == null) return;

    final positions = _markers.map((m) => m.position).toList();

    if (positions.isEmpty) return;

    double minLat = positions[0].latitude;
    double maxLat = positions[0].latitude;
    double minLng = positions[0].longitude;
    double maxLng = positions[0].longitude;

    for (var pos in positions) {
      if (pos.latitude < minLat) minLat = pos.latitude;
      if (pos.latitude > maxLat) maxLat = pos.latitude;
      if (pos.longitude < minLng) minLng = pos.longitude;
      if (pos.longitude > maxLng) maxLng = pos.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  // COMMENTED OUT: City extraction logic not needed for basic route display
  // Users can add stopovers manually instead
  /*
  Future<List<CityWaypoint>> _extractCitiesAlongRoute(List<dynamic> steps) async {
    Map<String, CityWaypoint> citiesMap = {};

    print('🏙️  Extracting cities along route (${steps.length} steps)...');

    // Calculate approximate distance per step
    double totalDistanceMeters = 0;
    for (var step in steps) {
      totalDistanceMeters += (step['distance']['value'] as num).toDouble();
    }

    // Sample every ~5-8 km for better coverage of cities like Lonavala
    final minSamples = 15;
    final sampleDistanceMeters = 5000.0; // 5 km (reduced from 15 km)
    final calculatedSamples = (totalDistanceMeters / sampleDistanceMeters).ceil();
    final sampleCount = calculatedSamples > minSamples ? calculatedSamples : minSamples;
    final sampleInterval = steps.length ~/ (sampleCount > steps.length ? steps.length : sampleCount);

    print('   Total distance: ${(totalDistanceMeters / 1000).toStringAsFixed(1)} km');
    print('   Sampling ${sampleCount} points (every ${sampleInterval > 0 ? sampleInterval : 1} steps)');

    double accumulatedDistance = 0;
    double lastSampledDistance = 0;

    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final stepDistance = (step['distance']['value'] as num).toDouble();
      accumulatedDistance += stepDistance;

      // Sample more frequently:
      // 1. At regular intervals
      // 2. When we've traveled 5km since last sample
      // 3. At first and last step
      // 4. On steps with significant distance (>3km typically means highway segment through cities)
      bool shouldSample = false;

      if (i == 0 || i == steps.length - 1) {
        shouldSample = true;
      } else if (sampleInterval > 0 && i % sampleInterval == 0) {
        shouldSample = true;
      } else if ((accumulatedDistance - lastSampledDistance) >= 5000) {
        shouldSample = true;
      } else if (stepDistance >= 3000) {
        // Long steps often mean passing through a city on highway
        shouldSample = true;
      }

      if (shouldSample) {
        lastSampledDistance = accumulatedDistance;

        // For very long steps (>20km), sample both start and end
        if (stepDistance >= 20000) {
          // Sample start location
          final startLocation = step['start_location'];
          final startLat = startLocation['lat'] as double;
          final startLng = startLocation['lng'] as double;

          final startCityInfo = await _reverseGeocodeDetailed(startLat, startLng);
          if (startCityInfo != null && !citiesMap.containsKey(startCityInfo.name)) {
            citiesMap[startCityInfo.name] = startCityInfo;
            print('   ✓ Found: ${startCityInfo.name} (${startCityInfo.category} - ${startCityInfo.type}) at ${((accumulatedDistance - stepDistance) / 1000).toStringAsFixed(1)}km');
          }

          // Sample middle point for very long steps
          final midLat = (startLat + (step['end_location']['lat'] as double)) / 2;
          final midLng = (startLng + (step['end_location']['lng'] as double)) / 2;

          final midCityInfo = await _reverseGeocodeDetailed(midLat, midLng);
          if (midCityInfo != null && !citiesMap.containsKey(midCityInfo.name)) {
            citiesMap[midCityInfo.name] = midCityInfo;
            print('   ✓ Found: ${midCityInfo.name} (${midCityInfo.category} - ${midCityInfo.type}) at ${((accumulatedDistance - stepDistance/2) / 1000).toStringAsFixed(1)}km [mid-point]');
          }
        }

        // Sample end location
        final location = step['end_location'];
        final lat = location['lat'] as double;
        final lng = location['lng'] as double;

        final cityInfo = await _reverseGeocodeDetailed(lat, lng);

        if (cityInfo != null && !citiesMap.containsKey(cityInfo.name)) {
          citiesMap[cityInfo.name] = cityInfo;
          print('   ✓ Found: ${cityInfo.name} (${cityInfo.category} - ${cityInfo.type}) at ${(accumulatedDistance / 1000).toStringAsFixed(1)}km');
        }
      }
    }

    final result = citiesMap.values.toList();
    print('✅ Total cities found: ${result.length}');
    return result;
  }

  Future<CityWaypoint?> _reverseGeocodeDetailed(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?'
        'latlng=$lat,$lng&'
        'key=${ApiConstants.googleMapsApiKey}',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final results = data['results'] as List;

          // Extract both cities and districts from address components
          String? localityName;
          String? districtName;
          String? subLocalityName;
          String? admin3Name;

          for (var result in results) {
            final components = result['address_components'] as List;

            for (var component in components) {
              final componentTypes = component['types'] as List;
              final name = component['long_name'] as String;

              // Extract locality (city/town)
              if (componentTypes.contains('locality') && localityName == null) {
                localityName = name;
              }
              // Extract sublocality (area within city)
              else if (componentTypes.contains('sublocality') && subLocalityName == null) {
                subLocalityName = name;
              }
              // Extract administrative_area_level_2 (district)
              else if (componentTypes.contains('administrative_area_level_2') && districtName == null) {
                districtName = name;
              }
              // Extract administrative_area_level_3 (sub-district/taluka)
              else if (componentTypes.contains('administrative_area_level_3') && admin3Name == null) {
                admin3Name = name;
              }
            }
          }

          // Priority: locality > sublocality > admin_level_3 > district
          String? placeName;
          String category = 'area';

          if (localityName != null) {
            placeName = localityName;
            category = 'city';
          } else if (subLocalityName != null) {
            placeName = subLocalityName;
            category = 'town';
          } else if (admin3Name != null) {
            placeName = admin3Name;
            category = 'area';
          } else if (districtName != null) {
            placeName = districtName;
            category = 'district';
          }

          if (placeName != null && placeName.isNotEmpty) {
            // Determine if we're passing through or nearby
            String waypointType = 'through';

            // Check if this is a route-only location (highway, not entering city)
            final firstResult = results[0];
            final firstTypes = firstResult['types'] as List;

            if (firstTypes.contains('route') && !firstTypes.contains('locality')) {
              waypointType = 'nearby';
            }

            return CityWaypoint(
              name: placeName,
              type: waypointType,
              category: category,
              latitude: lat,
              longitude: lng,
            );
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Google Map as background
            _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                    ? _buildErrorState()
                    : GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            widget.originLatitude ?? 0,
                            widget.originLongitude ?? 0,
                          ),
                          zoom: 6,
                        ),
                        markers: _markers,
                        polylines: _polylines,
                        onMapCreated: (controller) {
                          _mapController = controller;
                          _fitMapToRoute();
                        },
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: true,
                        mapToolbarEnabled: false,
                        compassEnabled: true,
                      ),

            // Header with back button
            _buildHeader(),

            // Floating Routes Card at bottom
            if (!_isLoading && _errorMessage == null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildFloatingRoutesCard(),
              ),

            // Add Stopover Button - COMMENTED OUT
            // if (!_isLoading && _errorMessage == null)
            //   Positioned(
            //     right: 16,
            //     bottom: _isCardMinimized ? 140 : 400,
            //     child: FloatingActionButton(
            //       onPressed: _showAddStopoverDialog,
            //       backgroundColor: AppColors.primary,
            //       child: Icon(Icons.add_location_alt, color: Colors.white),
            //       tooltip: 'Add Stopover',
            //     ),
            //   ),
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
              Colors.white.withOpacity(0.9),
              Colors.white.withOpacity(0.7),
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
                      'Route Map',
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

  Widget _buildFloatingRoutesCard() {
    if (_availableRoutes.isEmpty) return SizedBox.shrink();

    final selectedRoute = _availableRoutes[_selectedRouteIndex];

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
      child: SingleChildScrollView(
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
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.primary.withOpacity(0.05)
                  ],
                ),
              ),
              child: Column(
                children: [
                  Row(
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
                              selectedRoute.distance,
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
                                selectedRoute.duration,
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

                  // Stopovers indicator
                  if (widget.stopovers != null && widget.stopovers!.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_location_alt, color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Route includes ${widget.stopovers!.length} stopover${widget.stopovers!.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Expandable content
            if (!_isCardMinimized) ...[
              // Route options selector (if multiple routes)
              if (_availableRoutes.length > 1)
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _buildRouteOptionsSelector(),
                ),

              // Route Summary
              if (selectedRoute.summary.isNotEmpty)
                Container(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.route, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Route:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        selectedRoute.summary,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

              // Select Route Button
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _buildSelectRouteButton(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // STOPOVER FUNCTIONALITY - COMMENTED OUT
  /*
  void _showAddStopoverDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddStopoverSheet(
        onStopoverAdded: (stopoverData) {
          setState(() {
            _currentStopovers.add(stopoverData);
            _createMarkers();
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Stopover added: ${stopoverData['name']}'),
                  ),
                ],
              ),
              backgroundColor: Colors.green[700],
              duration: Duration(seconds: 2),
            ),
          );

          // Refetch routes with stopovers
          _refetchRoutesWithStopovers();
        },
        existingStopovers: _currentStopovers,
      ),
    );
  }

  Future<void> _refetchRoutesWithStopovers() async {
    if (_currentStopovers.isEmpty) {
      // If no stopovers, just fetch normal routes
      await _fetchRouteDetails();
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // Build waypoints string for Google Directions API
      final waypointsString = _currentStopovers
          .map((s) => '${s['latitude']},${s['longitude']}')
          .join('|');

      print('🗺️  Fetching routes with ${_currentStopovers.length} stopovers...');
      print('📍 Waypoints: $waypointsString');

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${widget.originLatitude},${widget.originLongitude}&'
        'destination=${widget.destinationLatitude},${widget.destinationLongitude}&'
        'waypoints=$waypointsString&'
        'alternatives=true&'
        'key=${ApiConstants.googleMapsApiKey}',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'] != null && data['routes'].isNotEmpty) {
          _availableRoutes.clear();
          Set<String> uniqueRouteSummaries = {};

          for (var route in data['routes']) {
            if (route['legs'] != null && route['legs'].isNotEmpty) {
              final summary = route['summary'] ?? 'Route ${_availableRoutes.length + 1}';

              if (!uniqueRouteSummaries.contains(summary)) {
                uniqueRouteSummaries.add(summary);

                // Calculate total distance and duration across all legs (for multiple stopovers)
                int totalDistanceMeters = 0;
                int totalDurationSeconds = 0;
                List<dynamic> allSteps = [];

                for (var leg in route['legs']) {
                  if (leg['distance'] != null && leg['distance']['value'] != null) {
                    totalDistanceMeters += (leg['distance']['value'] as num).toInt();
                  }
                  if (leg['duration'] != null && leg['duration']['value'] != null) {
                    totalDurationSeconds += (leg['duration']['value'] as num).toInt();
                  }
                  if (leg['steps'] != null) {
                    allSteps.addAll(leg['steps']);
                  }
                }

                // Format distance
                String totalDistance;
                if (totalDistanceMeters >= 1000) {
                  totalDistance = '${(totalDistanceMeters / 1000).toStringAsFixed(1)} km';
                } else {
                  totalDistance = '$totalDistanceMeters m';
                }

                // Format duration
                String totalDuration;
                int hours = totalDurationSeconds ~/ 3600;
                int minutes = (totalDurationSeconds % 3600) ~/ 60;
                if (hours > 0) {
                  totalDuration = '$hours hour ${minutes} mins';
                } else {
                  totalDuration = '$minutes mins';
                }

                print('📏 Total distance: $totalDistance (${route['legs'].length} legs)');
                print('⏱️ Total duration: $totalDuration');

                _availableRoutes.add(RouteInfo(
                  cities: <CityWaypoint>[],
                  distance: totalDistance,
                  duration: totalDuration,
                  summary: summary,
                  steps: allSteps,
                ));
              }
            }
          }

          print('✅ Found ${_availableRoutes.length} routes with stopovers');

          setState(() {
            _isLoading = false;
            _selectedRouteIndex = 0;
          });

          _drawSelectedRoute();
        } else {
          print('⚠️ No routes found with stopovers');
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error refetching routes with stopovers: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  */
  // END OF STOPOVER FUNCTIONALITY

  Widget _buildStatsCard() {
    final selectedRoute = _availableRoutes[_selectedRouteIndex];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Row(
          children: [
            // Distance
            Expanded(
              child: _buildStatItem(
                icon: Icons.straighten,
                label: 'Distance',
                value: selectedRoute.distance,
              ),
            ),
            Container(
              width: 1,
              height: 50,
              color: Colors.white.withOpacity(0.3),
            ),
            // Duration
            Expanded(
              child: _buildStatItem(
                icon: Icons.access_time,
                label: 'Duration',
                value: selectedRoute.duration,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildVisualRouteCard() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with minimize button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isCardMinimized = !_isCardMinimized;
                  });
                },
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.route,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Route Details',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(
                        _isCardMinimized
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),

              // Expandable content
              if (!_isCardMinimized) ...[
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Origin
                      _buildLocationItem(
                        city: widget.originCity,
                        isOrigin: true,
                        isDestination: false,
                        progress: 1.0,
                      ),

                      // Cities along route with animated connections
                      ..._buildRoutePath(),

                      // Destination
                      _buildLocationItem(
                        city: widget.destinationCity,
                        isOrigin: false,
                        isDestination: true,
                        progress: _animation.value,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildRoutePath() {
    List<Widget> pathWidgets = [];
    final selectedRoute = _availableRoutes[_selectedRouteIndex];

    for (int i = 0; i < selectedRoute.cities.length; i++) {
      final cityWaypoint = selectedRoute.cities[i];

      // Connection line
      pathWidgets.add(_buildConnectionLine(_animation.value));

      // City waypoint with type indicator
      pathWidgets.add(
        _buildLocationItemWithType(
          cityWaypoint: cityWaypoint,
          isOrigin: false,
          isDestination: false,
          progress: _animation.value,
        ),
      );
    }

    // Final connection to destination
    if (selectedRoute.cities.isNotEmpty) {
      pathWidgets.add(_buildConnectionLine(_animation.value));
    } else {
      // Direct connection if no intermediate cities
      pathWidgets.add(_buildConnectionLine(_animation.value));
    }

    return pathWidgets;
  }

  Widget _buildConnectionLine(double progress) {
    return Container(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background line
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Animated progress line
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 3,
              height: 40 * progress,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.6),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Animated dot moving along line
          if (progress < 1.0)
            Positioned(
              top: 40 * progress - 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationItem({
    required String city,
    required bool isOrigin,
    required bool isDestination,
    required double progress,
  }) {
    final opacity = progress.clamp(0.0, 1.0);

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: 0.8 + (0.2 * progress),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isOrigin || isDestination
                ? (isOrigin
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1))
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOrigin
                  ? Colors.green
                  : isDestination
                      ? Colors.red
                      : AppColors.primary.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isOrigin
                      ? Colors.green
                      : isDestination
                          ? Colors.red
                          : AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (isOrigin
                              ? Colors.green
                              : isDestination
                                  ? Colors.red
                                  : AppColors.primary)
                          .withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isOrigin
                      ? Icons.trip_origin
                      : isDestination
                          ? Icons.location_on
                          : Icons.circle,
                  color: Colors.white,
                  size: isOrigin || isDestination ? 28 : 16,
                ),
              ),
              SizedBox(width: 16),
              // City info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      city,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      isOrigin
                          ? 'Pickup Location'
                          : isDestination
                              ? 'Delivery Location'
                              : 'Via',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge
              if (isOrigin || isDestination)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOrigin ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOrigin ? 'START' : 'END',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationItemWithType({
    required CityWaypoint cityWaypoint,
    required bool isOrigin,
    required bool isDestination,
    required double progress,
  }) {
    final opacity = progress.clamp(0.0, 1.0);
    final isNearby = cityWaypoint.type == 'nearby';

    // Different colors based on city type
    final Color iconColor = isOrigin
        ? Colors.green
        : isDestination
            ? Colors.red
            : isNearby
                ? Colors.orange
                : AppColors.primary;

    final Color bgColor = isOrigin || isDestination
        ? (isOrigin ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1))
        : isNearby
            ? Colors.orange.withOpacity(0.05)
            : AppColors.primary.withOpacity(0.05);

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: 0.8 + (0.2 * progress),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: iconColor.withOpacity(isNearby ? 0.5 : 0.8),
              width: isNearby ? 1.5 : 2,
              style: isNearby ? BorderStyle.solid : BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(isNearby ? 0.7 : 1.0),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isOrigin
                      ? Icons.trip_origin
                      : isDestination
                          ? Icons.location_on
                          : isNearby
                              ? Icons.near_me
                              : _getCategoryIcon(cityWaypoint.category),
                  color: Colors.white,
                  size: isOrigin || isDestination ? 28 : 20,
                ),
              ),
              SizedBox(width: 16),
              // City info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cityWaypoint.name,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isNearby ? Icons.visibility : Icons.check_circle,
                          size: 14,
                          color: isNearby ? Colors.orange : Colors.green[600],
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            isOrigin
                                ? 'Pickup Location'
                                : isDestination
                                    ? 'Delivery Location'
                                    : isNearby
                                        ? 'Nearby (Bypassing) • ${_getCategoryLabel(cityWaypoint.category)}'
                                        : 'Passing Through • ${_getCategoryLabel(cityWaypoint.category)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Badge
              if (isOrigin || isDestination)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOrigin ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOrigin ? 'START' : 'END',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'city':
        return Icons.location_city;
      case 'district':
        return Icons.map;
      case 'town':
        return Icons.home_work;
      case 'area':
        return Icons.place;
      default:
        return Icons.location_on;
    }
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'city':
        return 'City';
      case 'district':
        return 'District';
      case 'town':
        return 'Town';
      case 'area':
        return 'Area';
      default:
        return 'Location';
    }
  }

  Widget _buildSelectRouteButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          // Return the selected route data back to the previous screen
          Navigator.pop(context, _availableRoutes[_selectedRouteIndex]);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 3,
        ),
        child: Text(
          'Select This Route',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }


  Widget _buildRouteOptionsSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.alt_route,
                  color: AppColors.primary,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Available Routes (${_availableRoutes.length})',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _availableRoutes.length,
            itemBuilder: (context, index) {
              return _buildRouteOption(index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRouteOption(int index) {
    final route = _availableRoutes[index];
    final isSelected = index == _selectedRouteIndex;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRouteIndex = index;
          _animationController.reset();
          _animationController.forward();
        });
        // Redraw route on map when selection changes
        _drawSelectedRoute();
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Selection indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
            SizedBox(width: 12),
            // Route info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Route ${index + 1}',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    route.summary,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            // Distance and duration
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      route.distance,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      route.duration,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Loading route...',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Calculating the best route for you',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red[700],
                size: 60,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Unable to load route',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 22,
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
    );
  }
}

// Add Stopover Bottom Sheet Widget - COMMENTED OUT
/*
class _AddStopoverSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onStopoverAdded;
  final List<dynamic> existingStopovers;

  const _AddStopoverSheet({
    required this.onStopoverAdded,
    required this.existingStopovers,
  });

  @override
  State<_AddStopoverSheet> createState() => _AddStopoverSheetState();
}

class _AddStopoverSheetState extends State<_AddStopoverSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?'
        'input=$query&'
        'key=${ApiConstants.googleMapsApiKey}',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _searchResults = data['predictions'];
          });
        }
      }
    } catch (e) {
      print('❌ Error searching places: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _selectPlace(String placeId, String description) async {
    try {
      // Get place details to get coordinates
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?'
        'place_id=$placeId&'
        'fields=geometry&'
        'key=${ApiConstants.googleMapsApiKey}',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          final stopoverData = {
            'name': description,
            'latitude': location['lat'],
            'longitude': location['lng'],
          };

          widget.onStopoverAdded(stopoverData);
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('❌ Error getting place details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.add_location_alt, color: AppColors.primary, size: 28),
                SizedBox(width: 12),
                Text(
                  'Add Stopover',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a place...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _isSearching
                    ? Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              onChanged: (value) {
                _searchPlaces(value);
              },
            ),
          ),

          SizedBox(height: 16),

          // Existing stopovers
          if (widget.existingStopovers.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Current Stopovers (${widget.existingStopovers.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            Container(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 20),
                itemCount: widget.existingStopovers.length,
                itemBuilder: (context, index) {
                  final stopover = widget.existingStopovers[index];
                  return Container(
                    margin: EdgeInsets.only(right: 12),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.orange, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Stop ${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        SizedBox(
                          width: 150,
                          child: Text(
                            stopover['name'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
          ],

          // Search results
          Expanded(
            child: _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey[300]),
                        SizedBox(height: 16),
                        Text(
                          'Search for a place to add as stopover',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final result = _searchResults[index];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.place,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          result['structured_formatting']['main_text'],
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          result['structured_formatting']['secondary_text'] ?? '',
                          style: TextStyle(fontSize: 12),
                        ),
                        onTap: () {
                          _selectPlace(
                            result['place_id'],
                            result['description'],
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
*/
// END OF STOPOVER BOTTOM SHEET WIDGET
