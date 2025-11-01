// lib/screens/RouteMapViewScreen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../Constants/colorconstant.dart';
import '../Constants/ApiConstants.dart';
import 'CustomRouteMapScreen.dart';

class RouteMapViewScreen extends StatefulWidget {
  final String originCity;
  final String destinationCity;
  final double? originLatitude;
  final double? originLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final RouteInfo routeInfo;
  final List<dynamic>? initialStopovers; // Accept initial stopovers from previous navigation

  const RouteMapViewScreen({
    Key? key,
    required this.originCity,
    required this.destinationCity,
    this.originLatitude,
    this.originLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
    required this.routeInfo,
    this.initialStopovers, // Optional initial stopovers
  }) : super(key: key);

  @override
  State<RouteMapViewScreen> createState() => _RouteMapViewScreenState();
}

class Stopover {
  final String name;
  final double latitude;
  final double longitude;

  Stopover({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class _RouteMapViewScreenState extends State<RouteMapViewScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoading = true;
  String? _errorMessage;
  bool _isCardMinimized = true;
  List<Stopover> _stopovers = [];

  // Updated route info when stopovers are added
  String? _updatedDistance;
  String? _updatedDuration;

  @override
  void initState() {
    super.initState();

    // Initialize stopovers from previous navigation if provided
    if (widget.initialStopovers != null && widget.initialStopovers!.isNotEmpty) {
      _stopovers = widget.initialStopovers!.map((data) {
        return Stopover(
          name: data['name'],
          latitude: data['latitude'],
          longitude: data['longitude'],
        );
      }).toList();
      print('✅ Loaded ${_stopovers.length} existing stopovers');
    }

    _initializeMap();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      if (widget.originLatitude == null || widget.destinationLatitude == null) {
        throw Exception('Location coordinates not provided');
      }

      // Fetch and decode the polyline from the route
      // If stopovers exist, fetch route with stopovers; otherwise fetch normal route
      if (_stopovers.isNotEmpty) {
        await _updateRouteWithStopovers();
      } else {
        await _fetchAndDrawRoute();
      }

      // Create markers for all waypoints
      _createMarkers();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error initializing map: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _fetchAndDrawRoute() async {
    try {
      print('🗺️  Fetching route polyline from Google Directions API...');

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${widget.originLatitude},${widget.originLongitude}&'
        'destination=${widget.destinationLatitude},${widget.destinationLongitude}&'
        'key=${ApiConstants.googleMapsApiKey}',
      );

      final response = await http.get(url);

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 API Response status: ${data['status']}');

        if (data['status'] == 'OK' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];

          // Decode polyline
          final polylinePoints = _decodePolyline(route['overview_polyline']['points']);
          print('📍 Decoded ${polylinePoints.length} polyline points');

          // Add polyline to map
          setState(() {
            _polylines.add(
              Polyline(
                polylineId: PolylineId('main_route'),
                points: polylinePoints,
                color: Colors.blue, // Use bright blue for better visibility
                width: 8,
                geodesic: true,
                visible: true,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
            );
          });

          print('✅ Polyline added to map with ${polylinePoints.length} points');
          print('🗺️ Polylines set contains ${_polylines.length} polylines');
          print('🎨 Polyline color: blue, width: 8');
        } else if (data['status'] == 'REQUEST_DENIED') {
          print('⚠️ API Request denied: ${data['error_message']}');
          // Fallback: Draw a simple straight line between origin and destination
          _drawSimpleLine();
        } else {
          print('⚠️ No route found, drawing simple line');
          // Fallback: Draw a simple straight line
          _drawSimpleLine();
        }
      } else {
        print('⚠️ HTTP error, drawing simple line');
        _drawSimpleLine();
      }
    } catch (e) {
      print('❌ Error fetching route: $e');
      print('⚠️ Falling back to simple line');
      _drawSimpleLine();
    }
  }

  void _drawSimpleLine() {
    // Draw a simple line between origin and destination as fallback
    final points = [
      LatLng(widget.originLatitude!, widget.originLongitude!),
      LatLng(widget.destinationLatitude!, widget.destinationLongitude!),
    ];

    setState(() {
      _polylines.add(
        Polyline(
          polylineId: PolylineId('simple_route'),
          points: points,
          color: Colors.red, // Use red for fallback to distinguish it
          width: 8,
          geodesic: true,
          visible: true,
          patterns: [PatternItem.dash(30), PatternItem.gap(20)],
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    });

    print('✅ Simple line drawn between origin and destination (fallback mode)');
    print('📍 Polylines set now contains ${_polylines.length} polylines');
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

  void _createMarkers() {
    Set<Marker> markers = {};

    // Origin marker
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

    // Destination marker
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

    // Add stopover markers
    for (int i = 0; i < _stopovers.length; i++) {
      final stopover = _stopovers[i];
      markers.add(
        Marker(
          markerId: MarkerId('stopover_$i'),
          position: LatLng(stopover.latitude, stopover.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: stopover.name,
            snippet: 'Stopover ${i + 1}',
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });

    print('✅ Created ${_markers.length} markers (${_stopovers.length} stopovers)');
  }

  void _fitMapToRoute() {
    if (_markers.isEmpty || _mapController == null) return;

    final positions = _markers.map((m) => m.position).toList();
    final bounds = _boundsFromLatLngList(positions);

    Future.delayed(Duration(milliseconds: 500), () {
      if (_mapController != null && mounted) {
        try {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 80),
          );
        } catch (e) {
          print('⚠️ Error fitting map to route: $e');
        }
      }
    });
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

  void _showAddStopoverDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddStopoverSheet(
        onStopoverAdded: (stopover) {
          print('📍 Adding stopover: ${stopover.name} at (${stopover.latitude}, ${stopover.longitude})');
          setState(() {
            _stopovers.add(stopover);
            _createMarkers();
          });
          print('📍 Total stopovers now: ${_stopovers.length}');
          print('📍 Stopovers list: ${_stopovers.map((s) => s.name).toList()}');

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Stopover added: ${stopover.name}'),
                  ),
                ],
              ),
              backgroundColor: Colors.green[700],
              duration: Duration(seconds: 2),
            ),
          );

          // Update route with new stopover
          _updateRouteWithStopovers();
        },
        existingStopovers: _stopovers,
      ),
    );
  }

  Future<void> _updateRouteWithStopovers() async {
    if (_stopovers.isEmpty) {
      // If no stopovers, just use original route
      await _fetchAndDrawRoute();
      return;
    }

    // Build waypoints string for Google Directions API
    final waypointsString = _stopovers
        .map((s) => '${s.latitude},${s.longitude}')
        .join('|');

    try {
      print('🗺️  Fetching route with ${_stopovers.length} stopovers...');
      print('📍 Waypoints: $waypointsString');

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${widget.originLatitude},${widget.originLongitude}&'
        'destination=${widget.destinationLatitude},${widget.destinationLongitude}&'
        'waypoints=$waypointsString&'
        'key=${ApiConstants.googleMapsApiKey}',
      );

      final response = await http.get(url);
      print('📡 Stopover route response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 Stopover route API status: ${data['status']}');

        if (data['status'] == 'OK' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final polylinePoints = _decodePolyline(route['overview_polyline']['points']);

          // Extract updated distance and duration
          String totalDistance = '0 km';
          String totalDuration = '0 min';

          if (route['legs'] != null && route['legs'].isNotEmpty) {
            // Calculate total distance and duration from all legs
            int totalDistanceMeters = 0;
            int totalDurationSeconds = 0;

            for (var leg in route['legs']) {
              if (leg['distance'] != null && leg['distance']['value'] != null) {
                totalDistanceMeters += (leg['distance']['value'] as num).toInt();
              }
              if (leg['duration'] != null && leg['duration']['value'] != null) {
                totalDurationSeconds += (leg['duration']['value'] as num).toInt();
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
              totalDuration = '${hours}h ${minutes}min';
            } else {
              totalDuration = '${minutes}min';
            }

            print('📏 New distance: $totalDistance');
            print('⏱️ New duration: $totalDuration');
          }

          print('📍 Decoded ${polylinePoints.length} polyline points for route with stopovers');

          setState(() {
            _polylines.clear();
            _polylines.add(
              Polyline(
                polylineId: PolylineId('main_route_with_stopovers'),
                points: polylinePoints,
                color: Colors.blue,
                width: 8,
                geodesic: true,
                visible: true,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
            );

            // Update distance and duration
            _updatedDistance = totalDistance;
            _updatedDuration = totalDuration;
          });

          print('✅ Route updated with ${_stopovers.length} stopovers');
          print('🗺️ Polyline now has ${polylinePoints.length} points');

          // Fit map to show all points including stopovers
          _fitMapToRoute();
        } else if (data['status'] == 'REQUEST_DENIED') {
          print('⚠️ API Request denied for stopover route: ${data['error_message']}');
          _showErrorSnackbar('Unable to fetch route with stopovers. Please check API configuration.');
        } else {
          print('⚠️ No route found with stopovers, keeping original route');
          _showErrorSnackbar('Could not find route with stopovers');
        }
      } else {
        print('⚠️ HTTP error fetching stopover route: ${response.statusCode}');
        _showErrorSnackbar('Error fetching route with stopovers');
      }
    } catch (e) {
      print('❌ Error updating route with stopovers: $e');
      _showErrorSnackbar('Error: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                          print('✅ Map controller created');
                          print('📌 Markers on map: ${_markers.length}');
                          print('📍 Polylines on map: ${_polylines.length}');
                          if (_polylines.isNotEmpty) {
                            print('📍 First polyline has ${_polylines.first.points.length} points');
                          }
                          _fitMapToRoute();
                        },
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: true,
                        mapToolbarEnabled: false,
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

            // Add Stopover Button
            if (!_isLoading && _errorMessage == null)
              Positioned(
                right: 16,
                bottom: 280,
                child: FloatingActionButton(
                  onPressed: _showAddStopoverDialog,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.add_location_alt, color: Colors.white),
                  tooltip: 'Add Stopover',
                ),
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
              Colors.white.withOpacity(0.9),
              Colors.white.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                // Return stopovers when navigating back
                final stopoversData = _stopovers.map((s) => {
                  'name': s.name,
                  'latitude': s.latitude,
                  'longitude': s.longitude,
                }).toList();
                Navigator.pop(context, stopoversData);
              },
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
                      'Map View',
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
              print('🎴 Card ${_isCardMinimized ? "minimized" : "expanded"}');
              print('🎴 Stopovers count: ${_stopovers.length}');
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
                        _updatedDistance ?? widget.routeInfo.distance,
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
                          _updatedDuration ?? widget.routeInfo.duration,
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
            // Stopovers List
            if (_stopovers.isNotEmpty) ...[
              // Divider before stopovers
              Divider(color: Colors.grey[300], thickness: 1, height: 1),

              Container(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.orange[50], // Light orange background to make it visible
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.add_location_alt, color: Colors.orange, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Stopovers (${_stopovers.length}):',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    ..._stopovers.asMap().entries.map((entry) {
                      int index = entry.key;
                      Stopover stopover = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Colors.orange[800],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                stopover.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],

            // Route Summary
            if (widget.routeInfo.summary.isNotEmpty)
              Container(
                padding: EdgeInsets.fromLTRB(20, _stopovers.isEmpty ? 20 : 0, 20, 20),
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
                      widget.routeInfo.summary,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
        ),
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
              'Loading map...',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Preparing route visualization',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
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
                'Unable to load map',
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
                onPressed: _initializeMap,
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

// Add Stopover Bottom Sheet Widget
class _AddStopoverSheet extends StatefulWidget {
  final Function(Stopover) onStopoverAdded;
  final List<Stopover> existingStopovers;

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
          final stopover = Stopover(
            name: description,
            latitude: location['lat'],
            longitude: location['lng'],
          );

          widget.onStopoverAdded(stopover);
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
                            stopover.name,
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
