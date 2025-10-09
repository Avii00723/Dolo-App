import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../Constants/colorconstant.dart';
import '../../Services/LocationService.dart';
import '../../Models/OrderModel.dart';
import '../../Models/TripRequestModel.dart';
import '../Controllers/OrderService.dart';
import '../Controllers/TripRequestService.dart';
import '../Controllers/AuthService.dart';
import 'LocationinputField.dart';
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

  // Vehicle selection
  String? selectedVehicle;
  final List<String> vehicleOptions = [
    'Car',
    'SUV',
    'Bike',
    'Auto Rickshaw',
    'Tempo',
    'Pickup Truck',
    'Mini Truck',
    'Truck',
    'Bus',
    'Train',
    'Plane',
  ];

  bool isLoading = false;
  bool isSearching = false;
  List<Order> availableOrders = [];

  // Services
  final OrderService _orderService = OrderService();
  final TripRequestService _tripRequestService = TripRequestService();

  // ✅ Position variables for location tracking
  Position? originPosition;
  Position? destinationPosition;

  int? currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeUser();
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
        content: Container(
          width: MediaQuery.of(dialogContext).size.width * 0.9,
          constraints: const BoxConstraints(maxHeight: 650),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 15),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Send Trip Request',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Fill in your travel details',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
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
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade50,
                              Colors.blue.shade50.withOpacity(0.5),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Order Details',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildOrderDetailRow(
                              Icons.location_on,
                              'Route',
                              '${order.origin} → ${order.destination}',
                              Colors.green,
                            ),
                            const SizedBox(height: 8),
                            _buildOrderDetailRow(
                              Icons.calendar_today,
                              'Date',
                              order.deliveryDate,
                              Colors.orange,
                            ),
                            const SizedBox(height: 8),
                            _buildOrderDetailRow(
                              Icons.inventory_2,
                              'Item',
                              order.itemDescription,
                              Colors.purple,
                            ),
                            const SizedBox(height: 8),
                            _buildOrderDetailRow(
                              Icons.scale,
                              'Weight',
                              '${order.weight} kg',
                              Colors.red,
                            ),
                            if (order.calculatedPrice != null) ...[
                              const SizedBox(height: 8),
                              _buildOrderDetailRow(
                                Icons.currency_rupee,
                                'Estimated Price',
                                '₹${order.calculatedPrice}',
                                Colors.green.shade700,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Your Travel Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 15),

                      _buildReadOnlyField(
                        label: 'Vehicle Type',
                        value: selectedVehicle ?? 'Not selected',
                        icon: Icons.directions_car,
                      ),
                      const SizedBox(height: 15),

                      _buildEnhancedTextField(
                        controller: vehicleInfoController,
                        label: 'Vehicle Number',
                        hint: 'e.g., XX XX XX XXXX',
                        icon: Icons.info_outline,
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
                            print('DEBUG: Vehicle Info: ${vehicleInfoController.text}');
                            print('DEBUG: Pickup Time: ${startTimeController.text}');
                            print('DEBUG: Dropoff Time: ${endTimeController.text}');

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
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderDetailRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
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
    required int tripRequestId,
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
                    availableOrders = [];
                  });
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'View My Requests',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
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
                    // ✅ REPLACED WITH ENHANCED LOCATION INPUT FIELD
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

                    // ✅ REPLACED WITH ENHANCED LOCATION INPUT FIELD
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
                            valueColor: AlwaysStoppedAnimation(Colors.white),
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
      case 'SUV':
        icon = Icons.airport_shuttle;
        break;
      case 'Bike':
        icon = Icons.two_wheeler;
        break;
      case 'Auto Rickshaw':
        icon = Icons.electric_rickshaw;
        break;
      case 'Tempo':
      case 'Pickup Truck':
        icon = Icons.local_shipping;
        break;
      case 'Mini Truck':
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(Icons.search, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Found ${availableOrders.length} Order${availableOrders.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: availableOrders.length,
          itemBuilder: (context, index) {
            final order = availableOrders[index];
            return CompactOrderCard(
              order: order,
              onSendRequest: () => _sendRequestToSender(order),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Image.asset(
              'assets/images/truck.png',
              height: 130,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'How it works',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Search for package delivery orders by selecting your route and travel date. Send requests to earn money by delivering packages.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInputBox(String label, TextEditingController controller, IconData icon,
      {TextInputType keyboardType = TextInputType.text}) {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey.shade300, width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 16, color: Colors.black),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey[600]),
            icon: Icon(icon, color: AppColors.primary, size: 20),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    dateController.dispose();
    hoursController.dispose();
    super.dispose();
  }
}

// Compact Order Card Widget
class CompactOrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onSendRequest;

  const CompactOrderCard({
    Key? key,
    required this.order,
    required this.onSendRequest,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      shadowColor: Colors.black12,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.green.shade50.withOpacity(0.3)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      order.userName.isNotEmpty ? order.userName[0].toUpperCase() : 'S',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.userName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Package Sender',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[600],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'AVAILABLE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        shape: BoxShape.circle,
                      ),
                    ),
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
                    Icon(Icons.arrow_forward, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red[600],
                        shape: BoxShape.circle,
                      ),
                    ),
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
              ),
              const SizedBox(height: 10),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCompactDetail(Icons.calendar_today, order.deliveryDate),
                    const SizedBox(width: 8),
                    _buildCompactDetail(Icons.inventory, order.itemDescription),
                    const SizedBox(width: 8),
                    _buildCompactDetail(Icons.scale, '${order.weight} kg'),
                    const SizedBox(width: 8),
                    if (order.distanceKm != null)
                      _buildCompactDetail(Icons.social_distance, '${order.distanceKm!.toStringAsFixed(1)} km'),
                    const SizedBox(width: 8),
                    if (order.calculatedPrice != null)
                      _buildCompactDetail(Icons.currency_rupee, '₹${order.calculatedPrice}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: onSendRequest,
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text(
                    'Send Request',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactDetail(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}