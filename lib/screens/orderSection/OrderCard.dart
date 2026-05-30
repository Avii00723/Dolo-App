// Modern Sender Order Card - Redesigned to match new UI design
// Shows: flight route, status badge, traveler info, dotted progress tracker

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../Controllers/ordertrackingservice.dart';
import '../../theme/app_theme.dart';
import '../SupportSection/SupportScreen.dart';
import 'RatingFeedbackDialog.dart';
import 'YourOrders.dart';

class ModernSenderOrderCard extends StatefulWidget {
  final OrderDisplay order;
  final List<TripRequestDisplay>? tripRequests;
  final Function(TripRequestDisplay, String)? onAcceptRequest;
  final Function(TripRequestDisplay, String)? onDeclineRequest;
  final VoidCallback? onTrackOrder;
  final VoidCallback? onMarkReceived;
  final VoidCallback? onCompleteOrder;
  final Function(OrderDisplay)? onUpdateOrder;
  final Function(String)? onDeleteOrder;
  final Function(String orderId, String otp)? onCompleteOrderWithOtp;
  final Function(String orderId, bool confirmed)? onConfirmPickup;

  const ModernSenderOrderCard({
    super.key,
    required this.order,
    this.tripRequests,
    this.onAcceptRequest,
    this.onDeclineRequest,
    this.onTrackOrder,
    this.onMarkReceived,
    this.onCompleteOrder,
    this.onUpdateOrder,
    this.onDeleteOrder,
    this.onCompleteOrderWithOtp,
    this.onConfirmPickup,
  });

  @override
  State<ModernSenderOrderCard> createState() => _ModernSenderOrderCardState();
}

class _ModernSenderOrderCardState extends State<ModernSenderOrderCard> {
  Map<String, dynamic>? _orderDetails;
  bool _isLoadingDetails = false;

  Map<String, dynamic>? get _apiOrder =>
      _orderDetails?['order'] as Map<String, dynamic>?;

  String get _vehicleType {
    final trip = _orderDetails?['trip'] as Map<String, dynamic>?;
    final fromTrip = trip?['vehicle_type'] as String?;
    if (fromTrip?.isNotEmpty == true) return fromTrip!;
    final fromApi = _apiOrder?['vehicle_type'] as String?;
    return fromApi?.isNotEmpty == true ? fromApi! : '—';
  }

  String get _vehicleInfo {
    final trip = _orderDetails?['trip'] as Map<String, dynamic>?;
    final fromTrip = trip?['info'] as String?;
    if (fromTrip?.isNotEmpty == true) return fromTrip!;
    final fromApi = _apiOrder?['vehicle_info'] as String?;
    return fromApi?.isNotEmpty == true ? fromApi! : '—';
  }

  String get _vehicleNumber {
    final trip = _orderDetails?['trip'] as Map<String, dynamic>?;
    final fromTrip = trip?['number'] as String?;
    if (fromTrip?.isNotEmpty == true) return fromTrip!;
    final fromApi = _apiOrder?['vehicle_number'] as String?;
    return fromApi?.isNotEmpty == true ? fromApi! : '—';
  }

  String? get _apiPickupDate =>
      _apiOrder?['pickup_date'] as String? ??
      (_orderDetails?['trip'] as Map<String, dynamic>?)?['pickup_date']
          as String?;
  String? get _apiDeliveryDate => _apiOrder?['delivery_date'] as String?;

  String get _travellerName =>
      widget.order.travelerName ??
      _apiOrder?['traveller_name'] ??
      _orderDetails?['traveller_name'] ??
      'Traveller';
  String? get _travellerProfileImageUrl =>
      _apiOrder?['traveller_profile_image_url'] ??
      _orderDetails?['traveller_profile_image_url'];

  String get _displayStatus {
    final currentStage =
        OrderTrackingService.currentStageFromHistory(_orderDetails);
    if (currentStage != null) {
      return OrderTrackingService.statusFromStage(currentStage);
    }
    return _apiOrder?['status'] ??
        _orderDetails?['status'] ??
        widget.order.status;
  }

  String? get _pickupConfirmationStatus {
    final raw = _apiOrder?['pickup_confirmation_status'] ??
        _orderDetails?['pickup_confirmation_status'] ??
        widget.order.pickupConfirmationStatus;
    final value = raw?.toString().trim().toLowerCase();
    return value == null || value.isEmpty || value == 'null' ? null : value;
  }

