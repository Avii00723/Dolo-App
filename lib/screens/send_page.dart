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
  // Location and Trip Details
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final List<TextEditingController> stopoverControllers = [];
  Position? originPosition;
  Position? destinationPosition;
  final List<Position?> stopoverPositions = [];

  // Date and Time Controllers
  final TextEditingController departureController = TextEditingController();
  final TextEditingController deliveryController = TextEditingController();
  String? _departureDate, _departureTime;
  String? _selectedDate, _selectedTime;

  // Vehicle
  String? selectedVehicle;
  final List<String> vehicleOptions = [
    'Car', 'Bike', 'Pickup Truck', 'Truck', 'Bus', 'Train', 'Plane'
  ];

  // Services
  final OrderService _orderService = OrderService();
  final TripRequestService _tripRequestService = TripRequestService();
  String? currentUserId;

  // UI State
  bool isLoading = true; // Start with loading true
  bool isSearching = false;
  bool _isLocationViewFocused = false;
  String? _focusedField; // 'from', 'to', or 'stopover_i'

  // Focus Nodes
  final FocusNode _fromFocusNode = FocusNode();
  final FocusNode _toFocusNode = FocusNode();
  final List<FocusNode> _stopoverFocusNodes = [];

  // Recent Searches
  final List<Map<String, String>> _recentSearches = [
    {'city': 'Delhi', 'country': 'India'},
    {'city': 'Mumbai', 'country': 'India'},
    {'city': 'Bangalore', 'country': 'India'},
    {'city': 'Kolkata', 'country': 'India'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeUserAndData();
    _addFocusListeners();
  }

  @override
  void dispose() {
    // Dispose all controllers and focus nodes
    fromController.dispose();
    toController.dispose();
    departureController.dispose();
    deliveryController.dispose();
    _fromFocusNode.dispose();
    _toFocusNode.dispose();
    for (var controller in stopoverControllers) {
      controller.dispose();
    }
    for (var focusNode in _stopoverFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _addFocusListeners() {
    _fromFocusNode.addListener(() {
      if (_fromFocusNode.hasFocus) {
        setState(() {
          _isLocationViewFocused = true;
          _focusedField = 'from';
        });
      }
    });
    _toFocusNode.addListener(() {
      if (_toFocusNode.hasFocus) {
        setState(() {
          _isLocationViewFocused = true;
          _focusedField = 'to';
        });
      }
    });
  }

  Future<void> _initializeUserAndData() async {
    setState(() => isLoading = true);
    await _initializeUser();
    // Any other async data loading can happen here
    setState(() => isLoading = false);
  }

  Future<void> _initializeUser() async {
    try {
      currentUserId = await AuthService.getUserId();
      if (currentUserId == null) {
        _showSnackBar('Please log in to continue', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error loading user data: $e', Colors.red);
    }
  }

  void _addStopoverField() {
    setState(() {
      final newController = TextEditingController();
      final newFocusNode = FocusNode();
      newFocusNode.addListener(() {
        if (newFocusNode.hasFocus) {
          setState(() {
            _isLocationViewFocused = true;
            _focusedField = 'stopover_${stopoverControllers.length}';
          });
        }
      });
      stopoverControllers.add(newController);
      _stopoverFocusNodes.add(newFocusNode);
      stopoverPositions.add(null);
    });
    // Focus the newly added field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_stopoverFocusNodes.last);
    });
  }

  void _removeStopoverField(int index) {
    setState(() {
      stopoverControllers[index].dispose();
      _stopoverFocusNodes[index].dispose();
      stopoverControllers.removeAt(index);
      _stopoverFocusNodes.removeAt(index);
      stopoverPositions.removeAt(index);
    });
  }
  
  void _onDoneEditingLocation() {
    setState(() {
      _isLocationViewFocused = false;
      _focusedField = null;
    });
    FocusScope.of(context).unfocus();
  }
  
  // Method to handle back press
  Future<bool> _onWillPop() async {
    if (_isLocationViewFocused) {
      setState(() {
        _isLocationViewFocused = false;
        _focusedField = null;
      });
      FocusScope.of(context).unfocus();
      return false; // Do not pop the route
    }
    return true; // Pop the route
  }


  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        body: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: Stack(
                        children: [
                          // Always visible main content
                          AnimatedOpacity(
                            opacity: _isLocationViewFocused ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 300),
                            child: IgnorePointer(
                              ignoring: _isLocationViewFocused,
                              child: _buildMainForm(),
                            ),
                          ),
                          // Location view that slides/fades in
                          if (_isLocationViewFocused)
                            _buildLocationView(),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () {
              if (_isLocationViewFocused) {
                _onDoneEditingLocation();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          const Text(
            'Travel Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(width: 48) // Placeholder for alignment
        ],
      ),
    );
  }

  Widget _buildLocationView() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        color: Colors.white,
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildLocationTextField(
                      controller: fromController,
                      focusNode: _fromFocusNode,
                      hintText: 'Eg. Mumbai',
                      labelText: 'Traveling From'),
                  const SizedBox(height: 16),
                  _buildLocationTextField(
                      controller: toController,
                      focusNode: _toFocusNode,
                      hintText: 'Eg. Delhi',
                      labelText: 'Traveling To'),
                  const SizedBox(height: 10),
                  ..._buildStopoverFields(),
                  
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _addStopoverField,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Stops'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  
                  const Divider(height: 30),
                  
                  // Suggestions/Recents
                  const Text('RECENT SEARCHES', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 10),
                  ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(), // The parent is already scrollable
                    children: _recentSearches.map((search) {
                      return ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(search['city']!),
                        subtitle: Text(search['country']!),
                        onTap: () {
                          // Handle selection
                          _handleRecentSearchSelection(search['city']!);
                        },
                      );
                    }).toList(),
                  ),
                  
                  // Action Buttons at bottom
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {}, // Implement View Route
                            child: const Text('View Route on Map'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _onDoneEditingLocation,
                            child: const Text('Done'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
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
      ),
    );
  }

