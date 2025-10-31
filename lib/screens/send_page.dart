import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../Constants/colorconstant.dart';
import '../../Models/OrderModel.dart';
import '../../Models/TripRequestModel.dart';
import '../Controllers/OrderService.dart';
import '../Controllers/TripRequestService.dart';
import '../Controllers/AuthService.dart';
import 'LocationinputField.dart';
import 'CustomRouteMapScreen.dart';
import 'orderSection/SearchResultPage.dart';
import 'orderSection/YourOrders.dart';

class SendPage extends StatefulWidget {
  const SendPage({Key? key}) : super(key: key);

  @override
  _SendPageState createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController hoursController = TextEditingController();

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

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    dateController.dispose();
    hoursController.dispose();
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
  // ✨ NEW METHOD: Show Route Map
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _showRouteMap() async {
    if (originPosition == null || destinationPosition == null) {
      _showSnackBar('Please select both origin and destination', Colors.orange);
      return;
    }

    final selectedRoute = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomRouteMapScreen(
          originCity: fromController.text,
          destinationCity: toController.text,
          originLatitude: originPosition!.latitude,
          originLongitude: originPosition!.longitude,
          destinationLatitude: destinationPosition!.latitude,
          destinationLongitude: destinationPosition!.longitude,
        ),
      ),
    );

    // If user selected a route, show confirmation
    if (selectedRoute != null) {
      _showSnackBar('Route selected: ${selectedRoute.distance}, ${selectedRoute.duration}', Colors.green);
      print('✅ User selected route: ${selectedRoute.distance}, ${selectedRoute.duration}');
      print('   Route summary: ${selectedRoute.summary}');
      print('   Cities along route (${selectedRoute.cities.length}):');
      for (var city in selectedRoute.cities) {
        print('     - ${city.name} (${city.category} - ${city.type})');
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        dateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _searchAvailableOrders() async {
    if (currentUserId == null) {
      _showSnackBar('Please log in to search orders', Colors.red);
      return;
    }

    if (fromController.text.trim().isEmpty ||
        toController.text.trim().isEmpty ||
        dateController.text.trim().isEmpty ||
        selectedVehicle == null ||
        hoursController.text.trim().isEmpty) {
      _showSnackBar('Please fill all required fields', Colors.red);
      return;
    }

    if (originPosition == null) {
      _showSnackBar('Please select origin location from suggestions', Colors.orange);
      return;
    }

    final hours = double.tryParse(hoursController.text.trim());
    if (hours == null || hours <= 0) {
      _showSnackBar('Please enter valid hours', Colors.red);
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
      print('DEBUG: Date: "${dateController.text.trim()}"');
      print('DEBUG: Origin Lat: ${originPosition!.latitude}');
      print('DEBUG: Origin Lng: ${originPosition!.longitude}');
      print('DEBUG: Vehicle: $selectedVehicle');
      print('DEBUG: Hours: $hours');

      final orders = await _orderService.searchOrders(
        origin: fromController.text.trim(),
        destination: toController.text.trim(),
        deliveryDate: dateController.text.trim(),
        originLatitude: originPosition!.latitude,
        originLongitude: originPosition!.longitude,
        vehicle: selectedVehicle!,
        timeHours: hours,
        userId: currentUserId!,
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

    final vehicleInfoController = TextEditingController();
    final startTimeController = TextEditingController();
    final endTimeController = TextEditingController();

    Future<void> selectTime(BuildContext context, TextEditingController controller) async {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        final formattedTime = '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}:00';
        controller.text = formattedTime;
      }
    }

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
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
                      child: const Icon(Icons.send, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Send Trip Request',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReadOnlyField(
                        label: 'From',
                        value: order.origin,
                        icon: Icons.trip_origin,
                      ),
                      const SizedBox(height: 15),
                      _buildReadOnlyField(
                        label: 'To',
                        value: order.destination,
                        icon: Icons.location_on,
                      ),
                      const SizedBox(height: 15),
                      _buildEnhancedTextField(
                        controller: vehicleInfoController,
                        label: 'Vehicle Information',
                        hint: 'e.g., Honda City, MH01AB1234',
                        icon: Icons.directions_car,
                        isRequired: true,
                      ),
                      const SizedBox(height: 15),
                      GestureDetector(
                        onTap: () => selectTime(dialogContext, startTimeController),
                        child: AbsorbPointer(
                          child: _buildEnhancedTextField(
                            controller: startTimeController,
                            label: 'Start Time',
                            hint: 'e.g., 09:00',
                            icon: Icons.access_time,
                            isRequired: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      GestureDetector(
                        onTap: () => selectTime(dialogContext, endTimeController),
                        child: AbsorbPointer(
                          child: _buildEnhancedTextField(
                            controller: endTimeController,
                            label: 'Arrival Time',
                            hint: 'e.g., 14:00',
                            icon: Icons.access_time_filled,
                            isRequired: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: Colors.grey.shade400,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (vehicleInfoController.text.trim().isEmpty ||
                              startTimeController.text.trim().isEmpty ||
                              endTimeController.text.trim().isEmpty) {
                            _showSnackBar('Please fill all required fields', Colors.red);
                            return;
                          }

                          Navigator.pop(dialogContext);

                          try {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (loadingContext) => PopScope(
                                canPop: false,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(30),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CircularProgressIndicator(),
                                        const SizedBox(height: 20),
                                        Text(
                                          'Sending request...',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );

                            String formattedDate = order.deliveryDate;
                            if (order.deliveryDate.contains('T')) {
                              formattedDate = order.deliveryDate.split('T')[0];
                            }

                            final tripRequest = TripRequestSendRequest(
                              travelerId: currentUserId!,
                              orderId: order.id,
                              travelDate: formattedDate,
                              vehicleInfo: vehicleInfoController.text.trim(),
                              source: order.origin,
                              destination: order.destination,
                              pickupTime: startTimeController.text.trim(),
                              dropoffTime: endTimeController.text.trim(),
                            );

                            print('DEBUG: Sending trip request...');
                            print('DEBUG: Traveler ID: $currentUserId');
                            print('DEBUG: Order ID: ${order.id}');

                            final response = await _tripRequestService.sendTripRequest(tripRequest);

                            if (context.mounted) {
                              Navigator.of(context).pop();

                              if (response != null) {
                                _showSuccessDialog(
                                  tripRequestId: response.tripRequestId,
                                  orderOwner: order.userName,
                                );
                              } else {
                                _showSnackBar(
                                  'Failed to send request. Please try again.',
                                  Colors.red,
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                            print('ERROR: Failed to send trip request: $e');
                            if (context.mounted) {
                              _showSnackBar('Failed to send request: $e', Colors.red);
                            }
                          }
                        },
                        icon: const Icon(Icons.send_rounded, size: 20),
                        label: const Text(
                          'Send Request',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
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
                  hoursController.clear();
                  setState(() {
                    selectedVehicle = null;
                    originPosition = null;
                    destinationPosition = null;
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
                    IconButton(
                      icon: const Icon(Icons.notifications_none),
                      iconSize: 28,
                      onPressed: () {},
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
                    if (originPosition != null && destinationPosition != null) ...[
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
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.map,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'View Route on Map',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'NEW',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
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
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: buildInputBox('Date (YYYY-MM-DD)', dateController, Icons.calendar_today),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildVehicleDropdown(),
                    const SizedBox(height: 15),
                    buildInputBox('Travel Hours', hoursController, Icons.access_time,
                        keyboardType: TextInputType.number),
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey.shade300, width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car, color: AppColors.primary, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedVehicle,
                hint: Text(
                  'Select Transportation Mode',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
                items: vehicleOptions.map((String vehicle) {
                  return DropdownMenuItem<String>(
                    value: vehicle,
                    child: Row(
                      children: [
                        _getVehicleIcon(vehicle),
                        const SizedBox(width: 12),
                        Text(vehicle),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedVehicle = newValue;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getVehicleIcon(String vehicle) {
    IconData icon;
    Color color = AppColors.primary;

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
        color = Colors.orange;
        break;
      case 'Bus':
        icon = Icons.directions_bus;
        break;
      case 'Train':
        icon = Icons.train;
        color = Colors.blue;
        break;
      case 'Plane':
        icon = Icons.flight;
        color = Colors.purple;
        break;
      default:
        icon = Icons.directions_car;
    }

    return Icon(icon, size: 18, color: color);
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey.shade300, width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: label,
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
                border: InputBorder.none,
              ),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
            ),
          ),
        ],
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