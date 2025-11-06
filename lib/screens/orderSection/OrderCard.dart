// Modern Sender Order Card - COMPACT VERSION with Click to Expand, Edit and Delete

import 'package:dolo/Constants/ApiConstants.dart';
import 'package:flutter/material.dart';
import 'YourOrders.dart';

class ModernSenderOrderCard extends StatelessWidget {
  final OrderDisplay order;
  final List<TripRequestDisplay>? tripRequests;
  final Function(TripRequestDisplay, String)? onAcceptRequest;
  final VoidCallback? onTrackOrder;
  final VoidCallback? onMarkReceived;
  final VoidCallback? onCompleteOrder;
  final Function(OrderDisplay)? onUpdateOrder;
  final Function(String)? onDeleteOrder;

  const ModernSenderOrderCard({
    Key? key,
    required this.order,
    this.tripRequests,
    this.onAcceptRequest,
    this.onTrackOrder,
    this.onMarkReceived,
    this.onCompleteOrder,
    this.onUpdateOrder,
    this.onDeleteOrder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showOrderDetailsModal(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50]?.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  // User Name with Icon
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue[600],
                          child: Text(
                            order.userName.isNotEmpty
                                ? order.userName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.userName.isNotEmpty
                                    ? order.userName
                                    : 'Unknown User',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                '#${order.id}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order.status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Compact Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route - Compact
                  Row(
                    children: [
                      Icon(Icons.radio_button_checked,
                          color: Colors.green[600], size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.origin,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 5, top: 4, bottom: 4),
                    child: Container(
                      height: 20,
                      width: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.green[400]!, Colors.red[400]!],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.red[600], size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.destination,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Quick Info Row
                  Row(
                    children: [
                      _buildCompactChip(
                          Icons.calendar_today, _formatDate(order.date)),
                      const SizedBox(width: 8),
                      _buildCompactChip(Icons.scale, order.weight),
                      const SizedBox(width: 8),
                      if (order.expectedPrice != null)
                        _buildCompactChip(
                          Icons.currency_rupee,
                          '₹${order.expectedPrice}',
                          color: Colors.green,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Trip Requests Indicator
                  if (tripRequests != null && tripRequests!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline,
                              color: Colors.orange[700], size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '${tripRequests!.length} Request${tripRequests!.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Tap to view indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Tap to view details',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios,
                          size: 10, color: Colors.grey[400]),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactChip(IconData icon, String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey[600])?.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: (color ?? Colors.grey[300])!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color ?? Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color ?? Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String date) {
    try {
      final DateTime parsedDate = DateTime.parse(date);
      return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
    } catch (e) {
      return date.split('T').first;
    }
  }

  String _formatTime(String time) {
    try {
      // Time is in HH:mm:ss format
      final parts = time.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$displayHour:$minute $period';
      }
      return time;
    } catch (e) {
      return time;
    }
  }

  String _formatDateTime(String dateTime) {
    try {
      final DateTime parsedDateTime = DateTime.parse(dateTime);
      final date =
          '${parsedDateTime.day}/${parsedDateTime.month}/${parsedDateTime.year}';
      final hour = parsedDateTime.hour > 12
          ? parsedDateTime.hour - 12
          : (parsedDateTime.hour == 0 ? 12 : parsedDateTime.hour);
      final minute = parsedDateTime.minute.toString().padLeft(2, '0');
      final period = parsedDateTime.hour >= 12 ? 'PM' : 'AM';
      return '$date at $hour:$minute $period';
    } catch (e) {
      return dateTime;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'technology':
        return Icons.devices;
      case 'fragile':
        return Icons.warning_amber_rounded;
      case 'documents':
        return Icons.description;
      case 'food':
        return Icons.restaurant;
      case 'clothing':
        return Icons.checkroom;
      default:
        return Icons.category;
    }
  }

  String _getCategoryDisplayName(String category) {
    switch (category.toLowerCase()) {
      case 'technology':
        return 'Technology';
      case 'fragile':
        return 'Fragile Items';
      case 'documents':
        return 'Documents';
      case 'food':
        return 'Food Items';
      case 'clothing':
        return 'Clothing';
      default:
        return category.toUpperCase();
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'technology':
        return Colors.blue[700]!;
      case 'fragile':
        return Colors.orange[700]!;
      case 'documents':
        return Colors.green[700]!;
      case 'food':
        return Colors.amber[700]!;
      case 'clothing':
        return Colors.purple[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  // DELETE CONFIRMATION DIALOG
  Future<void> _showDeleteConfirmation(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red[600]!, Colors.red[400]!],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_rounded,
                        color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delete Order?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'This action cannot be undone',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.red[700], size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Order #${order.id}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Deleting this order will also remove all related trip requests. Are you sure you want to continue?',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red[800],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              print('🔴 DELETE BUTTON PRESSED');
                              print('Order ID to delete: ${order.id}');
                              print(
                                  'onDeleteOrder callback is ${onDeleteOrder == null ? 'NULL' : 'NOT NULL'}');

                              Navigator.pop(
                                  context); // Close confirmation dialog
                              Navigator.pop(context); // Close details modal

                              if (onDeleteOrder != null) {
                                print('🔴 CALLING DELETE CALLBACK');
                                onDeleteOrder!(order.id);
                              } else {
                                print('❌ DELETE CALLBACK IS NULL');
                              }
                            },
                            icon: const Icon(Icons.delete_forever, size: 18),
                            label: const Text(
                              'Delete',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[600],
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ UPDATED EDIT ORDER DIALOG WITH OPTIONAL FIELDS
  Future<void> _showEditOrderDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();

    // Pre-populate with current order data
    final originController = TextEditingController(text: order.origin);
    final destinationController =
        TextEditingController(text: order.destination);
    final itemDescController =
        TextEditingController(text: order.itemDescription);
    final weightController =
        TextEditingController(text: order.weight.toString());
    final priceController =
        TextEditingController(text: order.expectedPrice?.toString() ?? '');
    final notesController = TextEditingController(text: order.notes ?? '');
    DateTime selectedDate = DateTime.parse(order.date);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[600]!, Colors.blue[400]!],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Edit Order',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Order #${order.id}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Form Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Origin - REQUIRED
                          _buildEditField(
                            controller: originController,
                            label: 'Origin *',
                            icon: Icons.radio_button_checked,
                            validator: (val) =>
                                val?.isEmpty ?? true ? 'Origin required' : null,
                          ),
                          const SizedBox(height: 16),

                          // Destination - REQUIRED
                          _buildEditField(
                            controller: destinationController,
                            label: 'Destination *',
                            icon: Icons.location_on,
                            validator: (val) => val?.isEmpty ?? true
                                ? 'Destination required'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Delivery Date
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedDate = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 18, color: Colors.grey[600]),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Delivery Date *',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatDate(selectedDate.toString()),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.edit,
                                      size: 16, color: Colors.blue[600]),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Item Description - OPTIONAL
                          _buildEditField(
                            controller: itemDescController,
                            label: 'Item Description (Optional)',
                            icon: Icons.inventory_2_outlined,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),

                          // Weight and Price Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildEditField(
                                  controller: weightController,
                                  label: 'Weight (kg) *',
                                  icon: Icons.scale,
                                  keyboardType: TextInputType.number,
                                  validator: (val) {
                                    if (val?.isEmpty ?? true) return 'Required';
                                    if (double.tryParse(val!) == null) {
                                      return 'Invalid number';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildEditField(
                                  controller: priceController,
                                  label: 'Price (₹) - Optional',
                                  icon: Icons.currency_rupee,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Notes - OPTIONAL
                          _buildEditField(
                            controller: notesController,
                            label: 'Special Instructions (Optional)',
                            icon: Icons.note_outlined,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Action Buttons
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              // Create updated order object with defaults for optional fields
                              final updatedOrder = OrderDisplay(
                                id: order.id,
                                userId: order.userId,
                                userName: order.userName,
                                senderInitial: order.senderInitial,
                                origin: originController.text.trim(),
                                destination: destinationController.text.trim(),
                                date: selectedDate.toIso8601String(),
                                itemDescription:
                                    itemDescController.text.trim().isNotEmpty
                                        ? itemDescController.text.trim()
                                        : 'Package', // Default value
                                weight: weightController.text.trim().isNotEmpty
                                    ? '${weightController.text.trim()} kg'
                                    : '0kg',
                                status: order.status,
                                expectedPrice: priceController.text.isNotEmpty
                                    ? int.tryParse(priceController.text)
                                    : null,
                                notes: notesController.text.trim().isNotEmpty
                                    ? notesController.text.trim()
                                    : null,
                                originLatitude: order.originLatitude,
                                originLongitude: order.originLongitude,
                                destinationLatitude: order.destinationLatitude,
                                destinationLongitude:
                                    order.destinationLongitude,
                                orderType: order.orderType,
                                estimatedDistance: order.estimatedDistance,
                                requestStatus: order.requestStatus,
                                imageUrl: (order.imageUrl != null &&
                                        order.imageUrl!.isNotEmpty)
                                    ? "${ApiConstants.imagebaseUrl}${order.imageUrl}"
                                    : 'https://example.com/default.jpg',
                                profileImageUrl: order.profileImageUrl,
                                matchedTravellerId: order.matchedTravellerId,
                              );

                              Navigator.pop(context);
                              print(
                                  '✅ Calling onUpdateOrder with order ID: ${updatedOrder.id}');
                              onUpdateOrder?.call(updatedOrder);
                            }
                          },
                          icon: const Icon(Icons.save, size: 18),
                          label: const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
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

  // Helper method for form fields
  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }

  // FLOATING MODAL WITH FULL DETAILS
  void _showOrderDetailsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.blue[600],
                            child: Text(
                              order.userName.isNotEmpty
                                  ? order.userName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.userName.isNotEmpty
                                      ? order.userName
                                      : 'Unknown User',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Text(
                                  'Order #${order.id}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(order.status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        order.status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date and Time
                      _buildDetailRow(
                        Icons.calendar_today,
                        'Delivery Date',
                        _formatDate(order.date),
                      ),
                      if (order.deliveryTime != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.access_time,
                          'Delivery Time',
                          _formatTime(order.deliveryTime!),
                        ),
                      ],

                      // Urgent Badge
                      if (order.isUrgent == true) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_fire_department,
                                  color: Colors.red[700], size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'URGENT DELIVERY',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Route Section
                      const Text(
                        'Route Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            _buildRoutePoint(
                              Icons.radio_button_checked,
                              'From',
                              order.origin,
                              Colors.green[600]!,
                            ),
                            if (order.estimatedDistance != null) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 12),
                                    Container(
                                      width: 2,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.green[400]!,
                                            Colors.red[400]!
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${order.estimatedDistance!.toStringAsFixed(1)} km',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            _buildRoutePoint(
                              Icons.location_on,
                              'To',
                              order.destination,
                              Colors.red[600]!,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Package Details
                      const Text(
                        'Package Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow(
                              Icons.inventory_2_outlined,
                              'Item Description',
                              order.itemDescription,
                            ),
                            if (order.category != null) ...[
                              const Divider(height: 24),
                              _buildDetailRow(
                                _getCategoryIcon(order.category!),
                                'Category',
                                _getCategoryDisplayName(order.category!),
                                valueColor: _getCategoryColor(order.category!),
                              ),
                            ],
                            const Divider(height: 24),
                            _buildDetailRow(
                              Icons.scale_outlined,
                              'Weight',
                              order.weight,
                            ),
                            if (order.preferenceTransport != null &&
                                order.preferenceTransport!.isNotEmpty) ...[
                              const Divider(height: 24),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.local_shipping_outlined,
                                          size: 18, color: Colors.grey[700]),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Preferred Transport',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: order.preferenceTransport!
                                        .map((transport) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.blue[200]!),
                                        ),
                                        child: Text(
                                          transport,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ],
                            if (order.notes != null &&
                                order.notes!.isNotEmpty) ...[
                              const Divider(height: 24),
                              _buildDetailRow(
                                Icons.note_outlined,
                                'Special Instructions',
                                order.notes!,
                              ),
                            ],
                            if (order.createdAt != null) ...[
                              const Divider(height: 24),
                              _buildDetailRow(
                                Icons.schedule,
                                'Created At',
                                _formatDateTime(order.createdAt!),
                                valueColor: Colors.grey[600],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Image if available
                      if (order.imageUrl != null &&
                          order.imageUrl!.isNotEmpty) ...[
                        const Text(
                          'Package Image',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            order.imageUrl ?? '',
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              height: 180,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image_not_supported,
                                      color: Colors.grey[400], size: 40),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Image not available',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Trip Requests Section
                      if (tripRequests != null && tripRequests!.isNotEmpty) ...[
                        Row(
                          children: [
                            const Text(
                              'Trip Requests',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[600],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${tripRequests!.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...tripRequests!.map((request) => _buildTripRequestCard(
                              context,
                              request,
                            )),
                        const SizedBox(height: 20),
                      ],

                      // Action Buttons
                      _buildModalActions(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoutePoint(
      IconData icon, String label, String location, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTripRequestCard(
      BuildContext context, TripRequestDisplay request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Traveler Info Header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue[100],
                child: Text(
                  request.travellerName.isNotEmpty
                      ? request.travellerName[0].toUpperCase()
                      : 'T',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.travellerName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Traveler ID: ${request.travellerId}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Vehicle Info & Times
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                _buildInfoRowCompact(
                    Icons.directions_car, 'Vehicle', request.vehicleInfo),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoRowCompact(
                        Icons.access_time,
                        'Pickup',
                        request.pickupTime,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoRowCompact(
                        Icons.access_time_filled,
                        'Dropoff',
                        request.dropoffTime,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Accept Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onAcceptRequest?.call(request, order.id);
              },
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text(
                'Accept Request',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowCompact(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // MODAL ACTIONS WITH EDIT AND DELETE BUTTONS FOR PENDING ORDERS
  Widget _buildModalActions(BuildContext context) {
    switch (order.status.toLowerCase()) {
      case 'pending':
        return Column(
          children: [
            // Edit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showEditOrderDialog(context);
                },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Delete Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showDeleteConfirmation(context),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete Order'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[600],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.red[300]!),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule, color: Colors.orange[600], size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Waiting for Trip Requests',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case 'accepted':
      case 'matched':
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onTrackOrder?.call();
                },
                icon: const Icon(Icons.my_location, size: 18),
                label: const Text('Track Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onCompleteOrder?.call();
                },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Mark as Delivered'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        );

      case 'in-transit':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onTrackOrder?.call();
            },
            icon: const Icon(Icons.my_location, size: 18),
            label: const Text('Track Order'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );

      case 'arrived':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onMarkReceived?.call();
            },
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Mark as Received'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );

      case 'delivered':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 20),
              const SizedBox(width: 12),
              Text(
                'Delivered Successfully',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange[600]!;
      case 'accepted':
      case 'matched':
        return Colors.blue[600]!;
      case 'in-transit':
        return Colors.purple[600]!;
      case 'arrived':
        return Colors.deepPurple[600]!;
      case 'delivered':
        return Colors.green[600]!;
      case 'booked':
        return Colors.yellow[600]!;
      default:
        return Colors.grey[600]!;
    }
  }
}
