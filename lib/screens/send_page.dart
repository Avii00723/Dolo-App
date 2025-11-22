import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart';
import '../Constants/colorconstant.dart';
import '../../Models/OrderModel.dart';
import '../../Models/TripRequestModel.dart';
import '../Controllers/OrderService.dart';
import '../Controllers/TripRequestService.dart';
import '../Controllers/AuthService.dart';
import 'LocationinputField.dart';
import 'CustomRoutePreviewScreen.dart';
import 'orderSection/SearchResultPage.dart';
import 'orderSection/YourOrders.dart';
import '../widgets/NotificationBellIcon.dart';

class SendPage extends StatefulWidget {
  const SendPage({Key? key}) : super(key: key);

  @override
  _SendPageState createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController dateController = TextEditingController();

  String? selectedVehicle;
  final List<String> vehicleOptions = [
    'Car',
    'Bike',
    'Pickup Truck',
    'Truck',
    'Bus',
    'Train',
    'Plane',
  ];

  bool isLoading = false;
  bool isSearching = false;
  List<Order> availableOrders = [];

  final OrderService _orderService = OrderService();
  final TripRequestService _tripRequestService = TripRequestService();

  Position? originPosition;
  Position? destinationPosition;
  String? currentUserId;

  // Store actual date and time values for API
  String? _selectedDate; // YYYY-MM-DD format
  String? _selectedTime; // HH:mm:ss format

  // Stopover management
  List<Map<String, dynamic>> stopovers = [];

