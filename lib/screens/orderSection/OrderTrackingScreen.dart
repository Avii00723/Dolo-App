import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as loc;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math' as math;

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const OrderTrackingScreen({
    Key? key,
    required this.orderId,
    required this.orderData,
  }) : super(key: key);

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  GoogleMapController? _mapController;
  final loc.Location _location = loc.Location();

  // Location variables
  LatLng? _currentPosition;
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;
  LatLng? _deliveryPersonLocation;

  // Tracking state
  String _trackingStatus = 'pending';
  double _progressPercentage = 0.0;
  double _estimatedDistance = 0.0;
  String _estimatedTime = '';
  bool _isDelivered = false;

  // Map markers and polylines
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Streams
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<DocumentSnapshot>? _orderStreamSubscription;

  // Animation controller for delivery person marker
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _orderStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    await _setupInitialLocations();
    _startLocationTracking();
    _listenToOrderUpdates();
  }

  Future<void> _setupInitialLocations() async {
    try {
      // Get pickup location from order data
      if (widget.orderData['pickup_coordinates'] != null) {
        final pickupCoords = widget.orderData['pickup_coordinates'];
        _pickupLocation = LatLng(
          pickupCoords['latitude'].toDouble(),
          pickupCoords['longitude'].toDouble(),
        );
      }

      // Get dropoff location from order data
      if (widget.orderData['dropoff_coordinates'] != null) {
        final dropoffCoords = widget.orderData['dropoff_coordinates'];
        _dropoffLocation = LatLng(
          dropoffCoords['latitude'].toDouble(),
          dropoffCoords['longitude'].toDouble(),
        );
      }

      // Get current user location
      final position = await Geolocator.getCurrentPosition();
      _currentPosition = LatLng(position.latitude, position.longitude);

      _updateMarkers();
      _calculateRoute();

    } catch (e) {
      print('Error setting up locations: $e');
    }
  }

  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _updateCurrentPosition(position);
    });
  }

  void _listenToOrderUpdates() {
    _orderStreamSubscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        _updateTrackingData(data);
      }
    });
  }

  void _updateCurrentPosition(Position position) {
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    _updateMarkers();
    _calculateProgress();

    // Update delivery person location in Firestore
    _updateDeliveryPersonLocation(position);
  }

  Future<void> _updateDeliveryPersonLocation(Position position) async {
    try {
      await FirebaseFirestore.instance
          .collection('order_tracking')
          .doc(widget.orderId)
          .set({
        'order_id': widget.orderId,
        'delivery_person_id': FirebaseAuth.instance.currentUser?.uid,
        'current_latitude': position.latitude,
        'current_longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'status': _trackingStatus,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating delivery location: $e');
    }
  }

  void _updateTrackingData(Map<String, dynamic> data) {
    setState(() {
      _trackingStatus = data['status'] ?? 'pending';

      // Get delivery person location from tracking data
      if (data['delivery_person_location'] != null) {
        final deliveryCoords = data['delivery_person_location'];
        _deliveryPersonLocation = LatLng(
          deliveryCoords['latitude'].toDouble(),
          deliveryCoords['longitude'].toDouble(),
        );
      }
    });

    _updateMarkers();
    _calculateProgress();
  }

  void _updateMarkers() {
    Set<Marker> markers = {};

    // Pickup marker
    if (_pickupLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Pickup Location',
          snippet: widget.orderData['origin'] ?? '',
        ),
      ));
    }

    // Dropoff marker
    if (_dropoffLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: _dropoffLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Delivery Location',
          snippet: widget.orderData['destination'] ?? '',
        ),
      ));
    }

    // Delivery person marker (current location or live tracking)
    final deliveryPosition = _deliveryPersonLocation ?? _currentPosition;
    if (deliveryPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('delivery_person'),
        position: deliveryPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(
          title: 'Delivery Person',
          snippet: 'Current Location',
        ),
      ));
    }

    setState(() {
      _markers = markers;
    });
  }

  void _calculateRoute() {
    if (_pickupLocation != null && _dropoffLocation != null) {
      // Create polyline between pickup and dropoff
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: [_pickupLocation!, _dropoffLocation!],
        color: Colors.blue,
        width: 3,
        patterns: [PatternItem.dash(30), PatternItem.gap(20)],
      ));

      // Calculate total distance
      _estimatedDistance = Geolocator.distanceBetween(
        _pickupLocation!.latitude,
        _pickupLocation!.longitude,
        _dropoffLocation!.latitude,
        _dropoffLocation!.longitude,
      ) / 1000; // Convert to kilometers

      // Estimate time (assuming 30 km/h average speed)
      final estimatedHours = _estimatedDistance / 30;
      final minutes = (estimatedHours * 60).round();
      _estimatedTime = minutes < 60
          ? '$minutes min'
          : '${(minutes ~/ 60)}h ${minutes % 60}min';
    }
  }

  void _calculateProgress() {
    if (_pickupLocation != null && _dropoffLocation != null && _currentPosition != null) {
      // Calculate distance from pickup to current location
      final distanceFromPickup = Geolocator.distanceBetween(
        _pickupLocation!.latitude,
        _pickupLocation!.longitude,
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      // Calculate total distance from pickup to dropoff
      final totalDistance = Geolocator.distanceBetween(
        _pickupLocation!.latitude,
        _pickupLocation!.longitude,
        _dropoffLocation!.latitude,
        _dropoffLocation!.longitude,
      );

      // Calculate progress percentage
      if (totalDistance > 0) {
        setState(() {
          _progressPercentage = (distanceFromPickup / totalDistance).clamp(0.0, 1.0);

          // Update status based on progress
          if (_progressPercentage >= 0.95) {
            _trackingStatus = 'arrived';
          } else if (_progressPercentage >= 0.5) {
            _trackingStatus = 'in_transit';
          } else if (_progressPercentage >= 0.1) {
            _trackingStatus = 'picked_up';
          }
        });
      }
    }
  }

  Future<void> _markAsReceived() async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'status': 'delivered',
        'delivered_at': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isDelivered = true;
        _trackingStatus = 'delivered';
      });

      _showDeliveryConfirmation();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking as received: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeliveryConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Order Delivered!'),
          ],
        ),
        content: const Text(
          'Your order has been successfully delivered. Thank you for using our service!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(true); // Return to previous screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Your Order'),
        backgroundColor: const Color(0xFF001127),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Map view
          Expanded(
            flex: 2,
            child: GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;

                // Fit map to show all markers
                if (_markers.isNotEmpty) {
                  _fitMapToMarkers();
                }
              },
              initialCameraPosition: CameraPosition(
                target: _currentPosition ?? const LatLng(19.0760, 72.8777), // Default to Mumbai
                zoom: 12,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapType: MapType.normal,
            ),
          ),

          // Tracking information card
          Expanded(
            flex: 1,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order info header
                    Row(
                      children: [
                        Icon(
                          Icons.local_shipping,
                          color: Colors.blue[700],
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Order #${widget.orderId.substring(0, 8)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        _buildStatusChip(),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Progress indicator
                    _buildProgressIndicator(),

                    const SizedBox(height: 16),

                    // Route information
                    _buildRouteInfo(),

                    const SizedBox(height: 16),

                    // Action button
                    if (_trackingStatus == 'arrived' && !_isDelivered)
                      _buildReceivedButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    Color chipColor;
    String statusText;
    IconData statusIcon;

    switch (_trackingStatus) {
      case 'pending':
        chipColor = Colors.orange;
        statusText = 'Pending';
        statusIcon = Icons.schedule;
        break;
      case 'picked_up':
        chipColor = Colors.blue;
        statusText = 'Picked Up';
        statusIcon = Icons.local_shipping;
        break;
      case 'in_transit':
        chipColor = Colors.purple;
        statusText = 'In Transit';
        statusIcon = Icons.directions;
        break;
      case 'arrived':
        chipColor = Colors.green;
        statusText = 'Arrived';
        statusIcon = Icons.location_on;
        break;
      case 'delivered':
        chipColor = Colors.teal;
        statusText = 'Delivered';
        statusIcon = Icons.check_circle;
        break;
      default:
        chipColor = Colors.grey;
        statusText = 'Unknown';
        statusIcon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 16, color: chipColor),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: chipColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery Progress',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),

        LinearProgressIndicator(
          value: _progressPercentage,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            _trackingStatus == 'delivered' ? Colors.green : Colors.blue,
          ),
          minHeight: 6,
        ),

        const SizedBox(height: 4),

        Text(
          '${(_progressPercentage * 100).toInt()}% Complete',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildRouteInfo() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.my_location, size: 16, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text(
                    'From',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                widget.orderData['origin'] ?? 'Pickup Location',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.red[600]),
                  const SizedBox(width: 4),
                  Text(
                    'To',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                widget.orderData['destination'] ?? 'Delivery Location',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReceivedButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _markAsReceived,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline),
            SizedBox(width: 8),
            Text(
              'Mark as Received',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _fitMapToMarkers() {
    if (_markers.length > 1 && _mapController != null) {
      final bounds = _calculateBounds(_markers.map((m) => m.position).toList());
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
    }
  }

  LatLngBounds _calculateBounds(List<LatLng> positions) {
    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;

    for (final pos in positions) {
      minLat = math.min(minLat, pos.latitude);
      maxLat = math.max(maxLat, pos.latitude);
      minLng = math.min(minLng, pos.longitude);
      maxLng = math.max(maxLng, pos.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
