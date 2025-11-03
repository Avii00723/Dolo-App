import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../Constants/colorconstant.dart';
import '../Constants/ApiConstants.dart';

class CustomRoutePreviewScreen extends StatefulWidget {
  final String origin;
  final String destination;
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final List<Map<String, dynamic>> stopovers;
  final String vehicle;

  const CustomRoutePreviewScreen({
    Key? key,
    required this.origin,
    required this.destination,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    required this.stopovers,
    required this.vehicle,
  }) : super(key: key);

  @override
  State<CustomRoutePreviewScreen> createState() =>
      _CustomRoutePreviewScreenState();
}

class _CustomRoutePreviewScreenState extends State<CustomRoutePreviewScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  late AnimationController _animationController;
  late Animation<double> _animation;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  String? totalDistance;
  String? totalDuration;
  List<Map<String, String>> legDetails = [];
  bool isLoadingRoute = true;

  // Custom map style (minimalist with your theme colors)
  static const String _mapStyle = '''
  [
    {
      "featureType": "all",
      "elementType": "geometry",
      "stylers": [{"color": "#F5F5F5"}]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [{"color": "#E0E0E0"}]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#757575"}]
    },
    {
      "featureType": "poi",
      "elementType": "labels.icon",
      "stylers": [{"visibility": "on"}]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [{"color": "#C8E6FF"}]
    },
    {
      "featureType": "transit",
      "elementType": "geometry",
      "stylers": [{"color": "#D0D0D0"}]
    }
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
    _setupMarkersAndRoute();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _setupMarkersAndRoute() async {
    // Create markers first
    _markers = {
      Marker(
        markerId: const MarkerId('origin'),
        position: LatLng(widget.originLat, widget.originLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'From',
          snippet: widget.origin,
        ),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(widget.destLat, widget.destLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'To',
          snippet: widget.destination,
        ),
      ),
    };

    // Add stopover markers
    for (int i = 0; i < widget.stopovers.length; i++) {
      final stopover = widget.stopovers[i];
      _markers.add(
        Marker(
          markerId: MarkerId('stopover_$i'),
          position: LatLng(
            stopover['latitude'] as double,
            stopover['longitude'] as double,
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: 'Stop ${i + 1}',
            snippet: stopover['city'] as String,
          ),
        ),
      );
    }

    // Fetch route from Google Directions API
    await _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    try {
      print('🗺️ Fetching route from Google Directions API...');

      // Map vehicle to travel mode
      String travelMode = _getTravelMode(widget.vehicle);

      // Build waypoints string for stopovers
      String waypoints = '';
      if (widget.stopovers.isNotEmpty) {
        waypoints = '&waypoints=';
        for (int i = 0; i < widget.stopovers.length; i++) {
          final stopover = widget.stopovers[i];
          waypoints +=
              '${stopover['latitude']},${stopover['longitude']}';
          if (i < widget.stopovers.length - 1) {
            waypoints += '|';
          }
        }
      }

      final url =
          'https://maps.googleapis.com/maps/api/directions/json?origin=${widget.originLat},${widget.originLng}&destination=${widget.destLat},${widget.destLng}$waypoints&mode=$travelMode&key=${ApiConstants.googleMapsApiKey}';

      print('🌐 Directions API URL: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final legs = route['legs'] as List;

          // Calculate totals and store leg details
          int totalDistanceMeters = 0;
          int totalDurationSeconds = 0;
          legDetails = [];

          for (int i = 0; i < legs.length; i++) {
            final leg = legs[i];
            totalDistanceMeters += leg['distance']['value'] as int;
            totalDurationSeconds += leg['duration']['value'] as int;

            // Store individual leg details
            String from = i == 0 ? widget.origin : widget.stopovers[i - 1]['city'];
            String to = i == legs.length - 1
                ? widget.destination
                : widget.stopovers[i]['city'];

            legDetails.add({
              'from': _extractCityName(from),
              'to': _extractCityName(to),
              'distance': leg['distance']['text'],
              'duration': leg['duration']['text'],
            });
          }

          // Format totals
          totalDistance = _formatDistance(totalDistanceMeters);
          totalDuration = _formatDuration(totalDurationSeconds);

          print('✅ Route fetched: Total Distance=$totalDistance, Total Duration=$totalDuration');

          // Decode polyline
          final polylinePoints = PolylinePoints();
          final points = polylinePoints
              .decodePolyline(route['overview_polyline']['points']);

          List<LatLng> routePoints = points
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          // Create polyline
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: routePoints,
              color: AppColors.primary,
              width: 5,
            ),
          };

          setState(() {
            isLoadingRoute = false;
          });
        } else {
          print('❌ Directions API error: ${data['status']}');
          setState(() {
            isLoadingRoute = false;
          });
        }
      } else {
        print('❌ HTTP error: ${response.statusCode}');
        setState(() {
          isLoadingRoute = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching route: $e');
      setState(() {
        isLoadingRoute = false;
      });
    }
  }

  String _getTravelMode(String vehicle) {
    // Map vehicle types to Google Directions API travel modes
    switch (vehicle.toLowerCase()) {
      case 'bike':
        return 'bicycling';
      case 'car':
      case 'pickup truck':
      case 'truck':
        return 'driving';
      case 'bus':
      case 'train':
        return 'transit';
      case 'plane':
        return 'driving'; // Fallback to driving for plane
      default:
        return 'driving';
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController?.setMapStyle(_mapStyle);

    // Fit bounds to show all markers
    if (_markers.isNotEmpty) {
      _fitMapBounds();
    }
  }

  void _fitMapBounds() {
    if (_mapController == null) return;

    double minLat = widget.originLat;
    double maxLat = widget.originLat;
    double minLng = widget.originLng;
    double maxLng = widget.originLng;

    // Include destination
    minLat = math.min(minLat, widget.destLat);
    maxLat = math.max(maxLat, widget.destLat);
    minLng = math.min(minLng, widget.destLng);
    maxLng = math.max(maxLng, widget.destLng);

    // Include stopovers
    for (var stopover in widget.stopovers) {
      final lat = stopover['latitude'] as double;
      final lng = stopover['longitude'] as double;
      minLat = math.min(minLat, lat);
      maxLat = math.max(maxLat, lat);
      minLng = math.min(minLng, lng);
      maxLng = math.max(maxLng, lng);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Route Preview',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Google Map with Custom Style
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(widget.originLat, widget.originLng),
                    zoom: 12,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  mapType: MapType.normal,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
                // Custom overlay at top
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.route,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Route',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_extractCityName(widget.origin)} → ${_extractCityName(widget.destination)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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

          // Route Details Card (overlapping map to hide Google logo)
          Expanded(
            flex: 2,
            child: Transform.translate(
              offset: const Offset(0, -60),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    const Text(
                      'Your Journey',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Distance and Duration Cards
                    if (isLoadingRoute)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Calculating route...',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (totalDistance != null && totalDuration != null)
                      Column(
                        children: [
                          // Total Distance and Duration Cards
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.primary.withOpacity(0.8)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.straighten,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        totalDistance!,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Total Distance',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.orange[600]!,
                                        Colors.orange[400]!
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        totalDuration!,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Total Time',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Leg Details
                          if (legDetails.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.route,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Route Breakdown',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ...legDetails.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final leg = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${index + 1}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${leg['from']} → ${leg['to']}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.straighten,
                                                      size: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      leg['distance']!,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Icon(
                                                      Icons.access_time,
                                                      size: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      leg['duration']!,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
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
                        ],
                      ),
                    const SizedBox(height: 20),

                    // Origin
                    _buildLocationRow(
                      icon: Icons.radio_button_checked,
                      label: 'From',
                      location: widget.origin,
                      color: AppColors.primary,
                    ),

                    // Stopovers
                    if (widget.stopovers.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ...widget.stopovers.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildLocationRow(
                            icon: Icons.location_on,
                            label: 'Stop ${entry.key + 1}',
                            location: entry.value['city'] ?? '',
                            color: Colors.orange,
                          ),
                        );
                      }).toList(),
                    ],

                    const SizedBox(height: 16),

                    // Destination
                    _buildLocationRow(
                      icon: Icons.location_on,
                      label: 'To',
                      location: widget.destination,
                      color: Colors.red,
                    ),

                    const SizedBox(height: 24),

                    // Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'This is a preview of your route. Search to find available orders.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Got it!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required String label,
    required String location,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to extract city name from location string
  String _extractCityName(String location) {
    final parts = location.split(',');
    return parts.isNotEmpty ? parts[0].trim() : location;
  }

  // Format distance from meters
  String _formatDistance(int meters) {
    if (meters < 1000) {
      return '$meters m';
    } else {
      double km = meters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  // Format duration from seconds
  String _formatDuration(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

class CustomRoutePainter extends CustomPainter {
  final double animationProgress;
  final String origin;
  final String destination;
  final List<Map<String, dynamic>> stopovers;

  CustomRoutePainter({
    required this.animationProgress,
    required this.origin,
    required this.destination,
    required this.stopovers,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background map elements first
    _drawMapBackground(canvas, size);
    _drawRoads(canvas, size);
    _drawStreetNames(canvas, size);
    _drawLandmarks(canvas, size);

    // Calculate layout
    final totalStops = 2 + stopovers.length; // origin + stopovers + destination
    final padding = size.width * 0.15;
    final availableWidth = size.width - (2 * padding);
    final availableHeight = size.height * 0.8;
    final topPadding = size.height * 0.1;

    // Create path points
    List<Offset> pathPoints = [];

    // Start point (origin)
    pathPoints.add(Offset(padding, topPadding));

    // Calculate intermediate points for stopovers
    if (stopovers.isNotEmpty) {
      final verticalSpacing = availableHeight / (totalStops + 1);

      for (int i = 0; i < stopovers.length; i++) {
        final y = topPadding + (verticalSpacing * (i + 1));
        // Alternate left and right for visual interest
        final x = (i % 2 == 0)
            ? padding + (availableWidth * 0.7)
            : padding + (availableWidth * 0.3);
        pathPoints.add(Offset(x, y));
      }
    }

    // End point (destination)
    final endY = topPadding + availableHeight;
    pathPoints.add(Offset(padding + availableWidth, endY));

    // Draw path
    _drawPath(canvas, pathPoints);

    // Draw markers
    _drawMarker(
      canvas,
      pathPoints[0],
      AppColors.primary,
      origin,
      'FROM',
    );

    for (int i = 0; i < stopovers.length; i++) {
      _drawStopoverMarker(
        canvas,
        pathPoints[i + 1],
        stopovers[i]['city'] ?? 'Stop ${i + 1}',
      );
    }

    _drawMarker(
      canvas,
      pathPoints.last,
      Colors.red,
      destination,
      'TO',
    );
  }

  void _drawMapBackground(Canvas canvas, Size size) {
    // Draw light gray background for map
    final bgPaint = Paint()..color = const Color(0xFFF5F5F5);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw subtle grid pattern
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // Draw city blocks (rectangles)
    final blockPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final blockBorderPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Add random city blocks
    final blocks = [
      Rect.fromLTWH(size.width * 0.1, size.height * 0.15, 60, 80),
      Rect.fromLTWH(size.width * 0.7, size.height * 0.25, 50, 70),
      Rect.fromLTWH(size.width * 0.3, size.height * 0.45, 70, 60),
      Rect.fromLTWH(size.width * 0.8, size.height * 0.6, 55, 65),
      Rect.fromLTWH(size.width * 0.15, size.height * 0.7, 65, 55),
    ];

    for (final block in blocks) {
      canvas.drawRect(block, blockPaint);
      canvas.drawRect(block, blockBorderPaint);
    }
  }

  void _drawRoads(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;

    final roadLinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Vertical roads
    final verticalRoads = [
      size.width * 0.25,
      size.width * 0.5,
      size.width * 0.75,
    ];

    for (final x in verticalRoads) {
      // Road background
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadPaint);
      // Center line
      _drawDashedLine(
          canvas, Offset(x, 0), Offset(x, size.height), roadLinePaint);
    }

    // Horizontal roads
    final horizontalRoads = [
      size.height * 0.2,
      size.height * 0.4,
      size.height * 0.6,
      size.height * 0.8,
    ];

    for (final y in horizontalRoads) {
      // Road background
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadPaint);
      // Center line
      _drawDashedLine(
          canvas, Offset(0, y), Offset(size.width, y), roadLinePaint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 5;
    const dashSpace = 5;
    final distance = (end - start).distance;
    final normalizedDistance = (end - start) / distance;

    for (double i = 0; i < distance; i += dashWidth + dashSpace) {
      final lineStart = start + (normalizedDistance * i);
      final lineEnd =
          start + (normalizedDistance * math.min(i + dashWidth, distance));
      canvas.drawLine(lineStart, lineEnd, paint);
    }
  }

  void _drawStreetNames(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: Colors.grey[600],
      fontSize: 9,
      fontWeight: FontWeight.w500,
    );

    // Parse city names from origin and destination
    final originCity = _extractCityName(origin);
    final destCity = _extractCityName(destination);

    // Draw street names along roads
    final streetNames = [
      _StreetLabel(
          '$originCity St', Offset(size.width * 0.05, size.height * 0.18), -90),
      _StreetLabel(
          'Main Ave', Offset(size.width * 0.48, size.height * 0.05), 0),
      _StreetLabel(
          '$destCity Rd', Offset(size.width * 0.72, size.height * 0.3), -90),
      _StreetLabel(
          'Central Blvd', Offset(size.width * 0.1, size.height * 0.38), 0),
    ];

    for (final street in streetNames) {
      canvas.save();
      canvas.translate(street.position.dx, street.position.dy);
      canvas.rotate(street.angle * math.pi / 180);

      final textPainter = TextPainter(
        text: TextSpan(text: street.name, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));

      canvas.restore();
    }
  }

  void _drawLandmarks(Canvas canvas, Size size) {
    // Extract area names
    final areas = _extractAreaNames();

    // Define landmarks with icons
    final landmarks = [
      _Landmark('🏪', 'Shop', Offset(size.width * 0.2, size.height * 0.3)),
      _Landmark(
          '🍴', 'Restaurant', Offset(size.width * 0.6, size.height * 0.35)),
      _Landmark('⛽', 'Fuel', Offset(size.width * 0.4, size.height * 0.55)),
      _Landmark('🏥', 'Hospital', Offset(size.width * 0.75, size.height * 0.7)),
      _Landmark('🏢', areas.isNotEmpty ? areas[0] : 'Building',
          Offset(size.width * 0.3, size.height * 0.75)),
    ];

    for (final landmark in landmarks) {
      // Draw landmark icon
      final iconPainter = TextPainter(
        text: TextSpan(
          text: landmark.icon,
          style: const TextStyle(fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      );
      iconPainter.layout();
      iconPainter.paint(
        canvas,
        Offset(
          landmark.position.dx - iconPainter.width / 2,
          landmark.position.dy - iconPainter.height / 2,
        ),
      );

      // Draw landmark label
      final labelPainter = TextPainter(
        text: TextSpan(
          text: landmark.label,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 8,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(
          landmark.position.dx - labelPainter.width / 2,
          landmark.position.dy + 12,
        ),
      );
    }
  }

  String _extractCityName(String location) {
    final parts = location.split(',');
    return parts.isNotEmpty ? parts[0].trim() : location;
  }

  List<String> _extractAreaNames() {
    List<String> areas = [];

    // Extract from origin
    final originParts = origin.split(',');
    if (originParts.length > 1) {
      areas.add(originParts[1].trim());
    }

    // Extract from destination
    final destParts = destination.split(',');
    if (destParts.length > 1 && !areas.contains(destParts[1].trim())) {
      areas.add(destParts[1].trim());
    }

    // Extract from stopovers
    for (final stopover in stopovers) {
      final stopParts = (stopover['city'] as String).split(',');
      if (stopParts.length > 1 && !areas.contains(stopParts[1].trim())) {
        areas.add(stopParts[1].trim());
      }
    }

    return areas.take(3).toList();
  }

  void _drawPath(Canvas canvas, List<Offset> points) {
    if (points.length < 2) return;

    // Draw incomplete (gray) path
    final incompletePaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw completed (primary color) path
    final completedPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Create smooth path using cubic bezier curves
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];

      // Create control points for smooth curve
      final midX = (p0.dx + p1.dx) / 2;
      final controlPoint1 = Offset(midX, p0.dy);
      final controlPoint2 = Offset(midX, p1.dy);

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }

    // Draw gray path first
    canvas.drawPath(path, incompletePaint);

    // Draw animated green path
    final pathMetric = path.computeMetrics().first;
    final animatedLength = pathMetric.length * animationProgress;
    final animatedPath = pathMetric.extractPath(0, animatedLength);
    canvas.drawPath(animatedPath, completedPaint);
  }

  void _drawMarker(
    Canvas canvas,
    Offset position,
    Color color,
    String label,
    String subtitle,
  ) {
    // Draw glow effect
    final glowPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(position, 35 * animationProgress, glowPaint);

    // Draw main circle
    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 28 * animationProgress, circlePaint);

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(position, 28 * animationProgress, borderPaint);

    // Draw inner white circle
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 20 * animationProgress, innerPaint);

    // Draw subtitle
    final subtitlePainter = TextPainter(
      text: TextSpan(
        text: subtitle,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    subtitlePainter.layout();
    subtitlePainter.paint(
      canvas,
      Offset(
        position.dx - subtitlePainter.width / 2,
        position.dy - subtitlePainter.height / 2,
      ),
    );

    // Draw label to the side
    final labelPainter = TextPainter(
      text: TextSpan(
        text: _shortenLabel(label),
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    labelPainter.layout(maxWidth: 150);

    final labelX = position.dx > 200
        ? position.dx - labelPainter.width - 45
        : position.dx + 45;
    labelPainter.paint(canvas, Offset(labelX, position.dy - 8));
  }

  void _drawStopoverMarker(Canvas canvas, Offset position, String label) {
    // Draw main circle
    final circlePaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 20 * animationProgress, circlePaint);

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(position, 20 * animationProgress, borderPaint);

    // Draw inner circle
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 14 * animationProgress, innerPaint);

    // Draw number
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '•',
        style: TextStyle(
          color: Colors.orange,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );

    // Draw label
    final labelPainter = TextPainter(
      text: TextSpan(
        text: _shortenLabel(label),
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    labelPainter.layout(maxWidth: 120);

    final labelX = position.dx > 200
        ? position.dx - labelPainter.width - 35
        : position.dx + 35;
    labelPainter.paint(canvas, Offset(labelX, position.dy - 6));
  }

  String _shortenLabel(String label) {
    final parts = label.split(',');
    final firstPart = parts.first.trim();
    return firstPart.length > 20
        ? '${firstPart.substring(0, 20)}...'
        : firstPart;
  }

  @override
  bool shouldRepaint(CustomRoutePainter oldDelegate) {
    return animationProgress != oldDelegate.animationProgress;
  }
}

// Helper classes for street labels and landmarks
class _StreetLabel {
  final String name;
  final Offset position;
  final double angle; // in degrees

  _StreetLabel(this.name, this.position, this.angle);
}

class _Landmark {
  final String icon;
  final String label;
  final Offset position;

  _Landmark(this.icon, this.label, this.position);
}