  @override
  void initState() {
    super.initState();
    print('📄 SendPage: initState() called');
    _initializeUser();
  }

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    dateController.dispose();
    super.dispose();
  }

  String _formatDateForDisplay(String isoDate) {
    try {
      DateTime dateTime = DateTime.parse(isoDate);
      return DateFormat('dd MMM yyyy').format(dateTime);
    } catch (e) {
      return isoDate;
    }
  }

  Future<void> _initializeUser() async {
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) {
        print('❌ No user ID found in AuthService');
        if (mounted) {
          _showSnackBar('Please log in to continue', Colors.red);
        }
        return;
      }

      setState(() {
        currentUserId = userId;
      });
      print('✅ User ID loaded from AuthService: $userId');
    } catch (e) {
      print('❌ Error initializing user: $e');
      if (mounted) {
        _showSnackBar('Error loading user data: $e', Colors.red);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // ✨ NEW METHOD: Show Route Preview
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _showRouteMap() async {
    if (originPosition == null || destinationPosition == null) {
      _showSnackBar('Please select both origin and destination', Colors.orange);
      return;
    }

    if (selectedVehicle == null) {
      _showSnackBar('Please select a vehicle type', Colors.orange);
      return;
    }

    // Show custom route preview with Google Maps and app theme colors
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomRoutePreviewScreen(
          origin: fromController.text,
          destination: toController.text,
          originLat: originPosition!.latitude,
          originLng: originPosition!.longitude,
          destLat: destinationPosition!.latitude,
          destLng: destinationPosition!.longitude,
          stopovers: stopovers,
          vehicle: selectedVehicle!,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ✨ STOPOVER MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════
  void _addStopover(String cityName, double latitude, double longitude) {
    setState(() {
      stopovers.add({
        'city': cityName,
        'latitude': latitude,
        'longitude': longitude,
      });
    });
    _showSnackBar('Stopover added: $cityName', Colors.green);
  }

  void _removeStopover(int index) {
    setState(() {
      stopovers.removeAt(index);
    });
    _showSnackBar('Stopover removed', Colors.orange);
  }

  Future<void> _showAddStopoverDialog() async {
    final stopoverController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddStopoverBottomSheet(
        controller: stopoverController,
        onAdd: (cityName, latitude, longitude) {
          _addStopover(cityName, latitude, longitude);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _selectDateTime(BuildContext context) async {
    // First, pick the date
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      // Then, pick the time
      if (context.mounted) {
        TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );

        if (pickedTime != null) {
          // Combine date and time
          final combinedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );

          // Store date and time separately for API
          final dateStr = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
          final hour = pickedTime.hour.toString().padLeft(2, '0');
          final minute = pickedTime.minute.toString().padLeft(2, '0');
          final timeStr = '$hour:$minute:00';

          setState(() {
            _selectedDate = dateStr;
            _selectedTime = timeStr;

            // Display formatted datetime in the text field (for user visibility)
            dateController.text = DateFormat('dd MMM yyyy, hh:mm a').format(combinedDateTime);
          });

          print('📅 Selected DateTime Display: ${dateController.text}');
          print('📅 Date for API: $_selectedDate');
          print('⏰ Time for API: $_selectedTime');
        }
      }
    }
  }

  Future<void> _searchAvailableOrders() async {
    if (currentUserId == null) {
      _showSnackBar('Please log in to search orders', Colors.red);
      return;
    }

    if (fromController.text.trim().isEmpty ||
        toController.text.trim().isEmpty ||
        _selectedDate == null ||
        _selectedTime == null ||
        selectedVehicle == null) {
      _showSnackBar('Please fill all required fields', Colors.red);
      return;
    }

    if (originPosition == null) {
      _showSnackBar(
          'Please select origin location from suggestions', Colors.orange);
      return;
    }

    setState(() {
      isSearching = true;
    });

    try {
      print('DEBUG: Starting search...');
      print('DEBUG: User ID: $currentUserId');
      print('DEBUG: From: "${fromController.text.trim()}"');
      print('DEBUG: To: "${toController.text.trim()}"');
      print('DEBUG: Date: "$_selectedDate"');
      print('DEBUG: Time: "$_selectedTime"');
      print('DEBUG: Origin Lat: ${originPosition!.latitude}');
      print('DEBUG: Origin Lng: ${originPosition!.longitude}');
      print('DEBUG: Vehicle: $selectedVehicle');

      // Format stopovers as comma-separated city names
      String? stopoversParam;
      if (stopovers.isNotEmpty) {
        stopoversParam = stopovers.map((s) => s['city'] as String).join(',');
        print('DEBUG: Stopovers: $stopoversParam');
      }

      final orders = await _orderService.searchOrders(
        origin: fromController.text.trim(),
        destination: toController.text.trim(),
        deliveryDate: _selectedDate!,
        deliveryTime: _selectedTime!,
        originLatitude: originPosition!.latitude,
        originLongitude: originPosition!.longitude,
        vehicle: selectedVehicle!,
        userId: currentUserId!,
        stopovers: stopoversParam,
      );

      print('DEBUG: API returned ${orders.length} orders');

      setState(() {
        isSearching = false;
      });

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchResultsPage(
              orders: orders,
              fromLocation: fromController.text.trim(),
              toLocation: toController.text.trim(),
              date: dateController.text.trim(),
              searchedVehicle: selectedVehicle!, // Pass the searched vehicle
              onSendRequest: (order) => _sendRequestToSender(order),
            ),
          ),
        );
      }

      if (orders.isEmpty) {
        _showSnackBar(
          'No orders found for this route on ${dateController.text.trim()}',
          Colors.orange,
        );
      }
    } catch (e) {
      print('DEBUG: Search error: $e');
      setState(() {
        isSearching = false;
      });
      _showSnackBar('Error searching orders: $e', Colors.red);
    }
  }

  Future<void> _sendRequestToSender(Order order) async {
    try {
      await _showTripRequestDialog(order);
    } catch (e) {
      _showSnackBar('Failed to send request: $e', Colors.red);
    }
  }

  Future<void> _showTripRequestDialog(Order order) async {
    if (currentUserId == null) {
      _showSnackBar('Please log in to send requests', Colors.red);
      return;
    }

    // Validate that the order has an ID
    if (order.id.isEmpty) {
      _showSnackBar(
          'Invalid order: Missing order ID. Please refresh and try again.',
          Colors.red);
      print('❌ ERROR: Order ID is empty');
      print(
          'DEBUG: Order details - Origin: ${order.origin}, Destination: ${order.destination}');
      return;
    }

    // Navigate to full page instead of showing dialog
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SendTripRequestPage(
          order: order,
          currentUserId: currentUserId!,
          tripRequestService: _tripRequestService,
          onSuccess: (tripRequestId, orderOwner) {
            _showSuccessDialog(
              tripRequestId: tripRequestId,
              orderOwner: orderOwner,
            );
          },
        ),
      ),
    );
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

  void _showSuccessDialog({
    required String tripRequestId,
    required String orderOwner,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 60,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Request Sent Successfully!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    'Trip Request ID',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#$tripRequestId',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Your request has been sent to $orderOwner. You will be notified when they respond.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const YourOrdersPage(),
                  ),
                ).then((_) {
                  fromController.clear();
                  toController.clear();
                  dateController.clear();
                  setState(() {
                    selectedVehicle = null;
                    originPosition = null;
                    destinationPosition = null;
                    _selectedDate = null;
                    _selectedTime = null;
                  });
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'View Your Orders',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      'assets/images/doloooo.png',
                      height: 40,
                    ),
                    NotificationBellIcon(
                      onNotificationHandled: () {
                        // Refresh the inbox and requests after handling a notification

                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Search Available Orders',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    EnhancedLocationInputField(
                      controller: fromController,
                      label: 'From',
                      hint: 'Tap to search location',
                      icon: Icons.my_location,
                      isOrigin: true,
                      onLocationSelected: (position) {
                        setState(() {
                          originPosition = position;
                        });
                      },
                    ),

                    // ═══════════════════════════════════════════════════════════
                    // ✨ ADD STOPOVER BUTTON
                    // ═══════════════════════════════════════════════════════════
                    const SizedBox(height: 10),
                    Center(
                      child: GestureDetector(
                        onTap: _showAddStopoverDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Add Stopover',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ═══════════════════════════════════════════════════════════
                    // ✨ DISPLAY STOPOVERS LIST
                    // ═══════════════════════════════════════════════════════════
                    if (stopovers.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...stopovers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final stopover = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.orange,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Stopover ${index + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      stopover['city'],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                color: Colors.red,
                                onPressed: () => _removeStopover(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],

                    const SizedBox(height: 15),
                    EnhancedLocationInputField(
                      controller: toController,
                      label: 'To',
                      hint: 'Tap to search location',
                      icon: Icons.location_on,
                      isOrigin: false,
                      onLocationSelected: (position) {
                        setState(() {
                          destinationPosition = position;
                        });
                      },
                    ),

                    // ═══════════════════════════════════════════════════════════════
                    // ✨ NEW: View Route Button (Shows when both locations selected)
                    // ═══════════════════════════════════════════════════════════════
                    if (originPosition != null &&
                        destinationPosition != null) ...[
                      const SizedBox(height: 15),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[400]!, Colors.blue[600]!],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _showRouteMap,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.map,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  const Flexible(
                                    child: Text(
                                      'View Route on Map',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'NEW',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 15),
                    GestureDetector(
                      onTap: () => _selectDateTime(context),
                      child: AbsorbPointer(
                        child: buildInputBox(
                          'Delivery Date & Time',
                          dateController,
                          Icons.calendar_today,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildVehicleDropdown(),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSearching ? null : _searchAvailableOrders,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Search Orders',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (availableOrders.isNotEmpty)
                _buildAvailableOrdersList()
              else if (isSearching)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                )
              else
                _buildEmptyState(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!, width: 2),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: selectedVehicle,
        hint: Row(
          children: [
            Icon(Icons.directions_car, color: Colors.grey[400], size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Select Transportation Mode',
                style: TextStyle(color: Colors.grey, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 17),
        ),
        icon: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
        ),
        isExpanded: true,
        menuMaxHeight: 400,
        selectedItemBuilder: (BuildContext context) {
          return vehicleOptions.map<Widget>((vehicle) {
            IconData icon;
            switch (vehicle) {
              case 'Car':
                icon = Icons.directions_car;
                break;
              case 'Bike':
                icon = Icons.two_wheeler;
                break;
              case 'Pickup Truck':
                icon = Icons.local_shipping;
                break;
              case 'Truck':
                icon = Icons.local_shipping;
                break;
              case 'Bus':
                icon = Icons.directions_bus;
                break;
              case 'Train':
                icon = Icons.train;
                break;
              case 'Plane':
                icon = Icons.flight;
                break;
              default:
                icon = Icons.directions;
                break;
            }

            return Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    vehicle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          }).toList();
        },
        items: vehicleOptions.map((String vehicle) {
          IconData icon;
          switch (vehicle) {
            case 'Car':
              icon = Icons.directions_car;
              break;
            case 'Bike':
              icon = Icons.two_wheeler;
              break;
            case 'Pickup Truck':
              icon = Icons.local_shipping;
              break;
            case 'Truck':
              icon = Icons.local_shipping;
              break;
            case 'Bus':
              icon = Icons.directions_bus;
              break;
            case 'Train':
              icon = Icons.train;
              break;
            case 'Plane':
              icon = Icons.flight;
              break;
            default:
              icon = Icons.directions;
              break;
          }

          return DropdownMenuItem<String>(
            value: vehicle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      vehicle,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            selectedVehicle = newValue;
          });
        },
      ),
    );
  }

  Widget _buildAvailableOrdersList() {
    return Column(
      children: availableOrders.map((order) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Available',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${order.origin} → ${order.destination}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDateForDisplay(order.deliveryDate),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (order.calculatedPrice != null)
                    Text(
                      '₹${order.calculatedPrice!.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _sendRequestToSender(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Send Request',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          Text(
            'No Orders Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start searching to find available orders',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget buildInputBox(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!, width: 2),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              icon,
              color: Colors.grey[400],
              size: 22,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 17,
          ),
        ),
      ),
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
}

// ═══════════════════════════════════════════════════════════════════
// ✨ ADD STOPOVER BOTTOM SHEET WIDGET
// ═══════════════════════════════════════════════════════════════════
class _AddStopoverBottomSheet extends StatefulWidget {
  final TextEditingController controller;
  final Function(String cityName, double latitude, double longitude) onAdd;

  const _AddStopoverBottomSheet({
    Key? key,
    required this.controller,
    required this.onAdd,
  }) : super(key: key);

  @override
  State<_AddStopoverBottomSheet> createState() =>
      _AddStopoverBottomSheetState();
}

class _AddStopoverBottomSheetState extends State<_AddStopoverBottomSheet> {
  final FocusNode _searchFocusNode = FocusNode();
  Position? selectedPosition;
  String? selectedCityName;

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field when the sheet opens
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_location_alt,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Add Stopover',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Search for stopover location',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                // Google Places Autocomplete
                GooglePlacesAutoCompleteTextFormField(
                  textEditingController: widget.controller,
                  focusNode: _searchFocusNode,
                  config: const GoogleApiConfig(
                    apiKey: 'AIzaSyBin4hsTqp0DSLCzjmQwuB78hBHZRhG_3Y',
                    countries: ['in'],
                    fetchPlaceDetailsWithCoordinates: true,
                    debounceTime: 400,
                  ),
                  onPredictionWithCoordinatesReceived: (prediction) {
                    if (prediction.lat != null && prediction.lng != null) {
                      setState(() {
                        selectedPosition = Position(
                          latitude: double.parse(prediction.lat.toString()),
                          longitude: double.parse(prediction.lng.toString()),
                          timestamp: DateTime.now(),
                          accuracy: 0.0,
                          altitude: 0.0,
                          altitudeAccuracy: 0.0,
                          heading: 0.0,
                          headingAccuracy: 0.0,
                          speed: 0.0,
                          speedAccuracy: 0.0,
                        );
                        selectedCityName = prediction.description ?? '';
                      });
                    }
                  },
                  onSuggestionClicked: (prediction) {
                    final description = prediction.description ?? '';
                    widget.controller.text = description;
                    widget.controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: description.length),
                    );
                  },
                  decoration: InputDecoration(
                    hintText: 'Search for a stopover city...',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    suffixIcon: widget.controller.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[600]),
                            onPressed: () {
                              setState(() {
                                widget.controller.clear();
                                selectedPosition = null;
                                selectedCityName = null;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey[300]!, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey[300]!, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: AppColors.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),

                // Show selected location info
                if (selectedPosition != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.green[700], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Location selected',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Lat: ${selectedPosition!.latitude.toStringAsFixed(6)}, Lng: ${selectedPosition!.longitude.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Add button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: selectedPosition != null
                        ? () {
                            widget.onAdd(
                              selectedCityName ?? widget.controller.text,
                              selectedPosition!.latitude,
                              selectedPosition!.longitude,
                            );
                          }
                        : null,
                    icon: const Icon(Icons.add_location_alt, size: 20),
                    label: const Text(
                      'Add Stopover',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: selectedPosition != null ? 2 : 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ✨ SEND TRIP REQUEST FULL PAGE
// ═══════════════════════════════════════════════════════════════════
class SendTripRequestPage extends StatefulWidget {
  final Order order;
  final String currentUserId;
  final TripRequestService tripRequestService;
  final Function(String tripRequestId, String orderOwner) onSuccess;

  const SendTripRequestPage({
    Key? key,
    required this.order,
    required this.currentUserId,
    required this.tripRequestService,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<SendTripRequestPage> createState() => _SendTripRequestPageState();
}

class _SendTripRequestPageState extends State<SendTripRequestPage> {
  final vehicleInfoController = TextEditingController();
  final startTimeController = TextEditingController();
  final endTimeController = TextEditingController();
  final commentsController = TextEditingController();
  bool isSubmitting = false;

  @override
  void dispose() {
    vehicleInfoController.dispose();
    startTimeController.dispose();
    endTimeController.dispose();
    commentsController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(TextEditingController controller) async {
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null) {
      final formattedTime =
          '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}:00';
      controller.text = formattedTime;
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
    if (vehicleInfoController.text.trim().isEmpty ||
        startTimeController.text.trim().isEmpty ||
        endTimeController.text.trim().isEmpty) {
      _showSnackBar('Please fill all required fields', Colors.red);
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      String formattedDate = widget.order.deliveryDate;
      if (widget.order.deliveryDate.contains('T')) {
        formattedDate = widget.order.deliveryDate.split('T')[0];
      }

      final tripRequest = TripRequestSendRequest(
        travelerId: widget.currentUserId,
        orderId: widget.order.id,
        travelDate: formattedDate,
        vehicleInfo: vehicleInfoController.text.trim(),
        source: widget.order.origin,
        destination: widget.order.destination,
        pickupTime: startTimeController.text.trim(),
        dropoffTime: endTimeController.text.trim(),
        comments: commentsController.text.trim().isNotEmpty
            ? commentsController.text.trim()
            : null,
      );

      print('DEBUG: Sending trip request...');
      print('DEBUG: Traveler ID: ${widget.currentUserId}');
      print('DEBUG: Order ID: ${widget.order.id}');

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
                    hint: 'e.g., Honda City, MH01AB1234',
                    icon: Icons.directions_car,
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _selectTime(startTimeController),
                    child: AbsorbPointer(
                      child: _buildEnhancedTextField(
                        controller: startTimeController,
                        label: 'Start Time',
                        hint: 'Tap to select time',
                        icon: Icons.access_time,
                        isRequired: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _selectTime(endTimeController),
                    child: AbsorbPointer(
                      child: _buildEnhancedTextField(
                        controller: endTimeController,
                        label: 'Arrival Time',
                        hint: 'Tap to select time',
                        icon: Icons.access_time_filled,
                        isRequired: true,
                      ),
                    ),
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
