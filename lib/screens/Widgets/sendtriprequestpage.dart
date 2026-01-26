
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../Constants/colorconstant.dart';
import '../../Controllers/TripRequestService.dart';
import '../../Models/OrderModel.dart';
import '../../Models/TripRequestModel.dart';
import '../../widgets/NotificationBellIcon.dart';

class SendTripRequestPage extends StatefulWidget {
  final Order order;
  final String currentUserId;
  final TripRequestService tripRequestService;
  final Function(String tripRequestId, String orderOwner) onSuccess;
  final String departureDate;
  final String departureTime;
  final String deliveryDate;
  final String deliveryTime;

  const SendTripRequestPage({
    Key? key,
    required this.order,
    required this.currentUserId,
    required this.tripRequestService,
    required this.onSuccess,
    required this.departureDate,
    required this.departureTime,
    required this.deliveryDate,
    required this.deliveryTime,
  }) : super(key: key);

  @override
  State<SendTripRequestPage> createState() => _SendTripRequestPageState();
}

class _SendTripRequestPageState extends State<SendTripRequestPage> {
  final vehicleInfoController = TextEditingController();
  final commentsController = TextEditingController();
  final pnrController = TextEditingController(); // NEW: For PNR/Ticket number
  bool isSubmitting = false;

  @override
  void dispose() {
    vehicleInfoController.dispose();
    commentsController.dispose();
    pnrController.dispose();
    super.dispose();
  }

  // Get PNR input hint based on transport mode
  String _getPnrHint(String transportMode) {
    switch (transportMode.toLowerCase()) {
      case 'train':
        return 'Enter 10-digit PNR (e.g., 1234567890)';
      case 'flight':
      case 'plane':
        return 'Enter flight booking reference or PNR';
      case 'bus':
        return 'Enter bus ticket number';
      default:
        return 'Enter ticket/PNR number (optional)';
    }
  }

  // Get placeholder text based on transport mode
  String _getPnrPlaceholder(String transportMode) {
    switch (transportMode.toLowerCase()) {
      case 'train':
        return 'PNR: 1234567890';
      case 'flight':
      case 'plane':
        return 'Booking Ref/PNR';
      case 'bus':
        return 'Ticket Number';
      default:
        return 'Ticket/PNR';
    }
  }

  // Validate PNR format
  bool _validatePnrFormat(String transportMode, String pnr) {
    if (pnr.isEmpty) return true; // PNR is optional

    switch (transportMode.toLowerCase()) {
      case 'train':
      // Train PNR should be exactly 10 digits
        return RegExp(r'^\d{10}$').hasMatch(pnr);
      case 'flight':
      case 'plane':
      // Flight booking reference: 6 alphanumeric characters or PNR format
        return pnr.length >= 5 && pnr.length <= 10;
      case 'bus':
      // Bus ticket: 6-20 alphanumeric characters
        return pnr.length >= 6 && pnr.length <= 20;
      default:
        return pnr.length >= 5 && pnr.length <= 20;
    }
  }

