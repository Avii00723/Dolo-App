import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math' as math;

import '../../Controllers/ordertrackingservice.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  /// Pass `true` if the current user is the traveller (delivery person),
  /// `false` if they are the order creator (sender).
  final bool isTraveller;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.orderData,
    required this.isTraveller,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  GoogleMapController? _mapController;

  // Location variables
  LatLng? _currentPosition;
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;
  LatLng? _deliveryPersonLocation;

  // Tracking state
  String _trackingStatus = 'pending';
  int _trackingStage = 0; // 0=confirmed, 1=picked_up, 2=in_transit, 3=arrived, 4=delivered
  double _progressPercentage = 0.0;
  bool _isDelivered = false;
  bool _isUpdatingStatus = false;
  bool _hasApiTrackingHistory = false;

  // OTP for order creator (visible at stage 3)
  String? _orderOtp;

  // Map markers and polylines
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Streams
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<DocumentSnapshot>? _orderStreamSubscription;

  final OrderTrackingService _trackingService = OrderTrackingService();

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
    await _refreshTrackingHistory();
    _startLocationTracking();
    _listenToOrderUpdates();
  }

  Future<void> _setupInitialLocations() async {
    try {
      if (widget.orderData['pickup_coordinates'] != null) {
        final pickupCoords = widget.orderData['pickup_coordinates'];
        _pickupLocation = LatLng(
          pickupCoords['latitude'].toDouble(),
          pickupCoords['longitude'].toDouble(),
        );
      } else if (widget.orderData['origin_latitude'] != null) {
        _pickupLocation = LatLng(
          widget.orderData['origin_latitude'].toDouble(),
          widget.orderData['origin_longitude'].toDouble(),
        );
      }

      if (widget.orderData['dropoff_coordinates'] != null) {
        final dropoffCoords = widget.orderData['dropoff_coordinates'];
        _dropoffLocation = LatLng(
          dropoffCoords['latitude'].toDouble(),
          dropoffCoords['longitude'].toDouble(),
        );
      } else if (widget.orderData['destination_latitude'] != null) {
        _dropoffLocation = LatLng(
          widget.orderData['destination_latitude'].toDouble(),
          widget.orderData['destination_longitude'].toDouble(),
        );
      }

      final position = await Geolocator.getCurrentPosition();
      _currentPosition = LatLng(position.latitude, position.longitude);

      _updateMarkers();
      _calculateRoute();
    } catch (e) {
      debugPrint('Error setting up locations: $e');
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
    if (!mounted) return;
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
      debugPrint('Error updating delivery location: $e');
    }
  }

  void _updateTrackingData(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      final fallbackStatus = data['status'] ?? 'pending';
      if (!_hasApiTrackingHistory) {
        _trackingStatus = fallbackStatus;
        _trackingStage = _statusToStage(_trackingStatus);
      }

      // Order creator sees their OTP once order is at stage 3 (arrived)
      if (!widget.isTraveller && _trackingStage >= 3) {
        _orderOtp = data['delivery_otp'] as String?;
      }

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

  int _statusToStage(String status) {
    return OrderTrackingService.progressStepFromStatus(status);
  }

  Future<void> _refreshTrackingHistory() async {
    final history = await _trackingService.getTrackingHistory(widget.orderId);
    final apiStage = OrderTrackingService.currentStageFromHistory(history);
    if (apiStage == null || !mounted) return;

    setState(() {
      _hasApiTrackingHistory = true;
      _trackingStatus = OrderTrackingService.statusFromStage(apiStage);
      _trackingStage = _statusToStage(_trackingStatus);
      _isDelivered = _trackingStatus == 'delivered';
    });
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

    if (!mounted) return;
    setState(() {
      _markers = markers;
    });
  }

  void _calculateRoute() {
    if (_pickupLocation != null && _dropoffLocation != null) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: [_pickupLocation!, _dropoffLocation!],
        color: const Color(0xFF3E83AE),
        width: 3,
        patterns: [PatternItem.dash(30), PatternItem.gap(20)],
      ));
    }
  }

  void _calculateProgress() {
    if (_pickupLocation != null &&
        _dropoffLocation != null &&
        _currentPosition != null) {
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
        if (!mounted) return;
        setState(() {
          _progressPercentage =
              (distanceFromPickup / totalDistance).clamp(0.0, 1.0);
        });
      }
    }
  }

  // ─── Status Update (Traveller only: stages 0-2) ───────────────────────────

  Future<void> _updateStatus() async {
    if (_isUpdatingStatus || _trackingStage >= 3) return;

    setState(() => _isUpdatingStatus = true);

    try {
      final nextStage = _nextApiStage();
      final success = await _trackingService.updateTrackingStage(
        widget.orderId,
        nextStage,
      );

      if (success && mounted) {
        await _refreshTrackingHistory();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getStageUpdateMessage(nextStage)),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  int _nextApiStage() {
    switch (_trackingStatus.toLowerCase()) {
      case 'confirmed':
      case 'accepted':
      case 'matched':
      case 'booked':
        return 2;
      case 'picked_up':
      case 'in_transit':
      case 'in-transit':
        return 3;
      default:
        return 1;
    }
  }

  String _getStageUpdateMessage(int newStage) {
    switch (newStage) {
      case 1:
        return 'Order confirmed';
      case 2:
        return 'Order marked as Picked Up';
      case 3:
        return 'Order has arrived at destination';
      case 4:
        return 'Order successfully delivered!';
      default:
        return 'Status updated';
    }
  }

  String _getNextStatusLabel() {
    switch (_trackingStage) {
      case 0:
        return 'Mark as Picked Up';
      case 1:
        return 'Mark as Arrived';
      default:
        return '';
    }
  }

  IconData _getNextStatusIcon() {
    switch (_trackingStage) {
      case 0:
        return Icons.inventory_2_outlined;
      case 1:
        return Icons.location_on_outlined;
      default:
        return Icons.check_circle_outline;
    }
  }

  // ─── OTP Flow (Traveller: Complete Order dialog) ──────────────────────────

  void _showCompleteOrderDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CompleteOrderBottomSheet(
        orderId: widget.orderId,
        onCompleted: _onOrderCompleted,
        trackingService: _trackingService,
      ),
    );
  }

  void _onOrderCompleted() {
    if (!mounted) return;
    setState(() {
      _isDelivered = true;
      _trackingStatus = 'delivered';
      _trackingStage = 4;
    });

    _updateOrderStatusFirestore('delivered');

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _showRatingDialog();
    });
  }

  // ─── OTP Display (Order Creator at stage 3) ───────────────────────────────

  void _showOtpDisplayDialog() {
    showDialog(
      context: context,
      builder: (context) => OtpDisplayDialog(
        otp: (_orderOtp?.trim().isNotEmpty ?? false)
            ? _orderOtp!.trim()
            : OrderTrackingService.developmentDeliveryOtp,
      ),
    );
  }

  // ─── Firestore status sync ────────────────────────────────────────────────

  Future<void> _updateOrderStatusFirestore(String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'status': status,
        'delivered_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating order status: $e');
    }
  }

  // ─── Rating Dialog ────────────────────────────────────────────────────────

  void _showRatingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RatingFeedbackDialog(
        orderId: widget.orderId,
        deliveryPersonName:
        widget.orderData['delivery_person_name'] ?? 'Delivery Person',
        onSubmitted: _onRatingSubmitted,
      ),
    );
  }

  void _onRatingSubmitted() {
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you for your feedback!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

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

          // Bottom Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
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
                      // Header row
                      Row(
                        children: [
                          Icon(Icons.track_changes,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Order Tracking',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          _buildStatusChip(),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Stage progress stepper
                      _buildStageStepper(),

                      const SizedBox(height: 16),

                      // Route info
                      _buildRouteInfo(),

                      const SizedBox(height: 16),

                      // Role-specific action buttons
                      _buildActionArea(),
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

  // ─── Stage Stepper ────────────────────────────────────────────────────────

  Widget _buildStageStepper() {
    final stages = [
      _StageItem(icon: Icons.check_circle_outline, label: 'Confirmed'),
      _StageItem(icon: Icons.inventory_2_outlined, label: 'Picked Up'),
      _StageItem(icon: Icons.local_shipping_outlined, label: 'In Transit'),
      _StageItem(icon: Icons.location_on_outlined, label: 'Arrived'),
      _StageItem(icon: Icons.celebration_outlined, label: 'Delivered'),
    ];

    final primary = Theme.of(context).colorScheme.primary;
    final inactive =
    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2);

    return Row(
      children: List.generate(stages.length, (i) {
        final isActive = i <= _trackingStage;
        final isLast = i == stages.length - 1;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isActive ? primary : inactive,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        stages[i].icon,
                        size: 17,
                        color: isActive
                            ? Colors.white
                            : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stages[i].label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w400,
                        color: isActive
                            ? primary
                            : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 2,
                      color: i < _trackingStage ? primary : inactive,
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  // ─── Action Area ──────────────────────────────────────────────────────────

  Widget _buildActionArea() {
    if (_trackingStage == 4) {
      return _buildDeliveredBanner();
    }

    if (widget.isTraveller) {
      // TRAVELLER VIEW
      if (_trackingStage < 3) {
        return _buildUpdateStatusButton();
      } else {
        // Stage 3 arrived → complete order
        return _buildCompleteOrderButton();
      }
    } else {
      // ORDER CREATOR VIEW
      if (_trackingStage == 3) {
        return _buildCreatorOtpSection();
      }
      return _buildCreatorWaitingInfo();
    }
  }

  Widget _buildUpdateStatusButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isUpdatingStatus ? null : _updateStatus,
        icon: _isUpdatingStatus
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Icon(_getNextStatusIcon()),
        label: Text(
          _isUpdatingStatus ? 'Updating…' : _getNextStatusLabel(),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildCompleteOrderButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _showCompleteOrderDialog,
        icon: const Icon(Icons.lock_open_outlined),
        label: const Text(
          'Complete Order',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildCreatorOtpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border:
            Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.delivery_dining,
                  color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your traveller has arrived! Share your OTP to confirm delivery.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _showOtpDisplayDialog,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text(
              'View My OTP',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreatorWaitingInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your OTP will appear here once the traveller arrives.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveredBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text(
            'Order successfully delivered 🎉',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Status Chip ──────────────────────────────────────────────────────────

  Widget _buildStatusChip() {
    Color chipColor;
    String statusText;
    IconData statusIcon;

    switch (_trackingStatus.toLowerCase()) {
      case 'pending':
        chipColor = Colors.orange;
        statusText = 'Pending';
        statusIcon = Icons.schedule;
        break;
      case 'picked_up':
        chipColor = Theme.of(context).colorScheme.primary;
        statusText = 'Picked Up';
        statusIcon = Icons.local_shipping;
        break;
      case 'in_transit':
      case 'in-transit':
        chipColor = Colors.purple;
        statusText = 'In Transit';
        statusIcon = Icons.directions;
        break;
      case 'arrived':
        chipColor = Colors.orange;
        statusText = 'Arrived';
        statusIcon = Icons.location_on;
        break;
      case 'delivered':
        chipColor = Colors.green;
        statusText = 'Delivered';
        statusIcon = Icons.check_circle;
        break;
      default:
        chipColor = Colors.grey;
        statusText = 'Confirmed';
        statusIcon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
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

  // ─── Route Info ───────────────────────────────────────────────────────────

  Widget _buildRouteInfo() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.my_location,
                      size: 16, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text(
                    'From',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                widget.orderData['origin'] ?? 'Pickup Location',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
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
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                widget.orderData['destination'] ?? 'Delivery Location',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
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

  void _fitMapToMarkers() {
    if (_markers.length > 1 && _mapController != null) {
      final bounds =
      _calculateBounds(_markers.map((m) => m.position).toList());
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

// ─── Helper model ──────────────────────────────────────────────────────────────

class _StageItem {
  final IconData icon;
  final String label;
  _StageItem({required this.icon, required this.label});
}

// ──────────────────────────────────────────────────────────────────────────────
// Complete Order Bottom Sheet — Traveller enters OTP to finish delivery
// ──────────────────────────────────────────────────────────────────────────────

class CompleteOrderBottomSheet extends StatefulWidget {
  final String orderId;
  final VoidCallback onCompleted;
  final OrderTrackingService trackingService;

  const CompleteOrderBottomSheet({
    super.key,
    required this.orderId,
    required this.onCompleted,
    required this.trackingService,
  });

  @override
  State<CompleteOrderBottomSheet> createState() =>
      _CompleteOrderBottomSheetState();
}

class _CompleteOrderBottomSheetState extends State<CompleteOrderBottomSheet> {
  final List<TextEditingController> _otpControllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final digits = OrderTrackingService.developmentDeliveryOtp.split('');
    for (var i = 0; i < _otpControllers.length && i < digits.length; i++) {
      _otpControllers[i].text = digits[i];
    }
  }

  @override
  void dispose() {
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var n in _otpFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _otpValue => _otpControllers.map((c) => c.text).join();

  Future<void> _verifyAndComplete() async {
    if (_otpValue.length != 6) {
      setState(
              () => _errorMessage = 'Please enter the complete 6-digit OTP');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      // Use the verified API endpoint provided in the prompt
      await widget.trackingService.verifyOtpAndComplete(widget.orderId, _otpValue);

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCompleted();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Invalid OTP. Please try again.';
        _isVerifying = false;
      });
      _clearOtp();
    }
  }

  void _clearOtp() {
    for (var c in _otpControllers) {
      c.clear();
    }
    if (_otpFocusNodes.isNotEmpty) {
      _otpFocusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_open_outlined,
                  color: Colors.green, size: 32),
            ),
            const SizedBox(height: 16),

            const Text(
              'Complete Order',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),

            Text(
              'Ask the recipient for their OTP and\nenter it below to confirm delivery.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // OTP Fields
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (i) {
                return SizedBox(
                  width: 44,
                  height: 54,
                  child: TextField(
                    controller: _otpControllers[i],
                    focusNode: _otpFocusNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: Theme.of(context).dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: Theme.of(context).dividerColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: primary, width: 2),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && i < 5) {
                        _otpFocusNodes[i + 1].requestFocus();
                      } else if (value.isEmpty && i > 0) {
                        _otpFocusNodes[i - 1].requestFocus();
                      }
                      if (i == 5 && value.isNotEmpty) {
                        _verifyAndComplete();
                      }
                    },
                  ),
                );
              }),
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Confirm button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isVerifying ? null : _verifyAndComplete,
                icon: _isVerifying
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isVerifying ? 'Verifying…' : 'Confirm Delivery',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// OTP Display Dialog — Order Creator sees their OTP at stage 3
// ──────────────────────────────────────────────────────────────────────────────

class OtpDisplayDialog extends StatelessWidget {
  final String otp;

  const OtpDisplayDialog({super.key, required this.otp});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final digits = otp.padRight(6, '-').split('');

    return Dialog(
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.key_outlined, color: primary, size: 32),
            ),
            const SizedBox(height: 16),

            const Text(
              'Your Delivery OTP',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Text(
              'Share this code with your traveller\nto confirm receipt of your order.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // OTP digits display (read-only)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: digits.map((d) {
                return Container(
                  width: 42,
                  height: 52,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: primary.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: d == '-'
                            ? Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.2)
                            : primary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Security note
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined,
                      color: Colors.amber, size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Only share this OTP with your traveller when you physically receive your package.',
                      style: TextStyle(fontSize: 11, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Got it',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Rating & Feedback Dialog (unchanged from original)
// ──────────────────────────────────────────────────────────────────────────────

class RatingFeedbackDialog extends StatefulWidget {
  final String orderId;
  final String deliveryPersonName;
  final VoidCallback onSubmitted;

  const RatingFeedbackDialog({
    super.key,
    required this.orderId,
    required this.deliveryPersonName,
    required this.onSubmitted,
  });

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
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

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'rating': _selectedRating,
        'feedback': _feedbackController.text.trim(),
        'rated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSubmitted();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
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
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.deliveryPersonName.isNotEmpty ? widget.deliveryPersonName.substring(0, 2).toUpperCase() : 'DP',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'How was ${widget.deliveryPersonName}\'s delivery?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your feedback helps us improve future orders',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedRating = starIndex),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      _selectedRating >= starIndex
                          ? Icons.star
                          : Icons.star_border,
                      size: 40,
                      color: _selectedRating >= starIndex
                          ? Colors.amber
                          : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.25),
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _feedbackController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Write a feedback',
                hintStyle: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.35)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  BorderSide(color: Theme.of(context).dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  BorderSide(color: Theme.of(context).dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text(
                  'Done',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
