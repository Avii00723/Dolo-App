import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../Constants/colorconstant.dart';
import '../../Services/LocationService.dart';

import '../../Models/OrderModel.dart';
import '../../Models/TripRequestModel.dart';
import '../Controllers/OrderService.dart';
import '../Controllers/TripRequestService.dart';

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

  // Vehicle selection - UPDATED with Train and Plane
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

  // Location variables
  Position? originPosition;
  bool isLoadingLocation = false;

  // User ID - Replace with actual user ID from auth
  int userId = 5; // TODO: Get from auth service

  @override
  void initState() {
    super.initState();
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    setState(() {
      isLoadingLocation = true;
    });
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        final address = await LocationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        setState(() {
          originPosition = position;
          fromController.text = address ??
              'Current Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
          isLoadingLocation = false;
        });
        _showSnackBar('✅ Location coordinates saved', Colors.green);
      } else {
        setState(() {
          isLoadingLocation = false;
        });
        _showSnackBar('Unable to get location. Please check permissions.', Colors.red);
      }
    } catch (e) {
      setState(() {
        isLoadingLocation = false;
      });
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  // Search location from text input
  Future<void> _searchOriginLocation() async {
    if (fromController.text.trim().isEmpty) {
      _showSnackBar('Please enter a location to search', Colors.orange);
      return;
    }

    setState(() {
      isLoadingLocation = true;
    });

    try {
      final locations = await LocationService.getCoordinatesFromAddress(
          fromController.text.trim()
      );
      if (locations != null && locations.isNotEmpty) {
        final location = locations.first;
        final position = Position(
          latitude: location.latitude,
          longitude: location.longitude,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );

        setState(() {
          originPosition = position;
          isLoadingLocation = false;
        });
        _showSnackBar('✅ Origin coordinates found', Colors.green);
      } else {
        setState(() {
          isLoadingLocation = false;
        });
        _showSnackBar('Location not found. Please try different search.', Colors.orange);
      }
    } catch (e) {
      setState(() {
        isLoadingLocation = false;
      });
      _showSnackBar('Error searching location: $e', Colors.red);
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

  // Search available orders using API
  Future<void> _searchAvailableOrders() async {
    // Validate all required fields
    if (fromController.text.trim().isEmpty ||
        toController.text.trim().isEmpty ||
        dateController.text.trim().isEmpty ||
        selectedVehicle == null ||
        hoursController.text.trim().isEmpty) {
      _showSnackBar('Please fill all required fields', Colors.red);
      return;
    }

    // Validate origin position
    if (originPosition == null) {
      _showSnackBar('Please get coordinates for origin location', Colors.orange);
      return;
    }

    // Validate hours
    final hours = double.tryParse(hoursController.text.trim());
    if (hours == null || hours <= 0) {
      _showSnackBar('Please enter valid hours', Colors.red);
      return;
    }

    setState(() {
      isSearching = true;
      availableOrders.clear();
    });

    try {
      print('DEBUG: Starting search...');
      print('DEBUG: From: "${fromController.text.trim()}"');
      print('DEBUG: To: "${toController.text.trim()}"');
      print('DEBUG: Date: "${dateController.text.trim()}"');
      print('DEBUG: Origin Lat: ${originPosition!.latitude}');
      print('DEBUG: Origin Lng: ${originPosition!.longitude}');
      print('DEBUG: Vehicle: $selectedVehicle');
      print('DEBUG: Hours: $hours');

      // Call API to search orders
      final orders = await _orderService.searchOrders(
        origin: fromController.text.trim(),
        destination: toController.text.trim(),
        deliveryDate: dateController.text.trim(),
        originLatitude: originPosition!.latitude,
        originLongitude: originPosition!.longitude,
        vehicle: selectedVehicle!,
        timeHours: hours,
      );

      print('DEBUG: API returned ${orders.length} orders');

      setState(() {
        availableOrders = orders;
        isSearching = false;
      });

      if (orders.isEmpty) {
        _showSnackBar(
          'No orders found for this route on ${dateController.text.trim()}',
          Colors.orange,
        );
      } else {
        _showSnackBar(
          'Found ${orders.length} order${orders.length > 1 ? 's' : ''} on ${dateController.text.trim()}',
          Colors.green,
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

  // Send trip request to order creator
  Future<void> _sendRequestToSender(Order order) async {
    try {
      // Check if already sent request (you can add this check via API later)
      await _showTripRequestDialog(order);
    } catch (e) {
      _showSnackBar('Failed to send request: $e', Colors.red);
    }
  }

  // Show dialog to collect trip details
  Future<void> _showTripRequestDialog(Order order) async {
    final vehicleInfoController = TextEditingController();
    final vehicleDetailsController = TextEditingController();
    final spaceController = TextEditingController();
    final routeController = TextEditingController(
      text: '${order.origin} -> ${order.destination}',
    );

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Send Trip Request',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order.origin} → ${order.destination}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Date: ${order.deliveryDate}'),
                    Text('Item: ${order.itemDescription}'),
                    Text('Weight: ${order.weight}'),
                    if (order.calculatedPrice != null)
                      Text('Estimated Price: ₹${order.calculatedPrice}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: vehicleInfoController,
                decoration: InputDecoration(
                  labelText: 'Vehicle Information*',
                  hintText: 'e.g., Maruti Suzuki Swift, AC',
                  prefixIcon: const Icon(Icons.directions_car),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: vehicleDetailsController,
                decoration: InputDecoration(
                  labelText: 'Vehicle Details*',
                  hintText: 'e.g., Red, 4-seater, Petrol',
                  prefixIcon: const Icon(Icons.info_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: spaceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Available Space (kg)*',
                  hintText: 'e.g., 10',
                  prefixIcon: const Icon(Icons.inventory),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: routeController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Route*',
                  hintText: 'e.g., Pune -> Lonavala -> Mumbai',
                  prefixIcon: const Icon(Icons.route),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (vehicleInfoController.text.trim().isEmpty ||
                  vehicleDetailsController.text.trim().isEmpty ||
                  spaceController.text.trim().isEmpty ||
                  routeController.text.trim().isEmpty) {
                _showSnackBar('Please fill all required fields', Colors.red);
                return;
              }

              final availableSpace = int.tryParse(spaceController.text.trim());
              if (availableSpace == null || availableSpace <= 0) {
                _showSnackBar('Please enter valid available space', Colors.red);
                return;
              }

              try {
                // Prepare trip request
                final tripRequest = TripRequestSendRequest(
                  travelerId: userId,
                  orderId: order.id,
                  travelDate: order.deliveryDate,
                  availableSpace: availableSpace,
                  vehicleInfo: vehicleInfoController.text.trim(),
                  vehicleDetails: vehicleDetailsController.text.trim(),
                  source: order.origin,
                  destination: order.destination,
                  route: routeController.text.trim(),
                );

                // Send trip request via API
                final response = await _tripRequestService.sendTripRequest(tripRequest);

                if (response != null) {
                  Navigator.pop(context);
                  _showSnackBar(
                    'Request sent successfully! Trip Request ID: #${response.tripRequestId}',
                    Colors.green,
                  );
                } else {
                  _showSnackBar('Failed to send request', Colors.red);
                }
              } catch (e) {
                _showSnackBar('Failed to send request: $e', Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Send Request', style: TextStyle(color: Colors.white)),
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Header with logo and notifications
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
              // Title
              const Text(
                'Search Available Orders',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              // Search form
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
                    _buildLocationInputField(),
                    const SizedBox(height: 15),
                    buildInputBox('To', toController, Icons.location_on),
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
                    // Search button
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
              // Available Orders List
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

  // Location input field with search and current location buttons
  Widget _buildLocationInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border.all(color: Colors.grey.shade300, width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: fromController,
            style: const TextStyle(fontSize: 16, color: Colors.black),
            decoration: InputDecoration(
              labelText: 'From',
              labelStyle: TextStyle(color: Colors.grey[600]),
              icon: const Padding(
                padding: EdgeInsets.only(left: 15),
                child: Icon(Icons.my_location, color: AppColors.primary, size: 20),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoadingLocation)
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else ...[
                    IconButton(
                      icon: const Icon(Icons.gps_fixed),
                      onPressed: _getCurrentLocation,
                      tooltip: 'Use current location',
                      color: AppColors.primary,
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _searchOriginLocation,
                      tooltip: 'Search location',
                      color: AppColors.primary,
                    ),
                  ],
                ],
              ),
            ),
            onChanged: (value) {
              if (originPosition != null) {
                setState(() {
                  originPosition = null;
                });
              }
            },
          ),
        ),
        if (originPosition != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, color: Colors.green[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lat: ${originPosition!.latitude.toStringAsFixed(6)}, Lng: ${originPosition!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Vehicle Dropdown Widget
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

  // Helper method to get vehicle icon
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
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              fromController.clear();
              toController.clear();
              dateController.clear();
              hoursController.clear();
              setState(() {
                selectedVehicle = null;
                originPosition = null;
              });
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Clear Search'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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