  Widget _buildReadOnlyDateTimeField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green
                  ? Icons.check_circle
                  : color == Colors.red
                  ? Icons.error_outline
                  : Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _submitRequest() async {
    // Validate required fields
    if (vehicleInfoController.text.trim().isEmpty) {
      _showSnackBar('Please enter vehicle information', Colors.red);
      return;
    }

    // Validate PNR format if provided
    final pnr = pnrController.text.trim();
    if (pnr.isNotEmpty && !_validatePnrFormat(widget.order.transportMode, pnr)) {
      String formatHint;
      switch (widget.order.transportMode.toLowerCase()) {
        case 'train':
          formatHint = 'Train PNR must be exactly 10 digits';
          break;
        case 'flight':
        case 'plane':
          formatHint = 'Flight booking reference must be 5-10 characters';
          break;
        case 'bus':
          formatHint = 'Bus ticket must be 6-20 characters';
          break;
        default:
          formatHint = 'Invalid ticket format';
      }
      _showSnackBar(formatHint, Colors.red);
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      // Build ISO datetime strings: YYYY-MM-DDTHH:MM:SSZ
      final departureDatetime = '${widget.departureDate}T${widget.departureTime}Z';
      final deliveryDatetime = '${widget.deliveryDate}T${widget.deliveryTime}Z';

      final tripRequest = TripRequestSendRequest(
        travelerId: widget.currentUserId,
        orderId: widget.order.id,
        travelDate: deliveryDatetime, // travel_date = delivery datetime
        vehicleInfo: vehicleInfoController.text.trim(),
        vehicleType: widget.order.transportMode, // Use transport mode from order
        pnr: pnr.isNotEmpty ? pnr : null, // Optional PNR
        source: widget.order.origin,
        destination: widget.order.destination,
        departureDatetime: departureDatetime,
        comments: commentsController.text.trim().isNotEmpty
            ? commentsController.text.trim()
            : null,
      );

      print('DEBUG: Sending trip request...');
      print('DEBUG: Traveler ID: ${widget.currentUserId}');
      print('DEBUG: Order ID: ${widget.order.id}');
      print('DEBUG: Travel Date (delivery): $deliveryDatetime');
      print('DEBUG: Departure Datetime: $departureDatetime');
      print('DEBUG: Vehicle Type: ${widget.order.transportMode}');
      print('DEBUG: PNR: $pnr');

      final response = await widget.tripRequestService.sendTripRequest(tripRequest);

      if (mounted) {
        setState(() {
          isSubmitting = false;
        });

        if (response != null) {
          Navigator.pop(context);
          widget.onSuccess(response.tripRequestId, widget.order.userName);
        } else {
          _showSnackBar('Failed to send request. Please try again.', Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
        print('ERROR: Failed to send trip request: $e');
        _showSnackBar('Failed to send request: $e', Colors.red);
      }
    }
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
              border: InputBorder.none,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Send Trip Request',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          NotificationBellIcon(
            iconColor: Colors.white,
            onNotificationHandled: () {
              print('🔔 SendPage: Notification handled callback');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header card with order info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.1),
                          AppColors.primary.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.local_shipping,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order #${widget.order.id}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'By ${widget.order.userName}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildReadOnlyField(
                    label: 'From',
                    value: widget.order.origin,
                    icon: Icons.trip_origin,
                  ),
                  const SizedBox(height: 16),
                  _buildReadOnlyField(
                    label: 'To',
                    value: widget.order.destination,
                    icon: Icons.location_on,
                  ),
                  const SizedBox(height: 24),

                  // Divider
                  Container(
                    height: 1,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Your Trip Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildEnhancedTextField(
                    controller: vehicleInfoController,
                    label: 'Vehicle Information',
                    hint: 'e.g., Maruti Suzuki Swift, AC',
                    icon: Icons.directions_car,
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),

                  // PNR/Ticket Section (only for Train, Flight, Bus)
                  if (widget.order.transportMode.toLowerCase() == 'train' ||
                      widget.order.transportMode.toLowerCase() == 'flight' ||
                      widget.order.transportMode.toLowerCase() == 'plane' ||
                      widget.order.transportMode.toLowerCase() == 'bus') ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.shade200,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                widget.order.transportMode.toLowerCase() == 'train'
                                    ? Icons.train
                                    : widget.order.transportMode.toLowerCase() == 'bus'
                                    ? Icons.directions_bus
                                    : Icons.flight,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Ticket/PNR Number',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'OPTIONAL',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _getPnrHint(widget.order.transportMode),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: TextField(
                              controller: pnrController,
                              keyboardType: TextInputType.text,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: _getPnrPlaceholder(
                                    widget.order.transportMode),
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                ),
                                prefixIcon: Icon(
                                  Icons.confirmation_number,
                                  color: Colors.blue.shade700,
                                  size: 20,
                                ),
                                border: InputBorder.none,
                                contentPadding:
                                const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  _buildReadOnlyDateTimeField(
                    label: 'Departure Date & Time',
                    value: '${widget.departureDate} ${widget.departureTime}',
                    icon: Icons.flight_takeoff,
                  ),
                  const SizedBox(height: 16),
                  _buildReadOnlyDateTimeField(
                    label: 'Delivery Date & Time',
                    value: '${widget.deliveryDate} ${widget.deliveryTime}',
                    icon: Icons.schedule,
                  ),
                  const SizedBox(height: 16),
                  _buildEnhancedTextField(
                    controller: commentsController,
                    label: 'Comments (Optional)',
                    hint: 'e.g., Can carry your item securely',
                    icon: Icons.comment_outlined,
                    isRequired: false,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom action buttons
          Container(
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSubmitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: Colors.grey.shade400,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: isSubmitting ? null : _submitRequest,
                      icon: isSubmitting
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Icon(Icons.send_rounded, size: 20),
                      label: Text(
                        isSubmitting ? 'Sending...' : 'Send Request',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}