// Modern Traveller Order Card - Redesigned to match new UI design
// Traveller enters the sender-provided OTP to complete delivery.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dolo/screens/Inbox Section/ChatScreen.dart';

import '../../Controllers/ordertrackingservice.dart';
import '../SupportSection/SupportScreen.dart';
import 'RatingFeedbackDialog.dart';
import 'YourOrders.dart';

class ModernTravellerOrderCard extends StatelessWidget {
  final OrderDisplay order;
  final VoidCallback? onTrackOrder;
  final Function(String)? onDeleteRequest;
  final Function(String)? onWithdrawRequest;
  final Function(String orderId, int currentStage)? onUpdateStatus;
  final Function(String orderId, String otp)? onCompleteOrderWithOtp;
  final Function(String orderId, bool confirmed)? onConfirmPickup;

  const ModernTravellerOrderCard({
    super.key,
    required this.order,
    this.onTrackOrder,
    this.onDeleteRequest,
    this.onWithdrawRequest,
    this.onUpdateStatus,
    this.onCompleteOrderWithOtp,
    this.onConfirmPickup,
  });

  int _getProgressStep() {
    return OrderTrackingService.progressStepFromStatus(order.status);
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'in-transit':
      case 'in_transit':
        return const Color(0xFFD4C88A);
      case 'delivered':
        return const Color(0xFFD4C88A);
      case 'pending':
        return const Color(0xFFE8E0C8);
      case 'accepted':
      case 'matched':
        return const Color(0xFFD0E8D0);
      default:
        return const Color(0xFFE8E0C8);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'in-transit':
      case 'in_transit':
        return const Color(0xFF5C4B00);
      case 'delivered':
        return const Color(0xFF3A3A1A);
      case 'pending':
        return const Color(0xFF6B5B00);
      case 'accepted':
      case 'matched':
        return const Color(0xFF1A5C1A);
      default:
        return const Color(0xFF6B5B00);
    }
  }

  String _getStatusLabel(String status) {
    final normalized = status.toLowerCase().trim();
    if (normalized == 'picked' ||
        normalized == 'picked_up' ||
        normalized == 'picked up') {
      final confirmation =
          order.pickupConfirmationStatus?.toLowerCase().trim() ?? '';
      if (confirmation == 'confirmed') return 'Picked Up';
      if (confirmation == 'rejected') return 'Pickup Rejected';
      return 'Pickup Requested';
    }

    switch (normalized) {
      case 'in-transit':
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'accepted':
        return 'Accepted';
      case 'matched':
        return 'Matched';
      case 'arrived':
        return 'Arrived';
      default:
        return status;
    }
  }

  String _formatDisplayDate(String date) {
    try {
      final DateTime d = DateTime.parse(date);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${d.day} ${months[d.month - 1]}, ${d.year.toString().substring(2)}';
    } catch (e) {
      return date.split('T').first;
    }
  }

  bool get _isDelivered =>
      (order.requestStatus ?? order.status).toLowerCase() == 'delivered';
  bool get _hasCompletedCardRating =>
      order.myRatingStatus?.toLowerCase() == 'completed';
  bool get _isWaitingForPickupConfirmation {
    final status = (order.requestStatus ?? order.status).toLowerCase().trim();
    final confirmation =
        order.pickupConfirmationStatus?.toLowerCase().trim() ?? '';
    return (status == 'picked' ||
            status == 'picked_up' ||
            status == 'picked up') &&
        (confirmation.isEmpty || confirmation == 'pending');
  }

  bool get _isPickupRejected {
    final status = (order.requestStatus ?? order.status).toLowerCase().trim();
    final confirmation =
        order.pickupConfirmationStatus?.toLowerCase().trim() ?? '';
    return (status == 'picked' ||
            status == 'picked_up' ||
            status == 'picked up') &&
        confirmation == 'rejected';
  }

  @override
  Widget build(BuildContext context) {
    final progressStep = _getProgressStep();

    return GestureDetector(
      onTap: () => _showTravellerDetailScreen(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Route Row ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.flight_takeoff,
                      size: 20, color: Colors.black87),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.origin,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            const Text(
                              '↓',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              order.destination,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDisplayDate(order.date),
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusBgColor(
                          order.requestStatus ?? order.status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusLabel(order.requestStatus ?? order.status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _getStatusTextColor(
                            order.requestStatus ?? order.status),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Order creator label ──
              Text(
                'Order Creator',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[300],
                    child: Text(
                      order.senderInitial,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    order.userName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Dotted Progress Tracker ──
              _buildProgressDots(progressStep),
              if (_isWaitingForPickupConfirmation || _isPickupRejected) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: (_isPickupRejected ? Colors.red : Colors.amber)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (_isPickupRejected ? Colors.red : Colors.amber)
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          _isPickupRejected
                              ? Icons.error_outline
                              : Icons.hourglass_top_outlined,
                          size: 18,
                          color: _isPickupRejected
                              ? Colors.red[700]
                              : Colors.amber[800]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isPickupRejected
                              ? 'Pickup confirmation rejected'
                              : 'Waiting for pickup confirmation',
                          style: TextStyle(
                            color: _isPickupRejected
                                ? Colors.red[700]
                                : Colors.amber[900],
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDots(int activeStep) {
    const totalSteps = 4;
    return Row(
      children: List.generate(totalSteps * 2 - 1, (i) {
        if (i.isEven) {
          final step = i ~/ 2;
          final isActive = step <= activeStep;
          return Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.grey[600] : Colors.transparent,
              border: Border.all(
                color: (isActive ? Colors.grey[600] : Colors.grey[400]) ??
                    Colors.grey,
                width: 1.5,
              ),
            ),
          );
        } else {
          final leftStep = i ~/ 2;
          final isActive = leftStep < activeStep;
          return Expanded(
            child: Container(
              height: 1.5,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: (isActive ? Colors.grey[600] : Colors.grey[300]) ??
                        Colors.grey,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          );
        }
      }),
    );
  }

  void _showTravellerDetailScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TravellerOrderDetailScreen(
          order: order,
          onWithdrawRequest: onWithdrawRequest,
          onDeleteRequest: onDeleteRequest,
          onTrackOrder: onTrackOrder,
          onUpdateStatus: onUpdateStatus,
          onCompleteOrderWithOtp: onCompleteOrderWithOtp,
          onConfirmPickup: onConfirmPickup,
        ),
      ),
    );
  }
}

class TravellerOrderDetailScreen extends StatefulWidget {
  final OrderDisplay order;
  final Function(String)? onWithdrawRequest;
  final Function(String)? onDeleteRequest;
  final VoidCallback? onTrackOrder;
  final Function(String orderId, int currentStage)? onUpdateStatus;
  final Function(String orderId, String otp)? onCompleteOrderWithOtp;
  final Function(String orderId, bool confirmed)? onConfirmPickup;

  const TravellerOrderDetailScreen({
    super.key,
    required this.order,
    this.onWithdrawRequest,
    this.onDeleteRequest,
    this.onTrackOrder,
    this.onUpdateStatus,
    this.onCompleteOrderWithOtp,
    this.onConfirmPickup,
  });

  @override
  State<TravellerOrderDetailScreen> createState() =>
      _TravellerOrderDetailScreenState();
}

class _TravellerOrderDetailScreenState
    extends State<TravellerOrderDetailScreen> {
  bool _packageDetailExpanded = false;
  bool _isUpdatingStatus = false;
  late OrderDisplay _order;

  final _trackingService = OrderTrackingService();
  Map<String, dynamic>? _orderDetails;
  bool _isLoadingDetails = false;

  Map<String, dynamic>? get _apiOrder =>
      _orderDetails?['order'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _tripInfo =>
      _orderDetails?['trip'] as Map<String, dynamic>?;
  String get _vehicleType =>
      (_tripInfo?['vehicle_type'] as String?)?.isNotEmpty == true
          ? _tripInfo!['vehicle_type']
          : '—';
  String get _vehicleInfo => (_tripInfo?['info'] as String?)?.isNotEmpty == true
      ? _tripInfo!['info']
      : '—';
  String get _vehicleNumber =>
      (_tripInfo?['number'] as String?)?.isNotEmpty == true
          ? _tripInfo!['number']
          : '—';

  String? get _apiPickupDate => _apiOrder?['pickup_date'] as String?;
  String? get _apiDeliveryDate => _apiOrder?['delivery_date'] as String?;
  String get _ratingOrderStatus =>
      _apiOrder?['status']?.toString().trim().isNotEmpty == true
          ? _apiOrder!['status'].toString().trim().toLowerCase()
          : _order.status.toLowerCase();
  String? get _ratingFeedbackStatus {
    final raw = _apiOrder?['my_rating_status'] ??
        _orderDetails?['my_rating_status'] ??
        _apiOrder?['rating_feedback_status'] ??
        _orderDetails?['rating_feedback_status'];
    final value = raw?.toString().trim().toLowerCase();
    return value == null || value.isEmpty || value == 'null' ? null : value;
  }

  bool get _hasCompletedRating => _ratingFeedbackStatus == 'completed';
  bool get _canRateOrder =>
      _ratingOrderStatus == 'delivered' && !_hasCompletedRating;

  /// Authoritative display status: prefer API tracking history, then API order, then local.
  String get _displayStatus {
    final apiStage =
        OrderTrackingService.currentStageFromHistory(_orderDetails);
    if (apiStage != null) return OrderTrackingService.statusFromStage(apiStage);
    final apiStatus = _apiOrder?['status']?.toString().trim().toLowerCase();
    if (apiStatus != null && apiStatus.isNotEmpty && apiStatus != 'null') {
      return apiStatus;
    }
    return _order.status.toLowerCase();
  }

  String? get _pickupConfirmationStatus {
    final raw = _apiOrder?['pickup_confirmation_status'] ??
        _orderDetails?['pickup_confirmation_status'] ??
        _order.pickupConfirmationStatus;
    final value = raw?.toString().trim().toLowerCase();
    return value == null || value.isEmpty || value == 'null' ? null : value;
  }

  bool get _isWaitingForPickupConfirmation {
    final status = _displayStatus;
    final confirmation = _pickupConfirmationStatus;
    return (status == 'picked' ||
            status == 'picked_up' ||
            status == 'picked up') &&
        (confirmation == null || confirmation == 'pending');
  }

  bool get _isPickupConfirmed {
    final status = _displayStatus;
    return (status == 'picked' ||
            status == 'picked_up' ||
            status == 'picked up') &&
        _pickupConfirmationStatus == 'confirmed';
  }

  bool get _isPickupRejected {
    final status = _displayStatus;
    return (status == 'picked' ||
            status == 'picked_up' ||
            status == 'picked up') &&
        _pickupConfirmationStatus == 'rejected';
  }

  void _showRatingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RatingFeedbackDialog(
        orderId: _order.id,
        isTraveller: true,
        displayName:
            _order.userName.isNotEmpty ? _order.userName : 'Order Creator',
        travellerId: null,
        orderDetails: _orderDetails,
        onSubmitted: _onRatingSubmitted,
      ),
    );
  }

  void _onRatingSubmitted() {
    if (!mounted) return;
    Navigator.of(context).pop();
    final currentOrder = Map<String, dynamic>.from(_apiOrder ?? {});
    currentOrder['my_rating_status'] = 'completed';
    currentOrder['rating_feedback_status'] = 'completed';
    setState(() {
      _orderDetails = {
        ...?_orderDetails,
        'order': currentOrder,
        'my_rating_status': 'completed',
        'rating_feedback_status': 'completed',
      };
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you for your feedback!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _fetchOrderDetails();
  }

  Future<void> _fetchOrderDetails() async {
    if (!mounted) return;
    setState(() => _isLoadingDetails = true);
    try {
      final result = await _trackingService.getOrderDetails(_order.id);
      // Debug print for API response
      try {
        print('TravellerCard: getOrderDetails for ${_order.id}: $result');
      } catch (_) {}
      if (!mounted) return;
      final apiOrder = result?['order'] is Map
          ? Map<String, dynamic>.from(result!['order'] as Map)
          : null;
      final pickupConfirmationStatus =
          apiOrder?['pickup_confirmation_status']?.toString() ??
              result?['pickup_confirmation_status']?.toString();
      setState(() {
        _orderDetails = result;
        if (pickupConfirmationStatus != null &&
            pickupConfirmationStatus.trim().isNotEmpty) {
          _order = _order.copyWith(
            pickupConfirmationStatus: pickupConfirmationStatus,
          );
        }
        _isLoadingDetails = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingDetails = false);
    }
  }

  String _formatDisplayDate(String date) {
    try {
      final DateTime d = DateTime.parse(date);
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ];
      return '${d.day} ${months[d.month - 1]}, ${d.year}';
    } catch (e) {
      return date.split('T').first;
    }
  }

  String _formatShortDate(String date) {
    try {
      final DateTime d = DateTime.parse(date);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${d.day} ${months[d.month - 1]}, ${d.year}';
    } catch (e) {
      return date.split('T').first;
    }
  }

  int _getProgressStep() {
    return OrderTrackingService.progressStepFromStatus(_displayStatus);
  }

  @override
  Widget build(BuildContext context) {
    final order = _order; // use local stateful copy
    final displayStatus = _displayStatus;
    final progressStep = _getProgressStep();

    // ── Determine which action button to show in the sticky bottom bar ──
    Widget? stickyButton;
    if (_canRateOrder) {
      stickyButton = ElevatedButton.icon(
        onPressed: _showRatingDialog,
        icon: const Icon(Icons.star_outline, size: 18),
        label: const Text('Rate & give feedback'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (_hasCompletedRating) {
      stickyButton = _buildFeedbackThankYou();
    } else if (displayStatus == 'accepted' ||
        displayStatus == 'matched' ||
        displayStatus == 'booked') {
      stickyButton = ElevatedButton.icon(
        onPressed: _isUpdatingStatus ? null : () => _updateStatus(1),
        icon: _isUpdatingStatus
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.inventory_2_outlined, size: 18),
        label: Text(_isUpdatingStatus ? 'Updating...' : 'Confirm Order'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (displayStatus == 'confirmed') {
      stickyButton = ElevatedButton.icon(
        onPressed: _isUpdatingStatus ? null : () => _updateStatus(2),
        icon: _isUpdatingStatus
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.flight_land_outlined, size: 18),
        label: Text(
            _isUpdatingStatus ? 'Updating...' : 'Request Pickup Confirmation'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (_isWaitingForPickupConfirmation) {
      stickyButton = _buildWaitingForPickupConfirmation();
    } else if (_isPickupRejected) {
      stickyButton = _buildPickupRejected();
    } else if (_isPickupConfirmed) {
      stickyButton = ElevatedButton.icon(
        onPressed: _isUpdatingStatus ? null : () => _updateStatus(3),
        icon: _isUpdatingStatus
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.flight_land_outlined, size: 18),
        label: Text(_isUpdatingStatus ? 'Updating...' : 'Mark as Arrived'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (displayStatus == 'arrived') {
      stickyButton = ElevatedButton.icon(
        onPressed: () => _showCompleteOrderOtpDialog(context),
        icon: const Icon(Icons.check_circle_outline, size: 18),
        label: const Text('Enter OTP to Complete Delivery'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (displayStatus == 'pending') {
      stickyButton = OutlinedButton(
        onPressed: () {
          Navigator.pop(context);
          widget.onWithdrawRequest?.call(_order.tripRequestId ?? _order.id);
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: Colors.red[300]!),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text('Withdraw Request',
            style:
                TextStyle(color: Colors.red[600], fontWeight: FontWeight.w600)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Order Tracking',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[200],
                child: const Icon(Icons.headset_mic_outlined,
                    color: Colors.black54, size: 18),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SupportScreen(orderId: _order.id),
                ),
              ),
            ),
          ),
        ],
      ),
      // ── Sticky action button always visible at bottom ──
      bottomNavigationBar: stickyButton != null
          ? Container(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: SizedBox(width: double.infinity, child: stickyButton),
            )
          : null,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black87,
                          border: Border.all(color: Colors.black87, width: 2),
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 32,
                        color: Colors.grey[300],
                        margin: const EdgeInsets.symmetric(vertical: 4),
                      ),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.origin,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        _formatDisplayDate(order.date),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        order.destination,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        _formatShortDate(order.date),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 20, color: Colors.black87),
                      const SizedBox(width: 10),
                      const Text(
                        'Track Package',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildTrackingTimeline(progressStep),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            InkWell(
              onTap: () => setState(
                  () => _packageDetailExpanded = !_packageDetailExpanded),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 20, color: Colors.black87),
                        const SizedBox(width: 10),
                        const Text(
                          'Package Detail',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _packageDetailExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Order ID',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '#${order.id}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (order.isUrgent == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red[600],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Urgent',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_packageDetailExpanded) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              'Package Type',
                              order.category ?? order.itemDescription,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDetailItem(
                                'Package Weight', order.weight),
                          ),
                        ],
                      ),
                      if (order.imageUrl != null &&
                          order.imageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Package Image',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            order.imageUrl!,
                            height: 120,
                            width: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.image_not_supported,
                                  color: Colors.grey[400]),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_car_outlined,
                          size: 20, color: Colors.black87),
                      const SizedBox(width: 10),
                      const Text(
                        'Travel Detail',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      if (_isLoadingDetails) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child:
                              _buildDetailItem('Vehicle Type', _vehicleType)),
                      Expanded(
                          child:
                              _buildDetailItem('Vehicle Info', _vehicleInfo)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                          child:
                              _buildDetailItem('Vehicle No.', _vehicleNumber)),
                      Expanded(
                        child: _buildDetailItem(
                          'Departure',
                          _apiPickupDate != null
                              ? _formatShortDate(_apiPickupDate!)
                              : _formatShortDate(order.date),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          'Delivery Date',
                          _apiDeliveryDate != null
                              ? _formatShortDate(_apiDeliveryDate!)
                              : '—',
                        ),
                      ),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Action buttons are now in the sticky bottomNavigationBar ──
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[300],
                    child: Text(
                      order.senderInitial,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.userName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Order Creator',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline,
                        color: Colors.black54),
                    onPressed: () {
                      // Navigate to chat between order creator and traveler.
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId: _getChatIdForOrder(order),
                            orderId: order.id,
                            otherUserName: order.userName,
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.call_outlined, color: Colors.black54),
                    onPressed: () async {
                      final details =
                          await _trackingService.getOrderDetails(order.id);
                      final rawPhone = details?['order']?['user_phone'] ??
                          details?['order']?['phone'];
                      final phone = rawPhone?.toString();
                      if (phone == null || phone.trim().isEmpty) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Phone number not available')),
                        );
                        return;
                      }
                      await _launchPhoneCall(phone);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackThankYou() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green[700], size: 18),
          const SizedBox(width: 8),
          Text(
            'Thank you for your feedback',
            style: TextStyle(
              color: Colors.green[800],
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingForPickupConfirmation() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_top_outlined,
              color: Colors.amber[800], size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Waiting for pickup confirmation',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.amber[900],
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupRejected() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red[700], size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Pickup confirmation rejected',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isUpdatingStatus ? null : () => _retryPickupConfirmation(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              _isUpdatingStatus ? 'Retrying...' : 'Retry Pickup Confirmation',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  /// Calls the parent callback, then updates local order status so the screen
  /// re-renders immediately (button changes, timeline advances, OTP button appears).
  Future<void> _updateStatus(int stage) async {
    setState(() => _isUpdatingStatus = true);
    try {
      await widget.onUpdateStatus?.call(_order.id, stage);
      if (!mounted) return;
      // Mirror the new status locally so the UI advances without a full list refresh
      final newStatus = OrderTrackingService.statusFromStage(stage);
      final updatedDetails = _orderDetails != null
          ? Map<String, dynamic>.from(_orderDetails!)
          : null;
      if (updatedDetails != null) {
        final historyKey = updatedDetails.containsKey('history')
            ? 'history'
            : updatedDetails.containsKey('tracking')
                ? 'tracking'
                : 'history';
        final rawHistory = updatedDetails[historyKey];
        final List<dynamic> historyList = rawHistory is List
            ? List<dynamic>.from(rawHistory)
            : <dynamic>[];
        historyList.add(
          {
            'stage': stage,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        updatedDetails[historyKey] = historyList;
        final apiOrderData = _apiOrder != null
            ? Map<String, dynamic>.from(_apiOrder!)
            : <String, dynamic>{};
        apiOrderData['status'] = newStatus;
        updatedDetails['order'] = apiOrderData;
      }
      setState(() {
        _order = _order.copyWith(
          status: newStatus,
          pickupConfirmationStatus:
              stage == 2 ? 'pending' : _order.pickupConfirmationStatus,
        );
        if (updatedDetails != null) {
          _orderDetails = updatedDetails;
        }
        _isUpdatingStatus = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(stage == 2
              ? 'Pickup confirmation requested'
              : 'Status updated to ${_statusLabel(newStatus)}'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdatingStatus = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _retryPickupConfirmation() async {
    await _updateStatus(2);
  }

  /// Calls the parent confirmPickup callback (which calls the REST API).
  /// Also updates local state so the "waiting" banner disappears immediately.
  Future<void> _confirmPickup(bool confirmed) async {
    setState(() => _isUpdatingStatus = true);
    try {
      if (widget.onConfirmPickup != null) {
        await widget.onConfirmPickup!.call(_order.id, confirmed);
      } else {
        // Direct API call fallback when widget is opened standalone.
        await _trackingService.confirmPickup(
          orderHashedId: _order.id,
          confirmed: confirmed,
        );
      }
      if (!mounted) return;
      setState(() {
        _isUpdatingStatus = false;
        _order = _order.copyWith(
          pickupConfirmationStatus: confirmed ? 'confirmed' : 'rejected',
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              confirmed ? 'Pickup confirmed successfully' : 'Pickup rejected'),
          backgroundColor: confirmed ? Colors.green[700] : Colors.orange[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdatingStatus = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to confirm pickup: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'picked_up':
        return 'Picked Up';
      case 'in-transit':
        return 'In Transit';
      case 'arrived':
        return 'Arrived';
      case 'delivered':
        return 'Delivered';
      default:
        return status;
    }
  }

  void _showCompleteOrderOtpDialog(BuildContext context) {
    final otpController = TextEditingController();
    bool isSubmitting = false;
    bool isResending = false;
    int resendCooldown = 0;
    Timer? cooldownTimer;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void startCooldown() {
            resendCooldown = 30;
            cooldownTimer?.cancel();
            cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
              if (!dialogContext.mounted) {
                t.cancel();
                return;
              }
              setDialogState(() {
                resendCooldown--;
                if (resendCooldown <= 0) t.cancel();
              });
            });
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: EdgeInsets.zero,
            content: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_open_outlined,
                        color: Colors.green[700], size: 28),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Enter Delivery OTP',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ask the order creator for the OTP to confirm delivery.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 10,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '• • • • • •',
                      hintStyle: TextStyle(
                          letterSpacing: 6,
                          color: Colors.grey[400],
                          fontSize: 22),
                      errorText: errorText,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.green[700]!, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.red, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onChanged: (_) {
                      if (errorText != null) {
                        setDialogState(() => errorText = null);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // ── Resend OTP (triggers sender to receive a new OTP) ──
                  TextButton.icon(
                    onPressed: (isResending || resendCooldown > 0)
                        ? null
                        : () async {
                            setDialogState(() => isResending = true);
                            try {
                              await _trackingService.resendOtp(_order.id);
                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  isResending = false;
                                });
                                startCooldown();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('OTP resent to the order creator'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (dialogContext.mounted) {
                                setDialogState(() => isResending = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to resend OTP: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    icon: isResending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh, size: 16),
                    label: Text(
                      resendCooldown > 0
                          ? 'Resend in ${resendCooldown}s'
                          : isResending
                              ? 'Resending…'
                              : 'Resend OTP to creator',
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSubmitting
                              ? null
                              : () {
                                  cooldownTimer?.cancel();
                                  FocusScope.of(dialogContext).unfocus();
                                  Navigator.pop(dialogContext);
                                },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Cancel',
                              style: TextStyle(color: Colors.black54)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final otp = otpController.text.trim();
                                  if (otp.length != 6) {
                                    setDialogState(() => errorText =
                                        'Please enter a valid 6-digit OTP');
                                    return;
                                  }
                                  setDialogState(() => isSubmitting = true);
                                  try {
                                    if (widget.onCompleteOrderWithOtp != null) {
                                      await widget.onCompleteOrderWithOtp!(
                                          _order.id, otp);
                                    } else {
                                      await _trackingService
                                          .verifyOtpAndComplete(_order.id, otp);
                                    }
                                    cooldownTimer?.cancel();
                                    if (mounted) {
                                      FocusScope.of(dialogContext).unfocus();
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext);
                                        }
                                      });
                                      setState(() {
                                        _order = _order.copyWith(
                                            status: 'delivered');
                                      });
                                      _fetchOrderDetails();
                                    }
                                  } catch (e) {
                                    setDialogState(() {
                                      isSubmitting = false;
                                      errorText =
                                          'Invalid OTP. Please try again.';
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Confirm Delivery',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  String _getChatIdForOrder(OrderDisplay order) {
    // Fallback implementation: if your backend uses a dedicated chat id,
    // replace this with the proper field (e.g., order.chatId).
    // Using order id as a stable chatId prevents crashes.
    return order.id.toString();
  }

  Future<void> _launchPhoneCall(String phoneNumber) async {
    final cleaned = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open phone app'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildTrackingTimeline(int activeStep) {
    final steps = [
      ('Order Confirmed', 'Order accepted'),
      ('Picked Up', 'Package collected'),
      ('Arrived', 'At destination'),
      ('Delivered', 'Delivery complete'),
    ];

    return Column(
      children: List.generate(steps.length, (i) {
        final isActive = i <= activeStep;
        final isCurrent = i == activeStep;
        final isLast = i == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? Colors.black87 : Colors.transparent,
                    border: Border.all(
                      color: isActive
                          ? Colors.black87
                          : (Colors.grey[400] ?? Colors.grey),
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 36,
                    color: isActive
                        ? (Colors.grey[400] ?? Colors.grey)
                        : (Colors.grey[200] ?? Colors.grey),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: Container(
                  padding: isCurrent
                      ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                      : EdgeInsets.zero,
                  decoration: isCurrent
                      ? BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        )
                      : null,
                  child: Row(
                    children: [
                      if (isCurrent) ...[
                        const Icon(Icons.chevron_right,
                            size: 18, color: Colors.black54),
                        const SizedBox(width: 4),
                      ],
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].$1,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isCurrent ? FontWeight.w700 : FontWeight.w500,
                              color: isActive
                                  ? Colors.black87
                                  : (Colors.grey[400] ?? Colors.grey),
                            ),
                          ),
                          Text(
                            steps[i].$2,
                            style: TextStyle(
                              fontSize: 11,
                              color: isActive
                                  ? (Colors.grey[600] ?? Colors.grey)
                                  : (Colors.grey[400] ?? Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