  String get _ratingOrderStatus => _displayStatus;

  String? get _ratingFeedbackStatus {
    final raw = _apiOrder?['my_rating_status'] ??
        _orderDetails?['my_rating_status'] ??
        _apiOrder?['rating_feedback_status'] ??
        _orderDetails?['rating_feedback_status'];
    return raw;
  }

  bool get _hasCompletedRating => _ratingFeedbackStatus == 'completed';

  bool get _shouldShowRating =>
      _ratingOrderStatus == 'delivered' && !_hasCompletedRating;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    if (widget.order.status.toLowerCase() == 'pending') return;

    setState(() => _isLoadingDetails = true);
    try {
      final details =
          await OrderTrackingService().getOrderDetails(widget.order.id);
      if (mounted) {
        setState(() {
          _orderDetails = details;
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDetails = false);
      }
    }
  }

  void _showRatingDialog() {
    showDialog(
      context: context,
      builder: (_) => RatingFeedbackDialog(
        orderId: widget.order.id,
        isTraveller: false, // Sender rating traveller
        displayName: _travellerName,
        travellerId: widget.order.matchedTravellerId,
        orderDetails: _orderDetails,
        onSubmitted: _onRatingSubmitted,
      ),
    );
  }

  void _onRatingSubmitted() {
    if (!mounted) return;
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
  }

