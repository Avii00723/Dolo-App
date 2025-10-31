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

  const RouteMapViewScreen({
    Key? key,
    required this.originCity,
    required this.destinationCity,
    this.originLatitude,
    this.originLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
    required this.routeInfo,
  }) : super(key: key);

  @override
  State<RouteMapViewScreen> createState() => _RouteMapViewScreenState();
}

class _RouteMapViewScreenState extends State<RouteMapViewScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoading = true;
  String? _errorMessage;
  bool _isCardMinimized = true;

  @override
  void initState() {
    super.initState();
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
      await _fetchAndDrawRoute();

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

    // Waypoint markers for cities along route
    int waypointIndex = 0;
    for (var cityWaypoint in widget.routeInfo.cities) {
      markers.add(
        Marker(
          markerId: MarkerId('waypoint_$waypointIndex'),
          position: LatLng(cityWaypoint.latitude, cityWaypoint.longitude),
          icon: cityWaypoint.type == 'nearby'
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange)
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: cityWaypoint.name,
            snippet: cityWaypoint.type == 'nearby'
                ? 'Nearby (${cityWaypoint.category})'
                : 'Passing Through (${cityWaypoint.category})',
          ),
        ),
      );
      waypointIndex++;
    }

    setState(() {
      _markers = markers;
    });

    print('✅ Created ${_markers.length} markers');
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
                        widget.routeInfo.distance,
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
                          widget.routeInfo.duration,
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
            if (widget.routeInfo.cities.isNotEmpty)
              Container(
                padding: EdgeInsets.all(20),
                constraints: BoxConstraints(maxHeight: 300),
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
                          'Waypoints (${widget.routeInfo.cities.length})',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: widget.routeInfo.cities.length,
                        itemBuilder: (context, index) {
                          final city = widget.routeInfo.cities[index];
                          return _buildWaypointItem(city, index);
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // Route Summary
            if (widget.routeInfo.summary.isNotEmpty)
              Container(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
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
    );
  }

  Widget _buildWaypointItem(CityWaypoint waypoint, int index) {
    final isNearby = waypoint.type == 'nearby';
    final color = isNearby ? Colors.orange : Colors.blue;

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isNearby ? Icons.near_me : Icons.circle,
              color: color[700],
              size: isNearby ? 18 : 12,
            ),
          ),
          SizedBox(width: 12),
          // City info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  waypoint.name,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  isNearby
                      ? 'Nearby • ${_getCategoryLabel(waypoint.category)}'
                      : 'Passing Through • ${_getCategoryLabel(waypoint.category)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
