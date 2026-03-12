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
    super.key,
    required this.order,
    required this.currentUserId,
    required this.tripRequestService,
    required this.onSuccess,
    required this.departureDate,
    required this.departureTime,
    required this.deliveryDate,
    required this.deliveryTime,
  });

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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
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

      debugPrint('DEBUG: Sending trip request...');
      debugPrint('DEBUG: Traveler ID: ${widget.currentUserId}');
      debugPrint('DEBUG: Order ID: ${widget.order.id}');
      debugPrint('DEBUG: Travel Date (delivery): $deliveryDatetime');
      debugPrint('DEBUG: Departure Datetime: $departureDatetime');
      debugPrint('DEBUG: Vehicle Type: ${widget.order.transportMode}');
      debugPrint('DEBUG: PNR: $pnr');

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
        debugPrint('ERROR: Failed to send trip request: $e');
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
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
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35), fontSize: 13),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              debugPrint('🔔 SendPage: Notification handled callback');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildReadOnlyField(
              label: 'Traveling From',
              value: widget.order.origin,
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 16),
            _buildReadOnlyField(
              label: 'Traveling To',
              value: widget.order.destination,
              icon: Icons.place_outlined,
            ),
            const SizedBox(height: 16),
            _buildReadOnlyField(
              label: 'Vehicle Info',
              value: widget.order.transportMode,
              icon: Icons.directions_bus_outlined,
            ),
            const SizedBox(height: 16),
            _buildEnhancedTextField(
              controller: vehicleInfoController,
              label: 'Enter Vehicle Info',
              hint: 'e.g., Bus, Train, Plane',
              icon: Icons.info_outline,
              isRequired: true,
            ),
            const SizedBox(height: 16),
            _buildEnhancedTextField(
              controller: pnrController,
              label: 'Enter PNR',
              hint: _getPnrPlaceholder(widget.order.transportMode),
              icon: Icons.confirmation_number_outlined,
            ),
            const SizedBox(height: 16),
            _buildEnhancedTextField(
              controller: commentsController,
              label: 'Enter Comments',
              hint: 'Enter your comments',
              icon: Icons.comment_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Send Request',
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