  // Map status to progress step (0-4 for 5 dots)
  int _getProgressStep() {
    return OrderTrackingService.progressStepFromStatus(_displayStatus);
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'in-transit':
      case 'in_transit':
        return AppColors.heroBlue;
      case 'delivered':
        return AppColors.sage;
      case 'pending':
        return AppColors.paleYellow;
      case 'accepted':
      case 'matched':
        return AppColors.sage;
      default:
        return AppColors.paleYellow;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'in-transit':
      case 'in_transit':
        return AppColors.primaryBlueDark;
      case 'delivered':
        return AppColors.sageDark;
      case 'pending':
        return AppColors.ink;
      case 'accepted':
      case 'matched':
        return AppColors.sageDark;
      default:
        return AppColors.ink;
    }
  }

  String _getStatusLabel(String status) {
    final normalized = status.toLowerCase().trim();
    final pickupConfirmation = _pickupConfirmationStatus;
    if (normalized == 'picked' ||
        normalized == 'picked_up' ||
        normalized == 'picked up') {
      if (pickupConfirmation == 'confirmed') return 'Picked Up';
      if (pickupConfirmation == 'rejected') return 'Pickup Rejected';
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

  @override
  Widget build(BuildContext context) {
    final progressStep = _getProgressStep();
    final displayStatus = _displayStatus;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => _showOrderDetailsScreen(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
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
                  Icon(Icons.flight_takeoff,
                      size: 20, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Origin (Line 1)
                        Text(
                          widget.order.origin,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            const Text(
                              '↓ ',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.mutedInk,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // Destination (Line 2)
                            Expanded(
                              child: Text(
                                widget.order.destination,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Dates row
                        Row(
                          children: [
                            Text(
                              _formatDisplayDate(widget.order.date),
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.62),
                              ),
                            ),
                            if (widget.order.deliveryTime != null) ...[
                              const SizedBox(width: 12),
                              Text(
                                _formatDisplayDate(widget.order.deliveryTime!),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.62),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusBgColor(displayStatus),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusLabel(displayStatus),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _getStatusTextColor(displayStatus),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Traveler Info (if matched) ──
              if (widget.order.matchedTravellerId != null ||
                  widget.order.status != 'pending') ...[
                Text(
                  'Traveler',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: colorScheme.secondary,
                      backgroundImage: widget.order.profileImageUrl != null
                          ? NetworkImage(widget.order.profileImageUrl!)
                          : null,
                      child: widget.order.profileImageUrl == null
                          ? Icon(Icons.person,
                              color: colorScheme.onSecondary, size: 20)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.order.userName != 'You'
                                ? widget.order.userName
                                : 'Matched Traveler',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.check,
                                  size: 12, color: colorScheme.secondary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else if (widget.tripRequests != null &&
                  widget.tripRequests!.isNotEmpty) ...[
                Text(
                  'Traveler',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.paleYellow.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.sage),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline,
                          color: AppColors.sageDark, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.tripRequests!.length} Request${widget.tripRequests!.length > 1 ? 's' : ''} — tap to review',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sageDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // ── Travel Detail Summary (vehicle & dates) ──
              if (!_isLoadingDetails &&
                  (_orderDetails != null ||
                      widget.order.status.toLowerCase() != 'pending')) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.directions_car_outlined,
                          size: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _vehicleType.isNotEmpty && _vehicleType != '—'
                              ? _vehicleType
                              : 'Travel details loading...',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.65),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_apiPickupDate != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today_outlined,
                            size: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.45)),
                        const SizedBox(width: 4),
                        Text(
                          _formatDisplayDate(_apiPickupDate!),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                const SizedBox(height: 4),
              ],

              // ── Dotted Progress Tracker ──
              _buildProgressDots(context, progressStep),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDots(BuildContext context, int activeStep) {
    final colorScheme = Theme.of(context).colorScheme;
    const totalSteps = 4;
    return Row(
      children: List.generate(totalSteps * 2 - 1, (i) {
        if (i.isEven) {
          final step = i ~/ 2;
          final isActive = step <= activeStep;
          return Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? colorScheme.primary : Colors.transparent,
              border: Border.all(
                color: isActive ? colorScheme.primary : AppColors.border,
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
                    color: isActive ? colorScheme.primary : AppColors.border,
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
              ),
            ),
          );
        }
      }),
    );
  }

  // ── ORDER DETAIL SCREEN (full page, like design image 2) ──
  void _showOrderDetailsScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          order: widget.order,
          tripRequests: widget.tripRequests,
          onAcceptRequest: widget.onAcceptRequest,
          onDeclineRequest: widget.onDeclineRequest,
          onTrackOrder: widget.onTrackOrder,
          onMarkReceived: widget.onMarkReceived,
          onCompleteOrder: widget.onCompleteOrder,
          onUpdateOrder: widget.onUpdateOrder,
          onDeleteOrder: widget.onDeleteOrder,
          onCompleteOrderWithOtp: widget.onCompleteOrderWithOtp,
          onConfirmPickup: widget.onConfirmPickup,
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
// ORDER DETAIL SCREEN — Full Page with OTP (Sender view: Show OTP)
// ═══════════════════════════════════════════════════
class OrderDetailScreen extends StatefulWidget {
  final OrderDisplay order;
  final List<TripRequestDisplay>? tripRequests;
  final Function(TripRequestDisplay, String)? onAcceptRequest;
  final Function(TripRequestDisplay, String)? onDeclineRequest;
  final VoidCallback? onTrackOrder;
  final VoidCallback? onMarkReceived;
  final VoidCallback? onCompleteOrder;
  final Function(OrderDisplay)? onUpdateOrder;
  final Function(String)? onDeleteOrder;
  final Function(String orderId, String otp)? onCompleteOrderWithOtp;
  final Function(String orderId, bool confirmed)? onConfirmPickup;

  const OrderDetailScreen({
    super.key,
    required this.order,
    this.tripRequests,
    this.onAcceptRequest,
    this.onDeclineRequest,
    this.onTrackOrder,
    this.onMarkReceived,
    this.onCompleteOrder,
    this.onUpdateOrder,
    this.onDeleteOrder,
    this.onCompleteOrderWithOtp,
    this.onConfirmPickup,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _packageDetailExpanded = false;
  final TextEditingController _otpController = TextEditingController();
  late OrderDisplay _order;
  bool _isUpdatingStatus = false;

  // ── Travel & rating state (mirrors TravellerOrderDetailScreen) ──
  final _trackingService = OrderTrackingService();
  Map<String, dynamic>? _orderDetails;
  bool _isLoadingDetails = false;

  // ── OTP resend state ──
  bool _isResendingOtp = false;
  int _resendCooldownSeconds = 0;
  Timer? _resendCooldownTimer;

  Map<String, dynamic>? get _apiOrder =>
      _orderDetails?['order'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _tripInfo =>
      _orderDetails?['trip'] as Map<String, dynamic>?;

  String get _vehicleType =>
      (_tripInfo?['vehicle_type'] as String?)?.isNotEmpty == true
          ? _tripInfo!['vehicle_type']
          : (_apiOrder?['vehicle_type'] as String?)?.isNotEmpty == true
              ? _apiOrder!['vehicle_type']
              : '—';
  String get _vehicleInfo => (_tripInfo?['info'] as String?)?.isNotEmpty == true
      ? _tripInfo!['info']
      : (_apiOrder?['vehicle_info'] as String?)?.isNotEmpty == true
          ? _apiOrder!['vehicle_info']
          : '—';
  String get _vehicleNumber =>
      (_tripInfo?['number'] as String?)?.isNotEmpty == true
          ? _tripInfo!['number']
          : (_apiOrder?['vehicle_number'] as String?)?.isNotEmpty == true
              ? _apiOrder!['vehicle_number']
              : '—';

  String? get _apiPickupDate =>
      _apiOrder?['pickup_date'] as String? ??
      _tripInfo?['pickup_date'] as String?;
  String? get _apiDeliveryDate =>
      _apiOrder?['delivery_date'] as String? ??
      _tripInfo?['delivery_date'] as String?;

  // Traveller name from API details
  String get _travellerName => widget.order.travelerName?.isNotEmpty == true
      ? widget.order.travelerName!
      : _apiOrder?['traveller_name']?.toString().isNotEmpty == true
          ? _apiOrder!['traveller_name']
          : _orderDetails?['traveller_name']?.toString().isNotEmpty == true
              ? _orderDetails!['traveller_name']
              : widget.order.userName;

  String? get _travellerInitial {
    final name = _travellerName;
    return name.isNotEmpty ? name[0].toUpperCase() : null;
  }

  String? get _travellerProfileImageUrl =>
      _apiOrder?['traveller_profile_image_url'] as String? ??
      _orderDetails?['traveller_profile_image_url'] as String?;

  // Authoritative status: prefer API tracking history, then API order, then local
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

  // Rating logic (mirrors TravellerOrderDetailScreen)
  String get _ratingOrderStatus => _displayStatus;

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

  String? get _pickupConfirmationStatus {
    final raw = _apiOrder?['pickup_confirmation_status'] ??
        _orderDetails?['pickup_confirmation_status'] ??
        _order.pickupConfirmationStatus;
    final value = raw?.toString().trim().toLowerCase();
    return value == null || value.isEmpty || value == 'null' ? null : value;
  }

  bool get _isWaitingForPickupConfirmation {
    final confirmation = _pickupConfirmationStatus;
    return _isPickedUpStatus(_displayStatus) &&
        (confirmation == null || confirmation == 'pending');
  }

  String? _readOtp(Map<String, dynamic>? source) {
    final raw = source?['otp'] ?? source?['delivery_otp'];
    final value = raw?.toString().trim();
    return value == null || value.isEmpty || value == 'null' ? null : value;
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
      final details = await _trackingService.getOrderDetails(_order.id);
      final otpDetails = await _trackingService.getOrderOtp(_order.id);
      // Debug prints for API responses
      try {
        print('OrderCard: getOrderDetails for ${_order.id}: $details');
      } catch (_) {}
      try {
        print('OrderCard: getOrderOtp for ${_order.id}: $otpDetails');
      } catch (_) {}
      final apiOrder = details?['order'] is Map
          ? Map<String, dynamic>.from(details!['order'] as Map)
          : null;
      final latestOtp =
          _readOtp(otpDetails) ?? _readOtp(apiOrder) ?? _readOtp(details);
      final pickupConfirmationStatus =
          apiOrder?['pickup_confirmation_status']?.toString() ??
              details?['pickup_confirmation_status']?.toString();
      if (mounted) {
        setState(() {
          _orderDetails = details;
          _order = _order.copyWith(
            otp: latestOtp,
            pickupConfirmationStatus: pickupConfirmationStatus,
          );
          _isLoadingDetails = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  void _showRatingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RatingFeedbackDialog(
        orderId: _order.id,
        isTraveller: false, // Sender rating traveller
        displayName: _travellerName.isNotEmpty ? _travellerName : 'Traveller',
        travellerId: _order.matchedTravellerId,
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

  @override
  void dispose() {
    _otpController.dispose();
    _resendCooldownTimer?.cancel();
    super.dispose();
  }

  /// Calls POST /order-tracking/track/resend-otp and then re-fetches the
  /// latest OTP so the displayed code is always up-to-date.
  Future<void> _resendOtp() async {
    if (_isResendingOtp || _resendCooldownSeconds > 0) return;
    setState(() => _isResendingOtp = true);
    try {
      await _trackingService.resendOtp(_order.id);
      // Re-fetch so the card shows the newly generated OTP.
      final otpDetails = await _trackingService.getOrderOtp(_order.id);
      final fresh = _readOtp(otpDetails);
      if (mounted) {
        setState(() {
          if (fresh != null) _order = _order.copyWith(otp: fresh);
          _isResendingOtp = false;
          _resendCooldownSeconds = 30;
        });
        _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) {
            t.cancel();
            return;
          }
          setState(() {
            _resendCooldownSeconds--;
            if (_resendCooldownSeconds <= 0) t.cancel();
          });
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP resent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResendingOtp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend OTP: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    return OrderTrackingService.progressStepFromStatus(_order.status);
  }

  bool _isPickedUpStatus(String status) {
    final normalized = status.toLowerCase().trim();
    return normalized == 'picked' ||
        normalized == 'picked_up' ||
        normalized == 'picked up';
  }

  Future<void> _confirmPickup(bool confirmed) async {
    setState(() => _isUpdatingStatus = true);
    try {
      await widget.onConfirmPickup?.call(_order.id, confirmed);
      if (!mounted) return;
      setState(() => _isUpdatingStatus = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(confirmed ? 'Pickup confirmed' : 'Pickup rejected'),
          backgroundColor: confirmed ? Colors.green : Colors.orange,
        ),
      );
      await _fetchOrderDetails();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdatingStatus = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error confirming pickup: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final displayStatus = _displayStatus;
    final progressStep =
        OrderTrackingService.progressStepFromStatus(displayStatus);
    final orderOtp = order.otp?.trim();

    // ── Determine sticky action button based on status ──
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
    } else if (displayStatus == 'pending') {
      stickyButton = Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showEditOrderDialog(context),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Order'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showDeleteConfirmation(context),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      );
    } else if (_isWaitingForPickupConfirmation) {
      stickyButton = Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isUpdatingStatus ? null : () => _confirmPickup(false),
              icon: const Icon(Icons.close_outlined, size: 18),
              label: const Text('No'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[700],
                side: BorderSide(color: Colors.red[200]!),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isUpdatingStatus ? null : () => _confirmPickup(true),
              icon: _isUpdatingStatus
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline, size: 18),
              label:
                  Text(_isUpdatingStatus ? 'Submitting...' : 'Confirm Pickup'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
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
          Container(
            margin: const EdgeInsets.only(right: 12),
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
      bottomNavigationBar: stickyButton != null
          ? Container(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: stickyButton,
            )
          : null,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Route Section ──
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
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
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
                        order.deliveryTime != null
                            ? _formatDisplayDate(order.deliveryTime!)
                            : _formatDisplayDate(order.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFEEEEEE)),

            // ── Track Package Section ──
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
                      const Expanded(
                        child: Text(
                          'Track Package',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      if (orderOtp != null && orderOtp.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          'OTP: $orderOtp',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildTrackingTimeline(progressStep),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFEEEEEE)),

            // ── Package Detail Section ──
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

                    // Always visible: Order ID + Urgent
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

                    // Expanded Details
                    if (_packageDetailExpanded) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPackageDetailItem(
                              'Package Type',
                              order.category ?? order.itemDescription,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildPackageDetailItem(
                              'Package Weight',
                              order.weight,
                            ),
                          ),
                        ],
                      ),
                      if (order.actualWeight != null ||
                          (order.customCategory?.isNotEmpty == true)) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildPackageDetailItem(
                                'Actual Weight',
                                order.actualWeight != null
                                    ? order.actualWeight.toString()
                                    : 'Not specified',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildPackageDetailItem(
                                'Custom Category',
                                order.customCategory?.isNotEmpty == true
                                    ? order.customCategory!
                                    : 'Not specified',
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (order.imageUrl != null &&
                          order.imageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Package Image',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            order.imageUrl!,
                            height: 120,
                            width: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
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
                      if (order.notes != null && order.notes!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildPackageDetailItem(
                            'Special Instructions', order.notes!),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFFEEEEEE)),

            // ── Travel Detail Section ──
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
                          child: _buildFlightDetailItem(
                              'Vehicle Type', _vehicleType)),
                      Expanded(
                          child: _buildFlightDetailItem(
                              'Vehicle Info', _vehicleInfo)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                          child: _buildFlightDetailItem(
                              'Vehicle No.', _vehicleNumber)),
                      Expanded(
                        child: _buildFlightDetailItem(
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
                        child: _buildFlightDetailItem(
                          'Delivery Date',
                          _apiDeliveryDate != null
                              ? _formatShortDate(_apiDeliveryDate!)
                              : order.deliveryTime != null
                                  ? _formatShortDate(order.deliveryTime!)
                                  : '—',
                        ),
                      ),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFEEEEEE)),

            const SizedBox(height: 16),

            // ── Sender: Show OTP card when order is 'arrived' ──
            if (displayStatus == 'arrived') ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_open_outlined,
                              color: Colors.green[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Your Delivery OTP',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.green[800],
                            ),
                          ),
                          if (_isLoadingDetails) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.green[700]),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      // OTP digits with copy-on-tap
                      GestureDetector(
                        onTap: () {
                          final otp = order.otp;
                          if (otp != null && otp.isNotEmpty) {
                            Clipboard.setData(ClipboardData(text: otp));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('OTP copied to clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              orderOtp?.isNotEmpty == true
                                  ? orderOtp!
                                  : '------',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.green[800],
                                letterSpacing: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.copy_outlined,
                                size: 18, color: Colors.green[600]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Share this OTP with the traveler to confirm delivery.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 12, color: Colors.green[700]),
                      ),
                      const SizedBox(height: 14),
                      // Resend OTP button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              (_isResendingOtp || _resendCooldownSeconds > 0)
                                  ? null
                                  : _resendOtp,
                          icon: _isResendingOtp
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh, size: 16),
                          label: Text(
                            _resendCooldownSeconds > 0
                                ? 'Resend in ${_resendCooldownSeconds}s'
                                : _isResendingOtp
                                    ? 'Resending…'
                                    : 'Resend OTP',
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green[700],
                            side: BorderSide(color: Colors.green[300]!),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Sender: in-transit or other pre-arrival active stages ──
            if (displayStatus == 'in-transit' ||
                displayStatus == 'in_transit') ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_shipping_outlined,
                          color: Colors.orange[700], size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your package is on its way! Confirm arrival once it reaches the destination.',
                          style: TextStyle(
                              fontSize: 13, color: Colors.orange[800]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Pending actions ──
            if (displayStatus == 'pending') ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    if (widget.tripRequests != null &&
                        widget.tripRequests!.isNotEmpty) ...[
                      ...widget.tripRequests!
                          .map((req) => _buildTripRequestCard(context, req)),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Traveller Info ──
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _travellerProfileImageUrl != null
                        ? NetworkImage(_travellerProfileImageUrl!)
                        : (order.profileImageUrl != null
                            ? NetworkImage(order.profileImageUrl!)
                            : null),
                    child: (_travellerProfileImageUrl == null &&
                            order.profileImageUrl == null)
                        ? Text(
                            _travellerInitial ?? 'T',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _travellerName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Traveller',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline,
                        color: Colors.black54),
                    onPressed: () {
                      // TODO: wire to your existing chat screen / chatId logic
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SizedBox.shrink(),
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
                      final rawPhone = details?['order']?['traveller_phone'] ??
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
                      // Launch phone call
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Calling $phone...')),
                      );
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

  Widget _buildPackageDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildFlightDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ],
    );
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
                      color: isActive ? Colors.black87 : Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.grey[400] : Colors.grey[200],
                    ),
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
                  decoration: i < activeStep
                      ? null
                      : isCurrent
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
                              color:
                                  isActive ? Colors.black87 : Colors.grey[400],
                            ),
                          ),
                          Text(
                            steps[i].$2,
                            style: TextStyle(
                              fontSize: 11,
                              color: isActive
                                  ? Colors.grey[600]
                                  : Colors.grey[400],
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

  void _showEnterOtpDialog(BuildContext context) {
    bool isSubmitting = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          content: Container(
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
                  'Confirm Delivery',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter the OTP provided by the traveler to confirm delivery.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _otpController,
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
                    if (errorText != null)
                      setDialogState(() => errorText = null);
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting
                            ? null
                            : () {
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
                                final otp = _otpController.text.trim();
                                if (otp.length < 4) {
                                  setDialogState(() =>
                                      errorText = 'Please enter a valid OTP');
                                  return;
                                }
                                setDialogState(() => isSubmitting = true);
                                try {
                                  await widget.onCompleteOrderWithOtp
                                      ?.call(widget.order.id, otp);
                                  if (mounted) {
                                    FocusScope.of(dialogContext).unfocus();
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext);
                                      }
                                      if (mounted) {
                                        Navigator.pop(context);
                                      }
                                    });
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
                                style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripRequestCard(
      BuildContext context, TripRequestDisplay request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[300],
                child: Text(
                  request.travellerName.isNotEmpty
                      ? request.travellerName[0].toUpperCase()
                      : 'T',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.travellerName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      request.vehicleInfo,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Order?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Order #${widget.order.id} will be permanently deleted. This action cannot be undone.',
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              widget.onDeleteOrder?.call(widget.order.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditOrderDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final originController = TextEditingController(text: widget.order.origin);
    final destinationController =
        TextEditingController(text: widget.order.destination);
    final itemDescController =
        TextEditingController(text: widget.order.itemDescription);
    final weightController =
        TextEditingController(text: widget.order.weight.toString());
    final priceController = TextEditingController(
        text: widget.order.expectedPrice?.toString() ?? '');
    final notesController =
        TextEditingController(text: widget.order.notes ?? '');
    DateTime selectedDate =
        DateTime.tryParse(widget.order.date) ?? DateTime.now();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Edit Order',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: formKey,
                      child: Column(
                        children: [
                          _editField(originController, 'Origin *',
                              Icons.radio_button_checked,
                              validator: (v) =>
                                  v?.isEmpty == true ? 'Required' : null),
                          const SizedBox(height: 14),
                          _editField(destinationController, 'Destination *',
                              Icons.location_on,
                              validator: (v) =>
                                  v?.isEmpty == true ? 'Required' : null),
                          const SizedBox(height: 14),
                          _editField(itemDescController, 'Item Description',
                              Icons.inventory_2_outlined,
                              maxLines: 2),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _editField(weightController,
                                    'Weight (kg) *', Icons.scale,
                                    keyboardType: TextInputType.number,
                                    validator: (v) =>
                                        v?.isEmpty == true ? 'Required' : null),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _editField(priceController, 'Price (₹)',
                                    Icons.currency_rupee,
                                    keyboardType: TextInputType.number),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _editField(
                              notesController, 'Notes', Icons.note_outlined,
                              maxLines: 2),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              final updated = OrderDisplay(
                                id: widget.order.id,
                                userId: widget.order.userId,
                                userName: widget.order.userName,
                                senderInitial: widget.order.senderInitial,
                                origin: originController.text.trim(),
                                destination: destinationController.text.trim(),
                                date: selectedDate.toIso8601String(),
                                itemDescription:
                                    itemDescController.text.trim().isNotEmpty
                                        ? itemDescController.text.trim()
                                        : 'Package',
                                weight: weightController.text.trim().isNotEmpty
                                    ? '${weightController.text.trim()} kg'
                                    : '0kg',
                                status: widget.order.status,
                                expectedPrice: priceController.text.isNotEmpty
                                    ? int.tryParse(priceController.text)
                                    : null,
                                notes: notesController.text.trim().isNotEmpty
                                    ? notesController.text.trim()
                                    : null,
                                originLatitude: widget.order.originLatitude,
                                originLongitude: widget.order.originLongitude,
                                destinationLatitude:
                                    widget.order.destinationLatitude,
                                destinationLongitude:
                                    widget.order.destinationLongitude,
                                orderType: widget.order.orderType,
                                estimatedDistance:
                                    widget.order.estimatedDistance,
                                requestStatus: widget.order.requestStatus,
                                imageUrl: widget.order.imageUrl,
                                profileImageUrl: widget.order.profileImageUrl,
                                matchedTravellerId:
                                    widget.order.matchedTravellerId,
                                otp: widget.order.otp,
                              );
                              Navigator.pop(context);
                              widget.onUpdateOrder?.call(updated);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
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
    );
  }

  Widget _editField(
    TextEditingController controller,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black87, width: 2),
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }
}