void _handleRecentSearchSelection(String city) {
  final field = _focusedField;
  if (field == 'from') {
    fromController.text = city;
  } else if (field == 'to') {
    toController.text = city;
  } else if (field != null && field.startsWith('stopover_')) {
    final index = int.parse(field.split('_').last);
    if (index < stopoverControllers.length) {
      stopoverControllers[index].text = city;
    }
  }
}
  
  List<Widget> _buildStopoverFields() {
    return List<Widget>.generate(stopoverControllers.length, (index) {
      return Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Row(
          children: [
            Expanded(
              child: _buildLocationTextField(
                controller: stopoverControllers[index],
                focusNode: _stopoverFocusNodes[index],
                hintText: 'Eg. Lonavla',
                labelText: 'Stopover ${index + 1}',
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () => _removeStopoverField(index),
            )
          ],
        ),
      );
    });
  }

  Widget _buildMainForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildReadOnlyLocationField('Traveling From', fromController.text, _fromFocusNode),
          const SizedBox(height: 16),
          _buildReadOnlyLocationField('Traveling To', toController.text, _toFocusNode),
          ..._buildReadOnlyStopoverFields(),
          const SizedBox(height: 24),
          _buildDateTimeField(departureController, 'Departure Date & Time', _selectDepartureDateTime),
          const SizedBox(height: 16),
          _buildDateTimeField(deliveryController, 'Delivery Date & Time', _selectDeliveryDateTime),
          const SizedBox(height: 16),
          _buildVehicleDropdown(),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSearching ? null : () {/* _searchAvailableOrders(); */},
              child: isSearching
                  ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white))
                  : const Text('Search Orders'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  Widget _buildReadOnlyLocationField(String label, String value, FocusNode focusNode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            setState(() {
              _isLocationViewFocused = true;
              if (focusNode == _fromFocusNode) _focusedField = 'from';
              if (focusNode == _toFocusNode) _focusedField = 'to';
            });
            focusNode.requestFocus();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(value.isEmpty ? 'Eg. Mumbai' : value, style: TextStyle(color: value.isEmpty ? Colors.grey: Colors.black)),
          ),
        ),
      ],
    );
  }
  
  List<Widget> _buildReadOnlyStopoverFields() {
    return List.generate(stopoverControllers.length, (index) {
      return Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: _buildReadOnlyLocationField('Stopover ${index + 1}', stopoverControllers[index].text, _stopoverFocusNodes[index]),
      );
    });
  }

  void _handleLocationSelection(prediction) {
    if (prediction.lat == null || prediction.lng == null) return;

    final position = Position(
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
    final address = prediction.description ?? '';

    setState(() {
      final field = _focusedField;
      if (field == 'from') {
        fromController.text = address;
        originPosition = position;
      } else if (field == 'to') {
        toController.text = address;
        destinationPosition = position;
      } else if (field != null && field.startsWith('stopover_')) {
        final index = int.parse(field.split('_').last);
        if (index < stopoverControllers.length) {
          stopoverControllers[index].text = address;
          stopoverPositions[index] = position;
        }
      }
    });
  }

  Widget _buildLocationTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required String labelText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(labelText, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GooglePlacesAutoCompleteTextFormField(
          textEditingController: controller,
          focusNode: focusNode,
          config: const GoogleApiConfig(
            apiKey: 'AIzaSyBin4hsTqp0DSLCzjmQwuB78hBHZRhG_3Y',
            countries: ['in'],
            fetchPlaceDetailsWithCoordinates: true,
            debounceTime: 400,
          ),
          onPredictionWithCoordinatesReceived: (prediction) {
             _handleLocationSelection(prediction);
          },
          onSuggestionClicked: (prediction) {
            controller.text = prediction.description ?? '';
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: prediction.description?.length ?? 0),
            );
          },
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.location_on_outlined),
            filled: true,
            fillColor: Colors.grey.shade200,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
             focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeField(TextEditingController controller, String label, Function(BuildContext) onTap) {
      return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => onTap(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                 Icon(Icons.calendar_today_outlined, color: Colors.grey.shade600),
                 const SizedBox(width: 8),
                 Text(controller.text.isEmpty ? 'dd/mm/yyyy HH:MM' : controller.text, style: TextStyle(color: controller.text.isEmpty ? Colors.grey: Colors.black)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDepartureDateTime(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(2101));
    if (pickedDate != null) {
      TimeOfDay? pickedTime =
          await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (pickedTime != null) {
        final dateTime = DateTime(pickedDate.year, pickedDate.month,
            pickedDate.day, pickedTime.hour, pickedTime.minute);
        setState(() {
          departureController.text = DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
          _departureDate = DateFormat('yyyy-MM-dd').format(dateTime);
          _departureTime = DateFormat('HH:mm:ss').format(dateTime);
        });
      }
    }
  }

  Future<void> _selectDeliveryDateTime(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(2101));
    if (pickedDate != null) {
      TimeOfDay? pickedTime =
          await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (pickedTime != null) {
        final dateTime = DateTime(pickedDate.year, pickedDate.month,
            pickedDate.day, pickedTime.hour, pickedTime.minute);
        setState(() {
          deliveryController.text = DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
          _selectedDate = DateFormat('yyyy-MM-dd').format(dateTime);
          _selectedTime = DateFormat('HH:mm:ss').format(dateTime);
        });
      }
    }
  }

 Widget _buildVehicleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Travel Transport', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selectedVehicle,
          hint: const Text('Eg. Car'),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.directions_car_outlined),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
             enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          items: vehicleOptions.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() {
              selectedVehicle = newValue;
            });
          },
        ),
      ],
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
    ));
  }
}
