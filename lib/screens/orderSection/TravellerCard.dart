// Modern Traveller Order Card - Redesigned to match new UI design
// Traveler sees OTP CODE displayed (not enter OTP)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../Controllers/ordertrackingservice.dart';
import 'YourOrders.dart';

class ModernTravellerOrderCard extends StatelessWidget {
  final OrderDisplay order;
  final VoidCallback? onTrackOrder;
  final Function(String)? onDeleteRequest;
  final Function(String)? onWithdrawRequest;
  final Function(String orderId, int currentStage)? onUpdateStatus;
  final Function(String orderId, String otp)? onCompleteOrderWithOtp;

  const ModernTravellerOrderCard({
    super.key,
    required this.order,
    this.onTrackOrder,
    this.onDeleteRequest,
    this.onWithdrawRequest,
    this.onUpdateStatus,
    this.onCompleteOrderWithOtp,
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
                  const Icon(Icons.flight_takeoff, size: 20, color: Colors.black87),
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
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusBgColor(order.requestStatus ?? order.status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusLabel(order.requestStatus ?? order.status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _getStatusTextColor(order.requestStatus ?? order.status),
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
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.grey[600] : Colors.transparent,
              border: Border.all(
                color: (isActive ? Colors.grey[600] : Colors.grey[400]) ?? Colors.grey,
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
                    color: (isActive ? Colors.grey[600] : Colors.grey[300]) ?? Colors.grey,
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

  const TravellerOrderDetailScreen({
    super.key,
    required this.order,
    this.onWithdrawRequest,
    this.onDeleteRequest,
    this.onTrackOrder,
    this.onUpdateStatus,
    this.onCompleteOrderWithOtp,
  });

  @override
  State<TravellerOrderDetailScreen> createState() =>
      _TravellerOrderDetailScreenState();
}

class _TravellerOrderDetailScreenState extends State<TravellerOrderDetailScreen> {
  bool _packageDetailExpanded = false;
  bool _isUpdatingStatus = false;
  late OrderDisplay _order; // local copy so we can update status in-place

  // Maps stage int → the status string the backend returns
  @override
  void initState() {
    super.initState();
    _order = widget.order;
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

  @override
  Widget build(BuildContext context) {
    final order = _order; // use local stateful copy
    final progressStep = _getProgressStep();

    // ── Determine which action button to show in the sticky bottom bar ──
    Widget? stickyButton;
    if (order.status.toLowerCase() == 'confirmed' ||
        order.status.toLowerCase() == 'accepted' ||
        order.status.toLowerCase() == 'matched' ||
        order.status.toLowerCase() == 'booked') {
      stickyButton = ElevatedButton.icon(
        onPressed: _isUpdatingStatus ? null : () => _updateStatus(2),
        icon: _isUpdatingStatus
            ? const SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.inventory_2_outlined, size: 18),
        label: Text(_isUpdatingStatus ? 'Updating...' : 'Mark as Picked Up'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (order.status.toLowerCase() == 'picked_up') {
      stickyButton = ElevatedButton.icon(
        onPressed: _isUpdatingStatus ? null : () => _updateStatus(3),
        icon: _isUpdatingStatus
            ? const SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.flight_land_outlined, size: 18),
        label: Text(_isUpdatingStatus ? 'Updating...' : 'Mark as Arrived'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (order.status.toLowerCase() == 'in-transit' ||
        order.status.toLowerCase() == 'in_transit') {
      stickyButton = ElevatedButton.icon(
        onPressed: _isUpdatingStatus ? null : () => _updateStatus(3),
        icon: _isUpdatingStatus
            ? const SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.flight_land_outlined, size: 18),
        label: Text(_isUpdatingStatus ? 'Updating...' : 'Mark as Arrived'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (order.status.toLowerCase() == 'arrived') {
      stickyButton = ElevatedButton.icon(
        onPressed: () => _showCompleteOrderOtpDialog(context),
        icon: const Icon(Icons.check_circle_outline, size: 18),
        label: const Text('Complete Order'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (order.status.toLowerCase() == 'pending') {
      stickyButton = OutlinedButton(
        onPressed: () {
          Navigator.pop(context);
          widget.onWithdrawRequest?.call(_order.tripRequestId ?? _order.id);
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: Colors.red[300]!),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text('Withdraw Request',
            style: TextStyle(color: Colors.red[600], fontWeight: FontWeight.w600)),
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
                            child: _buildDetailItem('Package Weight', order.weight),
                          ),
                        ],
                      ),
                      if (order.imageUrl != null && order.imageUrl!.isNotEmpty) ...[
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
                              child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
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
                        child: _buildDetailItem('Departure Date', _formatShortDate(order.date)),
                      ),
                      Expanded(
                        child: _buildDetailItem('Arrival Date', '—'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          'Airline Name',
                          order.preferenceTransport?.isNotEmpty == true
                              ? order.preferenceTransport!.first
                              : '—',
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Flight no.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
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
                      const Spacer(),
                      if (order.otp != null && order.status.toLowerCase() == 'arrived')
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: order.otp!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('OTP copied to clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'OTP: ${order.otp}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.copy, size: 14, color: Colors.black54),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildTrackingTimeline(progressStep),
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
                        'Traveler',
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

  /// Calls the parent callback, then updates local order status so the screen
  /// re-renders immediately (button changes, timeline advances, OTP button appears).
  Future<void> _updateStatus(int stage) async {
    setState(() => _isUpdatingStatus = true);
    try {
      await widget.onUpdateStatus?.call(_order.id, stage);
      if (!mounted) return;
      // Mirror the new status locally so the UI advances without a full list refresh
      final newStatus = OrderTrackingService.statusFromStage(stage);
      setState(() {
        _order = _order.copyWith(status: newStatus);
        _isUpdatingStatus = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${_statusLabel(newStatus)}'),
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

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'picked_up': return 'Picked Up';
      case 'in-transit': return 'In Transit';
      case 'arrived': return 'Arrived';
      case 'delivered': return 'Delivered';
      default: return status;
    }
  }

  void _showCompleteOrderOtpDialog(BuildContext context) {
    final otpController = TextEditingController();
    bool isSubmitting = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  child: Icon(Icons.lock_open_outlined, color: Colors.green[700], size: 28),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enter Delivery OTP',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black87),
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
                    hintStyle: TextStyle(letterSpacing: 6, color: Colors.grey[400], fontSize: 22),
                    errorText: errorText,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.green[700]!, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onChanged: (_) {
                    if (errorText != null) setDialogState(() => errorText = null);
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
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
                            setDialogState(() => errorText = 'Please enter a valid 6-digit OTP');
                            return;
                          }
                          setDialogState(() => isSubmitting = true);
                          try {
                            await widget.onCompleteOrderWithOtp?.call(_order.id, otp);
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              setState(() {
                                _order = _order.copyWith(status: 'delivered');
                              });
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorText = 'Invalid OTP. Please try again.';
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : const Text('Confirm Delivery', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      color: isActive ? Colors.black87 : (Colors.grey[400] ?? Colors.grey),
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 36,
                    color: isActive ? (Colors.grey[400] ?? Colors.grey) : (Colors.grey[200] ?? Colors.grey),
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
                              color: isActive ? Colors.black87 : (Colors.grey[400] ?? Colors.grey),
                            ),
                          ),
                          Text(
                            steps[i].$2,
                            style: TextStyle(
                              fontSize: 11,
                              color: isActive ? (Colors.grey[600] ?? Colors.grey) : (Colors.grey[400] ?? Colors.grey),
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

