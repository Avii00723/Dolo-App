// lib/screens/CustomRouteMapScreen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../Constants/colorconstant.dart';
import '../Constants/ApiConstants.dart';
import 'RouteMapViewScreen.dart';

class CustomRouteMapScreen extends StatefulWidget {
  final String originCity;
  final String destinationCity;
  final double? originLatitude;
  final double? originLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;

  const CustomRouteMapScreen({
    Key? key,
    required this.originCity,
    required this.destinationCity,
    this.originLatitude,
    this.originLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
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
  bool _isCardMinimized = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

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
      print('🗺️  Fetching alternative routes from Google Directions API...');

      // Fetch multiple route options by making separate API calls
      final routeRequests = [
        // 1. Default with alternatives
        {
          'url': Uri.parse(
            'https://maps.googleapis.com/maps/api/directions/json?'
            'origin=${widget.originLatitude},${widget.originLongitude}&'
            'destination=${widget.destinationLatitude},${widget.destinationLongitude}&'
            'alternatives=true&'
            'key=${ApiConstants.googleMapsApiKey}',
          ),
          'label': 'default routes'
        },
        // 2. Avoid tolls
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
        // 3. Avoid highways
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
                final leg = route['legs'][0];
                final summary = route['summary'] ?? 'via ${widget.originCity}';

                // Skip duplicate routes based on summary
                if (uniqueRouteSummaries.contains(summary)) {
                  continue;
                }
                uniqueRouteSummaries.add(summary);

                // Extract distance and duration
                final distance = leg['distance']['text'];
                final duration = leg['duration']['text'];

                // Extract cities along this route
                final cities = await _extractCitiesAlongRoute(leg['steps']);

                _availableRoutes.add(RouteInfo(
                  cities: cities,
                  distance: distance,
                  duration: duration,
                  summary: summary,
                  steps: leg['steps'],
                ));

                print('   ✓ Route ${_availableRoutes.length}: $distance, $duration - $summary');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Content
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _buildRouteContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Route Preview',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '${widget.originCity} → ${widget.destinationCity}',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteContent() {
    if (_availableRoutes.isEmpty) {
      return Center(child: Text('No routes available'));
    }

    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Route options selector (if multiple routes)
          if (_availableRoutes.length > 1) ...[
            _buildRouteOptionsSelector(),
            SizedBox(height: 16),
          ],

          // Distance & Duration Card
          _buildStatsCard(),

          SizedBox(height: 16),

          // Visual Route Card
          _buildVisualRouteCard(),

          SizedBox(height: 16),

          // Select Route Button
          _buildSelectRouteButton(),

          SizedBox(height: 12),

          // View in Map Button
          _buildViewInMapButton(),

          SizedBox(height: 20),
        ],
      ),
    );
  }

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

  Widget _buildViewInMapButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          final selectedRoute = _availableRoutes[_selectedRouteIndex];
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RouteMapViewScreen(
                originCity: widget.originCity,
                destinationCity: widget.destinationCity,
                originLatitude: widget.originLatitude,
                originLongitude: widget.originLongitude,
                destinationLatitude: widget.destinationLatitude,
                destinationLongitude: widget.destinationLongitude,
                routeInfo: selectedRoute,
              ),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: AppColors.primary, width: 2),
        ),
        icon: Icon(Icons.map, size: 20),
        label: Text(
          'View in Map',
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
