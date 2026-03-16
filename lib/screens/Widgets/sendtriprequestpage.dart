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

  // Get Vehicle Info label based on transport mode
  String _getVehicleInfoLabel(String transportMode) {
    switch (transportMode.toLowerCase()) {
      case 'car': return 'Car Model/Info';
      case 'train': return 'Train Name/No.';
      case 'plane':
      case 'flight': return 'Airlines/Flight No.';
      case 'bus': return 'Bus Operator/Info';
      case 'bike':
      case 'motorcycle': return 'Bike Model/Info';
      default: return 'Vehicle Info';
    }
  }

  // Get Vehicle Info hint based on transport mode
  String _getVehicleInfoHint(String transportMode) {
    switch (transportMode.toLowerCase()) {
      case 'car': return 'e.g. Toyota Camry, White';
      case 'train': return 'e.g. Rajdhani Express (12301)';
      case 'plane':
      case 'flight': return 'e.g. Indigo (6E-2134)';
      case 'bus': return 'e.g. RedBus / Intercity Operator';
      case 'bike':
      case 'motorcycle': return 'e.g. Honda Activa / Royal Enfield';
      default: return 'Enter vehicle details';
    }
  }

  // Get PNR/Number label based on transport mode
  String _getPnrLabel(String transportMode) {
    switch (transportMode.toLowerCase()) {
      case 'car': return 'Vehicle Number';
      case 'bike':
      case 'motorcycle': return 'Bike Number';
      case 'train':
      case 'plane':
      case 'flight':
      case 'bus': return 'PNR / Ticket Number';
      default: return 'ID / Registration Number';
    }
  }

  // Get placeholder text based on transport mode
  String _getPnrPlaceholder(String transportMode) {
    switch (transportMode.toLowerCase()) {
      case 'train':
        return 'Enter 10-digit PNR';
      case 'flight':
      case 'plane':
        return 'Booking Ref / PNR';
      case 'bus':
        return 'Ticket / Seat Number';
      case 'car':
        return 'e.g. MH 12 AB 1234';
      case 'bike':
      case 'motorcycle':
        return 'e.g. DL 1S AB 1234';
      default:
        return 'Enter identification number';
    }
  }

  // Validate PNR format
  bool _validatePnrFormat(String transportMode, String pnr) {
    if (pnr.isEmpty) return true; // Optional

    final cleanPnr = pnr.trim();
    switch (transportMode.toLowerCase()) {
      case 'train':
        return RegExp(r'^\d{10}$').hasMatch(cleanPnr);
      case 'flight':
      case 'plane':
        return cleanPnr.length >= 5 && cleanPnr.length <= 15;
      case 'bus':
        return cleanPnr.length >= 3 && cleanPnr.length <= 20;
      case 'car':
      case 'bike':
      case 'motorcycle':
        return cleanPnr.length >= 4 && cleanPnr.length <= 15;
      default:
        return cleanPnr.length >= 3 && cleanPnr.length <= 25;
    }
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
    // Validate required fields
    if (vehicleInfoController.text.trim().isEmpty) {
      _showSnackBar('Please enter ${_getVehicleInfoLabel(mode)}', Colors.red);
      return;
    }

    // Validate PNR format if provided
    final pnr = pnrController.text.trim();
    if (pnr.isNotEmpty && !_validatePnrFormat(mode, pnr)) {
      String formatHint;
      switch (mode.toLowerCase()) {
        case 'train':
          formatHint = 'Train PNR must be 10 digits';
          break;
        case 'car':
        case 'bike':
          formatHint = 'Invalid vehicle number format';
          break;
        default:
          formatHint = 'Invalid ${_getPnrLabel(mode)} format';
      }
      _showSnackBar(formatHint, Colors.red);
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final departureDatetime = '${widget.departureDate}T${widget.departureTime}Z';
      final deliveryDatetime = '${widget.deliveryDate}T${widget.deliveryTime}Z';

      final tripRequest = TripRequestSendRequest(
        travelerId: widget.currentUserId,
        orderId: widget.order.id,
        travelDate: deliveryDatetime,
        vehicleInfo: vehicleInfoController.text.trim(),
        vehicleType: mode,
        pnr: pnr.isNotEmpty ? pnr : null,
        source: widget.order.origin,
        destination: widget.order.destination,
        departureDatetime: departureDatetime,
        comments: commentsController.text.trim().isNotEmpty
            ? commentsController.text.trim()
            : null,
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
          _showSnackBar('Failed to send request. Please try again.', Colors.red);
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