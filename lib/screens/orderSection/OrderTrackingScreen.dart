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
      distanceFilter: 10,
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
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: [_pickupLocation!, _dropoffLocation!],
        color: Colors.blue,
        width: 3,
        patterns: [PatternItem.dash(30), PatternItem.gap(20)],
      ));

      _estimatedDistance = Geolocator.distanceBetween(
        _pickupLocation!.latitude,
        _pickupLocation!.longitude,
        _dropoffLocation!.latitude,
        _dropoffLocation!.longitude,
      ) / 1000;

      final estimatedHours = _estimatedDistance / 30;
      final minutes = (estimatedHours * 60).round();
      _estimatedTime = minutes < 60
          ? '$minutes min'
          : '${(minutes ~/ 60)}h ${minutes % 60}min';
    }
  }

  void _calculateProgress() {
    if (_pickupLocation != null && _dropoffLocation != null && _currentPosition != null) {
      final distanceFromPickup = Geolocator.distanceBetween(
        _pickupLocation!.latitude,
        _pickupLocation!.longitude,
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      final totalDistance = Geolocator.distanceBetween(
        _pickupLocation!.latitude,
        _pickupLocation!.longitude,
        _dropoffLocation!.latitude,
        _dropoffLocation!.longitude,
      );

      if (totalDistance > 0) {
        setState(() {
          _progressPercentage = (distanceFromPickup / totalDistance).clamp(0.0, 1.0);
        });
      }
    }
  }

  // Show OTP Verification Dialog
  void _showOtpDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OtpVerificationBottomSheet(
        orderId: widget.orderId,
        onVerified: _onOtpVerified,
      ),
    );
  }

  // After OTP is verified
  void _onOtpVerified() {
    setState(() {
      _isDelivered = true;
      _trackingStatus = 'delivered';
    });

    // Update order status in Firestore
    _updateOrderStatus('delivered');

    // Show rating dialog after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _showRatingDialog();
    });
  }

  Future<void> _updateOrderStatus(String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'status': status,
        'delivered_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating order status: $e');
    }
  }

  // Show Rating and Feedback Dialog
  void _showRatingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RatingFeedbackDialog(
        orderId: widget.orderId,
        deliveryPersonName: widget.orderData['delivery_person_name'] ?? 'Delivery Person',
        onSubmitted: _onRatingSubmitted,
      ),
    );
  }

  void _onRatingSubmitted() {
    // Navigate back or show success message
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you for your feedback!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _markAsReceived() {
    // Show OTP dialog when user clicks "Mark as Received"
    _showOtpDialog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition ?? const LatLng(0, 0),
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _fitMapToMarkers();
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Bottom sheet with tracking info
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.track_changes, color: Colors.blue),
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
                      _buildProgressIndicator(),
                      const SizedBox(height: 16),
                      _buildRouteInfo(),
                      const SizedBox(height: 16),
                      if (_trackingStatus == 'arrived' && !_isDelivered)
                        _buildReceivedButton(),
                    ],
                  ),
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

// OTP Verification Bottom Sheet Widget
class OtpVerificationBottomSheet extends StatefulWidget {
  final String orderId;
  final VoidCallback onVerified;

  const OtpVerificationBottomSheet({
    Key? key,
    required this.orderId,
    required this.onVerified,
  }) : super(key: key);

  @override
  State<OtpVerificationBottomSheet> createState() =>
      _OtpVerificationBottomSheetState();
}

class _OtpVerificationBottomSheetState
    extends State<OtpVerificationBottomSheet> {
  final List<TextEditingController> _otpControllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _otpValue {
    return _otpControllers.map((c) => c.text).join();
  }

  Future<void> _verifyOtp() async {
    if (_otpValue.length != 6) {
      setState(() {
        _errorMessage = 'Please enter complete OTP';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      // Get the OTP from Firestore
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();

      if (orderDoc.exists) {
        final data = orderDoc.data() as Map<String, dynamic>;
        final String? storedOtp = data['delivery_otp'];

        if (storedOtp == _otpValue) {
          // OTP is correct
          Navigator.of(context).pop();
          widget.onVerified();
        } else {
          // OTP is incorrect
          setState(() {
            _errorMessage = 'Invalid OTP. Please try again.';
            _isVerifying = false;
          });
          _clearOtp();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error verifying OTP: $e';
        _isVerifying = false;
      });
    }
  }

  void _clearOtp() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    _otpFocusNodes[0].requestFocus();
  }

  Future<void> _resendOtp() async {
    try {
      // Generate new OTP
      final newOtp = (100000 + math.Random().nextInt(900000)).toString();

      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'delivery_otp': newOtp,
        'otp_generated_at': FieldValue.serverTimestamp(),
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New OTP sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resending OTP: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'Enter OTP',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              'Please enter the OTP to complete delivery',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // OTP Input Fields
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 45,
                  height: 55,
                  child: TextField(
                    controller: _otpControllers[index],
                    focusNode: _otpFocusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 5) {
                        _otpFocusNodes[index + 1].requestFocus();
                      } else if (value.isEmpty && index > 0) {
                        _otpFocusNodes[index - 1].requestFocus();
                      }

                      // Auto-verify when all digits are entered
                      if (index == 5 && value.isNotEmpty) {
                        _verifyOtp();
                      }
                    },
                  ),
                );
              }),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Verify Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isVerifying
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text(
                  'Verify',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Resend OTP
            TextButton(
              onPressed: _resendOtp,
              child: const Text(
                'Resend OTP',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Rating and Feedback Dialog Widget
class RatingFeedbackDialog extends StatefulWidget {
  final String orderId;
  final String deliveryPersonName;
  final VoidCallback onSubmitted;

  const RatingFeedbackDialog({
    Key? key,
    required this.orderId,
    required this.deliveryPersonName,
    required this.onSubmitted,
  }) : super(key: key);

  @override
  State<RatingFeedbackDialog> createState() => _RatingFeedbackDialogState();
}

class _RatingFeedbackDialogState extends State<RatingFeedbackDialog> {
  int _selectedRating = 0;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Save rating and feedback to Firestore
      await FirebaseFirestore.instance
          .collection('order_ratings')
          .doc(widget.orderId)
          .set({
        'order_id': widget.orderId,
        'user_id': FirebaseAuth.instance.currentUser?.uid,
        'rating': _selectedRating,
        'feedback': _feedbackController.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
      });

      // Update order document with rating
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'rating': _selectedRating,
        'feedback': _feedbackController.text.trim(),
        'rated_at': FieldValue.serverTimestamp(),
      });

      Navigator.of(context).pop();
      widget.onSubmitted();
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting rating: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getRatingMessage() {
    switch (_selectedRating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),

            // Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.deliveryPersonName.substring(0, 2).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Question
            Text(
              'How was ${widget.deliveryPersonName}\'s delivery?',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              'Your feedback helps us improve future orders',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Star Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRating = starIndex;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      _selectedRating >= starIndex
                          ? Icons.star
                          : Icons.star_border,
                      size: 40,
                      color: _selectedRating >= starIndex
                          ? Colors.amber
                          : Colors.grey[400],
                    ),
                  ),
                );
              }),
            ),

            if (_selectedRating > 0) ...[
              const SizedBox(height: 8),
              Text(
                _getRatingMessage(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Feedback TextField
            TextField(
              controller: _feedbackController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Write a feedback',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}