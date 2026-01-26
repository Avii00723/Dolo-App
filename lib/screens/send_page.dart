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
import '../widgets/addStopoverbotttomsheet.dart';
import 'LocationinputField.dart';
import 'CustomRoutePreviewScreen.dart';
import 'Widgets/sendtriprequestpage.dart';
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
  final TextEditingController departureController = TextEditingController();
  final TextEditingController deliveryController = TextEditingController();

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

  String? _selectedDate;
  String? _selectedTime;
  String? _departureDate;
  String? _departureTime;

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
    departureController.dispose();
    deliveryController.dispose();
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

  Future<void> _showRouteMap() async {
    if (originPosition == null || destinationPosition == null) {
      _showSnackBar('Please select both origin and destination', Colors.orange);
      return;
    }

    if (selectedVehicle == null) {
      _showSnackBar('Please select a vehicle type', Colors.orange);
      return;
    }

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
      builder: (context) => AddStopoverBottomSheet(
        controller: stopoverController,
        onAdd: (cityName, latitude, longitude) {
          _addStopover(cityName, latitude, longitude);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _selectDepartureDateTime(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && context.mounted) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppColors.primary,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        final combinedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        final dateStr = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
        final hour = pickedTime.hour.toString().padLeft(2, '0');
        final minute = pickedTime.minute.toString().padLeft(2, '0');
        final timeStr = '$hour:$minute:00';

        setState(() {
          _departureDate = dateStr;
          _departureTime = timeStr;
          departureController.text = DateFormat('dd/MM/yyyy').format(combinedDateTime) + ' ' + DateFormat('HH:MM').format(combinedDateTime);
        });

        print('🛫 Departure DateTime Display: ${departureController.text}');
        print('🛫 Departure Date for API: $_departureDate');
        print('🛫 Departure Time for API: $_departureTime');
      }
    }
  }

  Future<void> _selectDeliveryDateTime(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && context.mounted) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppColors.primary,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        final combinedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        final dateStr = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
        final hour = pickedTime.hour.toString().padLeft(2, '0');
        final minute = pickedTime.minute.toString().padLeft(2, '0');
        final timeStr = '$hour:$minute:00';

        setState(() {
          _selectedDate = dateStr;
          _selectedTime = timeStr;
          deliveryController.text = DateFormat('dd/MM/yyyy').format(combinedDateTime) + ' ' + DateFormat('HH:MM').format(combinedDateTime);
        });

        print('📦 Delivery DateTime Display: ${deliveryController.text}');
        print('📦 Delivery Date for API: $_selectedDate');
        print('📦 Delivery Time for API: $_selectedTime');
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
        _departureDate == null ||
        _departureTime == null ||
        _selectedDate == null ||
        _selectedTime == null ||
        selectedVehicle == null) {
      _showSnackBar('Please fill all required fields', Colors.red);
      return;
    }

    if (originPosition == null) {
      _showSnackBar('Please select origin location from suggestions', Colors.orange);
      return;
    }

    setState(() {
      isSearching = true;
    });

    try {
      String? stopoversParam;
      if (stopovers.isNotEmpty) {
        stopoversParam = stopovers.map((s) => s['city'] as String).join(',');
      }

      final orders = await _orderService.searchOrders(
        origin: fromController.text.trim(),
        destination: toController.text.trim(),
        departureDate: _departureDate!,
        departureTime: _departureTime!,
        deliveryDate: _selectedDate!,
        deliveryTime: _selectedTime!,
        originLatitude: originPosition!.latitude,
        originLongitude: originPosition!.longitude,
        vehicle: selectedVehicle!,
        userId: currentUserId!,
        stopovers: stopoversParam,
      );

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
              date: deliveryController.text.trim(),
              searchedVehicle: selectedVehicle!,
              onSendRequest: (order) => _sendRequestToSender(order),
              departureDate: _departureDate!,
              departureTime: _departureTime!,
              deliveryDate: _selectedDate!,
              deliveryTime: _selectedTime!,
            ),
          ),
        );
      }

      if (orders.isEmpty) {
        _showSnackBar('No orders found for this route', Colors.orange);
      }
    } catch (e) {
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

    if (order.id.isEmpty) {
      _showSnackBar('Invalid order: Missing order ID', Colors.red);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SendTripRequestPage(
          order: order,
          currentUserId: currentUserId!,
          tripRequestService: _tripRequestService,
          departureDate: _departureDate!,
          departureTime: _departureTime!,
          deliveryDate: _selectedDate!,
          deliveryTime: _selectedTime!,
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
                  departureController.clear();
                  deliveryController.clear();
                  setState(() {
                    selectedVehicle = null;
                    originPosition = null;
                    destinationPosition = null;
                    _departureDate = null;
                    _departureTime = null;
                    _selectedDate = null;
                    _selectedTime = null;
                    stopovers.clear();
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
        backgroundColor: Colors.white,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Search Orders',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Travel Details Section
                    const Text(
                      'Travel Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // From Location
                    _buildModernLocationField(
                      controller: fromController,
                      label: 'Traveling From',
                      hint: 'Eg. Mumbai',
                      icon: Icons.trip_origin,
                      isOrigin: true,
                    ),
                    const SizedBox(height: 12),

                    // To Location with Stopovers
                    Column(
                      children: [
                        _buildModernLocationField(
                          controller: toController,
                          label: 'Traveling To',
                          hint: 'Eg. Delhi',
                          icon: Icons.location_on,
                          isOrigin: false,
                        ),

                        // Stopovers Display
                        if (stopovers.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...stopovers.asMap().entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildStopoverChip(entry.key, entry.value),
                            );
                          }).toList(),
                        ],
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Action Buttons Row
                    Row(
                      children: [
                        // Select from Map Button
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.map,
                            label: 'Select from map',
                            onTap: () {
                              // Handle map selection
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Add Stops Button
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.add_circle_outline,
                            label: 'Add Stops',
                            onTap: _showAddStopoverDialog,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Date & Time Fields
                    _buildDateTimeField(
                      controller: departureController,
                      label: 'Departure Date & Time',
                      icon: Icons.calendar_today,
                      onTap: () => _selectDepartureDateTime(context),
                    ),
                    const SizedBox(height: 12),
                    _buildDateTimeField(
                      controller: deliveryController,
                      label: 'Delivery Date & Time',
                      icon: Icons.schedule,
                      onTap: () => _selectDeliveryDateTime(context),
                    ),

                    const SizedBox(height: 24),

                    // Travel Transport
                    const Text(
                      'Travel Transport',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildVehicleSelector(),

                    const SizedBox(height: 32),

                    // View Route Button
                    if (originPosition != null && destinationPosition != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: OutlinedButton.icon(
                          onPressed: _showRouteMap,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.map, color: AppColors.primary),
                          label: const Text(
                            'View Route on Map',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),

                    // Search Orders Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSearching ? null : _searchAvailableOrders,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
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
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernLocationField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isOrigin,
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
        EnhancedLocationInputField(
          controller: controller,
          label: '',
          hint: hint,
          icon: icon,
          isOrigin: isOrigin,
          onLocationSelected: (position) {
            setState(() {
              if (isOrigin) {
                originPosition = position;
              } else {
                destinationPosition = position;
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildStopoverChip(int index, Map<String, dynamic> stopover) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              stopover['city'],
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: Colors.grey[600],
            onPressed: () => _removeStopover(index),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.grey[700]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
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
        GestureDetector(
          onTap: onTap,
          child: AbsorbPointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      controller.text.isEmpty ? 'dd/mm/yyyy  HH:MM' : controller.text,
                      style: TextStyle(
                        fontSize: 14,
                        color: controller.text.isEmpty ? Colors.grey[500] : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedVehicle,
          hint: Row(
            children: [
              Icon(Icons.directions_car, size: 20, color: Colors.grey[500]),
              const SizedBox(width: 12),
              Text(
                'Eg. Car',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
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
            }

            return DropdownMenuItem<String>(
              value: vehicle,
              child: Row(
                children: [
                  Icon(icon, size: 20, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    vehicle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
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