// Modern Sender Order Card - Redesigned to match new UI design
// Shows: flight route, status badge, traveler info, dotted progress tracker

import 'package:flutter/material.dart';
import '../../Controllers/ordertrackingservice.dart';
import 'YourOrders.dart';

class ModernSenderOrderCard extends StatelessWidget {
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
  final Function(String orderId, int stage)? onUpdateStatus;

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
    this.onUpdateStatus,
  });

  // Map status to progress step (0-4 for 5 dots)
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
    switch (status.toLowerCase()) {
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
      case 'picked_up':
        return 'Picked Up';
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
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${d.day} ${months[d.month - 1]}, ${d.year.toString().substring(2)}';
    } catch (e) {
      return date.split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressStep = _getProgressStep();

    return GestureDetector(
      onTap: () => _showOrderDetailsScreen(context),
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
                  const Icon(Icons.flight_takeoff, size: 20, color: Colors.black87),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Origin (Line 1)
                        Text(
                          order.origin,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
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
                                color: Colors.black54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // Destination (Line 2)
                            Expanded(
                              child: Text(
                                order.destination,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
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
                              _formatDisplayDate(order.date),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (order.deliveryTime != null) ...[
                              const SizedBox(width: 12),
                              Text(
                                _formatDisplayDate(order.deliveryTime!),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusBgColor(order.status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusLabel(order.status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _getStatusTextColor(order.status),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Traveler Info (if matched) ──
              if (order.matchedTravellerId != null || order.status != 'pending') ...[
                Text(
                  'Traveler',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: order.profileImageUrl != null
                          ? NetworkImage(order.profileImageUrl!)
                          : null,
                      child: order.profileImageUrl == null
                          ? Icon(Icons.person, color: Colors.grey[600], size: 20)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.userName != 'You' ? order.userName : 'Matched Traveler',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
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
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.check, size: 12, color: Colors.grey[500]),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else if (tripRequests != null && tripRequests!.isNotEmpty) ...[
                Text(
                  'Traveler',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, color: Colors.orange[700], size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '${tripRequests!.length} Request${tripRequests!.length > 1 ? 's' : ''} — tap to review',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ── Dotted Progress Tracker ──
              _buildProgressDots(progressStep),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDots(int activeStep) {
    const totalSteps = 5;
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
              color: isActive ? Colors.grey[600] : Colors.transparent,
              border: Border.all(
                color: isActive ? Colors.grey[600]! : Colors.grey[400]!,
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
                    color: isActive ? Colors.grey[600]! : Colors.grey[300]!,
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
          order: order,
          tripRequests: tripRequests,
          onAcceptRequest: onAcceptRequest,
          onDeclineRequest: onDeclineRequest,
          onTrackOrder: onTrackOrder,
          onMarkReceived: onMarkReceived,
          onCompleteOrder: onCompleteOrder,
          onUpdateOrder: onUpdateOrder,
          onDeleteOrder: onDeleteOrder,
          onCompleteOrderWithOtp: onCompleteOrderWithOtp,
          onUpdateStatus: onUpdateStatus,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// ORDER DETAIL SCREEN — Full Page with OTP (Sender view: Enter OTP)
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
  final Function(String orderId, int stage)? onUpdateStatus;

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
    this.onUpdateStatus,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _packageDetailExpanded = false;
  late OrderDisplay _order;
  bool _isUpdatingStatus = false;

  final _trackingService = OrderTrackingService();
  String? _fetchedOtp;
  DateTime? _otpExpiresAt;
  bool _isLoadingOtp = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    if (_order.status.toLowerCase() == 'arrived') {
      _fetchOtp();
    }
  }

  Future<void> _fetchOtp() async {
    if (!mounted) return;
    setState(() => _isLoadingOtp = true);
    try {
      final result = await _trackingService.getOrderOtp(_order.id);
      if (!mounted) return;
      setState(() {
        _fetchedOtp = result?['otp']?.toString();
        final expiresRaw = result?['expires_at']?.toString();
        _otpExpiresAt = expiresRaw != null ? DateTime.tryParse(expiresRaw) : null;
        _isLoadingOtp = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingOtp = false);
    }
  }

  String _formatDisplayDate(String date) {
    try {
      final DateTime d = DateTime.parse(date);
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
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
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${d.day} ${months[d.month - 1]}, ${d.year}';
    } catch (e) {
      return date.split('T').first;
    }
  }

  int _getProgressStep() {
    return OrderTrackingService.progressStepFromStatus(_order.status);
  }

  String _displayOtp() {
    if (_fetchedOtp != null && _fetchedOtp!.isNotEmpty) return _fetchedOtp!;
    final otp = _order.otp?.trim();
    return otp == null || otp.isEmpty
        ? OrderTrackingService.developmentDeliveryOtp
        : otp;
  }

  Future<void> _updateStatus(int stage) async {
    setState(() => _isUpdatingStatus = true);
    try {
      if (widget.onUpdateStatus != null) {
        await widget.onUpdateStatus!(_order.id, stage);
      }
      if (!mounted) return;
      final newStatus = OrderTrackingService.statusFromStage(stage);
      setState(() {
        _order = _order.copyWith(status: newStatus);
        _isUpdatingStatus = false;
      });
      if (stage == 3) _fetchOtp();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $newStatus'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdatingStatus = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final progressStep = _getProgressStep();

    // ── Determine sticky action button based on status ──
    Widget? stickyButton;
    if (order.status.toLowerCase() == 'pending') {
      stickyButton = Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showEditOrderDialog(context),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Order'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      );
    } else if (order.status.toLowerCase() == 'confirmed' ||
        order.status.toLowerCase() == 'accepted' ||
        order.status.toLowerCase() == 'matched' ||
        order.status.toLowerCase() == 'booked') {
      stickyButton = ElevatedButton.icon(
        onPressed: _isUpdatingStatus ? null : () => _updateStatus(2),
        icon: _isUpdatingStatus
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.inventory_2_outlined, size: 18),
        label: Text(_isUpdatingStatus ? 'Updating...' : 'Hand over: Mark as Picked Up'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 2,
        ),
      );
    } else if (order.status.toLowerCase() == 'picked_up') {
      stickyButton = ElevatedButton.icon(
        onPressed: _isUpdatingStatus ? null : () => _updateStatus(3),
        icon: _isUpdatingStatus
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.location_on_outlined, size: 18),
        label: Text(_isUpdatingStatus ? 'Updating...' : 'Confirm Arrival'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 2,
        ),
      );
    } else if (order.status.toLowerCase() == 'in-transit' || order.status.toLowerCase() == 'in_transit') {
      stickyButton = ElevatedButton.icon(
        onPressed: _isUpdatingStatus ? null : () => _updateStatus(3),
        icon: _isUpdatingStatus
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.location_on_outlined, size: 18),
        label: Text(_isUpdatingStatus ? 'Updating...' : 'Confirm Arrival'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 2,
        ),
      );
    } else if (order.status.toLowerCase() == 'arrived') {
      stickyButton = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.key_outlined, color: Colors.green[700], size: 18),
            const SizedBox(width: 8),
            Text(
              'Share your OTP above with the traveler',
              style: TextStyle(
                color: Colors.green[800],
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
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
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[200],
              child: const Icon(Icons.headset_mic_outlined, color: Colors.black54, size: 18),
            ),
          ),
        ],
      ),
      // bottomNavigationBar: stickyButton != null
      //     ? Container(
      //   padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      //   decoration: BoxDecoration(
      //     color: Colors.white,
      //     border: Border(top: BorderSide(color: Colors.grey[200]!)),
      //   ),
      //   child: stickyButton,
      // )
      //     : null,
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

            // ── Package Detail Section ──
            InkWell(
              onTap: () => setState(() => _packageDetailExpanded = !_packageDetailExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 20, color: Colors.black87),
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
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
                      if (order.imageUrl != null && order.imageUrl!.isNotEmpty) ...[
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
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
                            ),
                          ),
                        ),
                      ],
                      if (order.notes != null && order.notes!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildPackageDetailItem('Special Instructions', order.notes!),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFFEEEEEE)),

            // ── Flight Detail Section ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flight_takeoff, size: 20, color: Colors.black87),
                      const SizedBox(width: 10),
                      const Text(
                        'Flight Detail',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFlightDetailItem(
                          'Departure Date',
                          _formatShortDate(order.date),
                        ),
                      ),
                      Expanded(
                        child: _buildFlightDetailItem(
                          'Arrival Date',
                          order.deliveryTime != null
                              ? _formatShortDate(order.deliveryTime!)
                              : '—',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFlightDetailItem(
                          'Airline Name',
                          order.notes?.isNotEmpty == true
                              ? (order.preferenceTransport?.isNotEmpty == true
                              ? order.preferenceTransport!.first
                              : '—')
                              : '—',
                        ),
                      ),
                      Expanded(
                        child: _buildFlightDetailItem(
                          'Flight no.',
                          '—',
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
                      const Icon(Icons.location_on_outlined, size: 20, color: Colors.black87),
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

                  // ── Status Update Buttons (added in Track Package section) ──
                  if (order.status.toLowerCase() != 'delivered') ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Update Track Package Status',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    _buildStatusUpdateButton(order),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Sender: Show OTP card when order is 'arrived' ──
            if (order.status.toLowerCase() == 'arrived') ...[
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
                          Icon(Icons.lock_open_outlined, color: Colors.green[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Your Delivery OTP',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.green[800],
                            ),
                          ),
                          if (_isLoadingOtp) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingOtp)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: CircularProgressIndicator(color: Colors.green[700]),
                        )
                      else
                        Text(
                          _displayOtp(),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.green[800],
                            letterSpacing: 12,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Share this OTP with the traveler to confirm delivery.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.green[700]),
                      ),
                      if (_otpExpiresAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Expires at ${_otpExpiresAt!.toLocal().toString().substring(11, 16)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Sender: in-transit or other pre-arrival active stages ──
            if (order.status.toLowerCase() == 'in-transit' || order.status.toLowerCase() == 'in_transit') ...[
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
                      Icon(Icons.local_shipping_outlined, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your package is on its way! Confirm arrival once it reaches the destination.',
                          style: TextStyle(fontSize: 13, color: Colors.orange[800]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Pending actions ──
            if (order.status.toLowerCase() == 'pending') ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    if (widget.tripRequests != null && widget.tripRequests!.isNotEmpty) ...[
                      ...widget.tripRequests!.map((req) => _buildTripRequestCard(context, req)),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Order Creator Info ──
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: order.profileImageUrl != null
                        ? NetworkImage(order.profileImageUrl!)
                        : null,
                    child: order.profileImageUrl == null
                        ? Text(
                      order.userName.isNotEmpty ? order.userName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                        : null,
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
                        'Order creator',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.black54),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.call_outlined, color: Colors.black54),
                    onPressed: () {},
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

  Widget _buildStatusUpdateButton(OrderDisplay order) {
    if (order.status.toLowerCase() == 'confirmed' ||
        order.status.toLowerCase() == 'accepted' ||
        order.status.toLowerCase() == 'matched' ||
        order.status.toLowerCase() == 'booked') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isUpdatingStatus ? null : () => _updateStatus(2),
          icon: _isUpdatingStatus
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.inventory_2_outlined),
          label: Text(_isUpdatingStatus ? 'Updating...' : 'Hand over: Mark as Picked Up'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    } else if (order.status.toLowerCase() == 'picked_up') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isUpdatingStatus ? null : () => _updateStatus(3),
          icon: _isUpdatingStatus
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.location_on_outlined),
          label: Text(_isUpdatingStatus ? 'Updating...' : 'Confirm Arrival'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    } else if (order.status.toLowerCase() == 'in-transit' || order.status.toLowerCase() == 'in_transit') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isUpdatingStatus ? null : () => _updateStatus(3),
          icon: _isUpdatingStatus
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.location_on_outlined),
          label: Text(_isUpdatingStatus ? 'Updating...' : 'Confirm Arrival'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
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
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
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
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildTrackingTimeline(int activeStep) {
    final steps = [
      ('Order Confirmed', 'Order accepted'),
      ('Picked Up', 'Package collected'),
      ('In Transit', 'En-route to destination'),
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
                  decoration: isCurrent
                      ? BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  )
                      : null,
                  child: Row(
                    children: [
                      if (isCurrent) ...[
                        const Icon(Icons.chevron_right, size: 18, color: Colors.black54),
                        const SizedBox(width: 4),
                      ],
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].$1,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                              color: isActive ? Colors.black87 : Colors.grey[400],
                            ),
                          ),
                          Text(
                            steps[i].$2,
                            style: TextStyle(
                              fontSize: 11,
                              color: isActive ? Colors.grey[600] : Colors.grey[400],
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

  Widget _buildTripRequestCard(BuildContext context, TripRequestDisplay request) {
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onAcceptRequest?.call(request, widget.order.id);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Accept', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDeclineRequest?.call(request, widget.order.id);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey[400]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Decline', style: TextStyle(color: Colors.black54)),
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
        title: const Text('Delete Order?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Order #${widget.order.id} will be permanently deleted. This action cannot be undone.',
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              widget.onDeleteOrder?.call(widget.order.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    final destinationController = TextEditingController(text: widget.order.destination);
    final itemDescController = TextEditingController(text: widget.order.itemDescription);
    final weightController = TextEditingController(text: widget.order.weight.toString());
    final priceController = TextEditingController(text: widget.order.expectedPrice?.toString() ?? '');
    final notesController = TextEditingController(text: widget.order.notes ?? '');
    DateTime selectedDate = DateTime.tryParse(widget.order.date) ?? DateTime.now();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          _editField(originController, 'Origin *', Icons.radio_button_checked,
                              validator: (v) => v?.isEmpty == true ? 'Required' : null),
                          const SizedBox(height: 14),
                          _editField(destinationController, 'Destination *', Icons.location_on,
                              validator: (v) => v?.isEmpty == true ? 'Required' : null),
                          const SizedBox(height: 14),
                          _editField(itemDescController, 'Item Description', Icons.inventory_2_outlined,
                              maxLines: 2),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _editField(weightController, 'Weight (kg) *', Icons.scale,
                                    keyboardType: TextInputType.number,
                                    validator: (v) => v?.isEmpty == true ? 'Required' : null),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _editField(priceController, 'Price (₹)', Icons.currency_rupee,
                                    keyboardType: TextInputType.number),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _editField(notesController, 'Notes', Icons.note_outlined, maxLines: 2),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                                itemDescription: itemDescController.text.trim().isNotEmpty
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
                                destinationLatitude: widget.order.destinationLatitude,
                                destinationLongitude: widget.order.destinationLongitude,
                                orderType: widget.order.orderType,
                                estimatedDistance: widget.order.estimatedDistance,
                                requestStatus: widget.order.requestStatus,
                                imageUrl: widget.order.imageUrl,
                                profileImageUrl: widget.order.profileImageUrl,
                                matchedTravellerId: widget.order.matchedTravellerId,
                                otp: widget.order.otp,
                              );
                              Navigator.pop(context);
                              widget.onUpdateOrder?.call(updated);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
