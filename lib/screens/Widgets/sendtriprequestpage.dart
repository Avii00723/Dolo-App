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
  final pnrController = TextEditingController(); 
  bool isSubmitting = false;

  @override
  void dispose() {
    vehicleInfoController.dispose();
    commentsController.dispose();
    pnrController.dispose();
    super.dispose();
  }

  // Get Vehicle Info label based on transport mode
  String _getVehicleInfoLabel(String transportMode) {
    final mode = transportMode.toLowerCase();
    if (mode == 'car') return 'Car Model/Info';
    if (mode == 'bike' || mode == 'motorcycle' || mode == 'scooter') return 'Bike Model/Info';
    if (mode == 'train' || mode == 'metro') return 'Train Name/No.';
    if (mode == 'plane' || mode == 'flight') return 'Airlines/Flight No.';
    if (mode == 'bus') return 'Bus Operator/Info';
    if (mode == 'auto' || mode == 'rickshaw') return 'Auto Info';
    if (mode == 'truck') return 'Truck Info';
    if (mode == 'van') return 'Van Info';
    return 'Vehicle Info';
  }

  // Get Vehicle Info hint based on transport mode
  String _getVehicleInfoHint(String transportMode) {
    final mode = transportMode.toLowerCase();
    if (mode == 'car') return 'e.g. Toyota Camry, White';
    if (mode == 'bike' || mode == 'motorcycle' || mode == 'scooter') return 'e.g. Honda Activa / RE';
    if (mode == 'train' || mode == 'metro') return 'e.g. Rajdhani Express';
    if (mode == 'plane' || mode == 'flight') return 'e.g. Flight Indigo 6E-2134';
    if (mode == 'bus') return 'e.g. Intercity / Volvo Bus';
    if (mode == 'auto' || mode == 'rickshaw') return 'e.g. Local Auto-rickshaw';
    if (mode == 'truck') return 'e.g. Tata Truck / Container';
    if (mode == 'van') return 'e.g. Maruti Omni / Cargo Van';
    return 'Enter vehicle details';
  }

  // Get PNR/Number label based on transport mode
  String _getPnrLabel(String transportMode) {
    final mode = transportMode.toLowerCase();
    if (mode == 'car') return 'Car Number';
    if (mode == 'bike' || mode == 'motorcycle' || mode == 'scooter') return 'Bike Number';
    if (mode == 'train' || mode == 'plane' || mode == 'flight') return 'PNR Number';
    if (mode == 'bus') return 'Ticket Number';
    if (mode == 'auto' || mode == 'rickshaw') return 'Registration Number';
    if (mode == 'truck' || mode == 'van') return 'Vehicle Number';
    return 'PNR / Ticket Number';
  }

  // Get placeholder text based on transport mode
  String _getPnrPlaceholder(String transportMode) {
    final mode = transportMode.toLowerCase();
    if (mode == 'train') return 'Enter 10-digit PNR';
    if (mode == 'plane' || mode == 'flight') return 'Booking Ref / PNR';
    if (mode == 'bus') return 'Ticket / Seat Number';
    if (mode == 'car') return 'e.g. MH 12 AB 1234';
    if (mode == 'bike' || mode == 'motorcycle' || mode == 'scooter') return 'e.g. DL 1S AB 1234';
    if (mode == 'auto' || mode == 'rickshaw') return 'e.g. UP 16 AB 9999';
    return 'Enter identification number';
  }

  // Validate PNR format
  bool _validatePnrFormat(String transportMode, String pnr) {
    if (pnr.isEmpty) return true;
    final cleanPnr = pnr.trim();
    final mode = transportMode.toLowerCase();
    if (mode == 'train') return RegExp(r'^\d{10}$').hasMatch(cleanPnr);
    if (mode == 'plane' || mode == 'flight') return cleanPnr.length >= 5 && cleanPnr.length <= 15;
    if (mode == 'bus') return cleanPnr.length >= 3 && cleanPnr.length <= 20;
    if (mode == 'car' || mode == 'bike' || mode == 'motorcycle' || mode == 'scooter' || mode == 'auto' || mode == 'rickshaw' || mode == 'truck' || mode == 'van') {
      return cleanPnr.length >= 4 && cleanPnr.length <= 15;
    }
    return cleanPnr.length >= 3 && cleanPnr.length <= 25;
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
    final mode = widget.order.transportMode;
    if (vehicleInfoController.text.trim().isEmpty) {
      _showSnackBar('Please enter ${_getVehicleInfoLabel(mode)}', Colors.red);
      return;
    }

    final pnr = pnrController.text.trim();
    if (pnr.isNotEmpty && !_validatePnrFormat(mode, pnr)) {
      String formatHint;
      if (mode.toLowerCase() == 'train') {
        formatHint = 'Train PNR must be 10 digits';
      } else {
        formatHint = 'Invalid ${_getPnrLabel(mode)} format';
      }
      _showSnackBar(formatHint, Colors.red);
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      // Logic modified to match API documentation provided
      
      // Ensure time format is HH:mm:ss for ISO strings
      String ensureSeconds(String time) {
        if (time.isEmpty) return "00:00:00";
        List<String> parts = time.split(':');
        if (parts.length == 1) return "${parts[0].padLeft(2, '0')}:00:00";
        if (parts.length == 2) return "${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}:00";
        return time;
      }

      // API example shows travel_date and departure_datetime are typically same for trip request
      final formattedTime = ensureSeconds(widget.departureTime);
      final departureIsoString = '${widget.departureDate}T${formattedTime}Z';

      final tripRequest = TripRequestSendRequest(
        travelerId: widget.currentUserId,
        orderId: widget.order.id,
        travelDate: departureIsoString, // Using departure time as travel_date per API example
        vehicleInfo: vehicleInfoController.text.trim(),
        vehicleType: mode.toLowerCase(), // API expects lowercase type (e.g., "train")
        pnr: pnr.isNotEmpty ? pnr : "N/A", // Use "N/A" or value to avoid missing field issues if required
        source: widget.order.origin,
        destination: widget.order.destination,
        departureDatetime: departureIsoString,
        comments: commentsController.text.trim().isNotEmpty
            ? commentsController.text.trim()
            : "No specific comments", // Ensuring comments is sent per API example
      );

      final response = await widget.tripRequestService.sendTripRequest(tripRequest);

      if (mounted) {
        setState(() {
          isSubmitting = false;
        });

        if (response != null) {
          Navigator.pop(context);
          widget.onSuccess(response.tripRequestId, widget.order.userName);
        } else {
          _showSnackBar('Failed to send request. Please check required fields.', Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
        _showSnackBar('An error occurred: $e', Colors.red);
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
    final transportMode = widget.order.transportMode;

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
              label: 'Selected Mode',
              value: transportMode,
              icon: Icons.directions_bus_outlined,
            ),
            const SizedBox(height: 16),
            _buildEnhancedTextField(
              controller: vehicleInfoController,
              label: _getVehicleInfoLabel(transportMode),
              hint: _getVehicleInfoHint(transportMode),
              icon: Icons.info_outline,
              isRequired: true,
            ),
            const SizedBox(height: 16),
            _buildEnhancedTextField(
              controller: pnrController,
              label: _getPnrLabel(transportMode),
              hint: _getPnrPlaceholder(transportMode),
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
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
          ],
        ),
      ),
    );
  }
}