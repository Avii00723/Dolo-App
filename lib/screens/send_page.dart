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

// =============================================================================
// DESIGN PRINCIPLE:
//   GooglePlacesAutoCompleteTextFormField calls addListener() on BOTH the
//   TextEditingController AND the FocusNode in its initState. If either has
//   been disposed before initState runs, you get the "used after disposed" crash.
//
//   Solution: _PlacesField (StatefulWidget) owns BOTH internally.
//   The parent passes only the initial text string and receives updates via
//   callbacks. No disposed object ever crosses a widget-mount boundary.
// =============================================================================

// ─────────────────────────────────────────────────────────────────────────────
// Stopover data — stores text + position only. No controllers, no nodes.
// ─────────────────────────────────────────────────────────────────────────────
class _StopoverData {
  String text;
  Position? position;
  _StopoverData({this.text = '', this.position});
}

// =============================================================================
// _PlacesField
// Owns its TextEditingController AND FocusNode — both created in initState,
// both disposed in dispose(). The parent never touches them directly.
// =============================================================================
class _PlacesField extends StatefulWidget {
  final String initialText;
  final String labelText;
  final String hintText;
  final VoidCallback? onFocusGained;
  final void Function(String text, Position position) onLocationSelected;

  const _PlacesField({
    Key? key,
    required this.initialText,
    required this.labelText,
    required this.hintText,
    this.onFocusGained,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  State<_PlacesField> createState() => _PlacesFieldState();
}

class _PlacesFieldState extends State<_PlacesField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    // Both created fresh here — guaranteed live when GooglePlaces reads them
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) widget.onFocusGained?.call();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void requestFocus() {
    if (mounted) FocusScope.of(context).requestFocus(_focusNode);
  }

  Position _makePosition(dynamic prediction) => Position(
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.labelText,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GooglePlacesAutoCompleteTextFormField(
          // Always receives a fresh, live controller and focus node
          textEditingController: _controller,
          focusNode: _focusNode,
          config: const GoogleApiConfig(
            apiKey: 'AIzaSyBin4hsTqp0DSLCzjmQwuB78hBHZRhG_3Y',
            countries: ['in'],
            fetchPlaceDetailsWithCoordinates: true,
            debounceTime: 400,
          ),
          onPredictionWithCoordinatesReceived: (prediction) {
            if (prediction.lat == null || prediction.lng == null) return;
            final text = prediction.description ?? '';
            setState(() => _controller.text = text);
            widget.onLocationSelected(text, _makePosition(prediction));
          },
          onSuggestionClicked: (prediction) {
            final text = prediction.description ?? '';
            _controller.text = text;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: text.length),
            );
          },
          decoration: InputDecoration(
            hintText: widget.hintText,
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
}

// =============================================================================
// _StopoverRow — wraps _PlacesField with a remove button
// =============================================================================
class _StopoverRow extends StatefulWidget {
  final int index;
  final String initialText;
  final VoidCallback onRemove;
  final VoidCallback onFocusGained;
  final void Function(String text, Position position) onLocationSelected;

  const _StopoverRow({
    Key? key,
    required this.index,
    required this.initialText,
    required this.onRemove,
    required this.onFocusGained,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  State<_StopoverRow> createState() => _StopoverRowState();
}

class _StopoverRowState extends State<_StopoverRow> {
  final GlobalKey<_PlacesFieldState> _fieldKey = GlobalKey();

  void requestFocus() => _fieldKey.currentState?.requestFocus();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        children: [
          Expanded(
            child: _PlacesField(
              key: _fieldKey,
              initialText: widget.initialText,
              labelText: 'Stopover ${widget.index + 1}',
              hintText: 'Eg. Lonavla',
              onFocusGained: widget.onFocusGained,
              onLocationSelected: widget.onLocationSelected,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _LocationSearchView — stateless; all lifecycle is in child StatefulWidgets
// =============================================================================
class _LocationSearchView extends StatelessWidget {
  final String fromText;
  final String toText;
  final List<_StopoverData> stopovers;
  final List<GlobalKey<_StopoverRowState>> stopoverKeys;
  final List<Map<String, String>> recentSearches;
  final String? focusedField;

  final VoidCallback onDone;
  final VoidCallback onAddStop;
  final void Function(int) onRemoveStop;
  final void Function(String field) onFieldFocused;
  final void Function(String text, Position pos) onFromSelected;
  final void Function(String text, Position pos) onToSelected;
  final void Function(int index, String text, Position pos) onStopoverSelected;
  final void Function(String city) onRecentSearch;

  const _LocationSearchView({
    Key? key,
    required this.fromText,
    required this.toText,
    required this.stopovers,
    required this.stopoverKeys,
    required this.recentSearches,
    required this.focusedField,
    required this.onDone,
    required this.onAddStop,
    required this.onRemoveStop,
    required this.onFieldFocused,
    required this.onFromSelected,
    required this.onToSelected,
    required this.onStopoverSelected,
    required this.onRecentSearch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        color: Colors.white,
        height: MediaQuery.of(context).size.height,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // FROM — fresh controller+focusnode every mount
                _PlacesField(
                  initialText: fromText,
                  labelText: 'Traveling From',
                  hintText: 'Eg. Mumbai',
                  onFocusGained: () => onFieldFocused('from'),
                  onLocationSelected: onFromSelected,
                ),
                const SizedBox(height: 16),
                // TO — fresh controller+focusnode every mount
                _PlacesField(
                  initialText: toText,
                  labelText: 'Traveling To',
                  hintText: 'Eg. Delhi',
                  onFocusGained: () => onFieldFocused('to'),
                  onLocationSelected: onToSelected,
                ),
                const SizedBox(height: 10),
                for (int i = 0; i < stopovers.length; i++)
                  _StopoverRow(
                    key: stopoverKeys[i],
                    index: i,
                    initialText: stopovers[i].text,
                    onRemove: () => onRemoveStop(i),
                    onFocusGained: () => onFieldFocused('stopover_$i'),
                    onLocationSelected: (text, pos) =>
                        onStopoverSelected(i, text, pos),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onAddStop,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Stops'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const Divider(height: 30),
                const Text('RECENT SEARCHES',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 10),
                ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: recentSearches.map((s) {
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(s['city']!),
                      subtitle: Text(s['country']!),
                      onTap: () => onRecentSearch(s['city']!),
                    );
                  }).toList(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey.shade400),
                          ),
                          child: const Text('View Route on Map'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onDone,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Done'),
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
}

// =============================================================================
// SendPage — holds only plain data (strings, positions). Zero controllers/nodes.
// =============================================================================
class SendPage extends StatefulWidget {
  const SendPage({Key? key}) : super(key: key);

  @override
  _SendPageState createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  // ── Location data (plain strings + positions, NO controllers) ────────────
  String _fromText = '';
  String _toText = '';
  Position? originPosition;
  Position? destinationPosition;

  // Stopovers: plain data only
  final List<_StopoverData> _stopovers = [];
  final List<GlobalKey<_StopoverRowState>> _stopoverKeys = [];

  // ── Date / Time ───────────────────────────────────────────────────────────
  // These controllers are safe because they are NEVER passed to
  // GooglePlacesAutoCompleteTextFormField — no addListener() risk.
  final TextEditingController departureController = TextEditingController();
  final TextEditingController deliveryController = TextEditingController();
  String? _departureDate, _departureTime;
  String? _selectedDate, _selectedTime;
  
  DateTime? _departureDateTime;
  DateTime? _deliveryDateTime;

  // ── Vehicle ───────────────────────────────────────────────────────────────
  String? selectedVehicle;
  final List<String> vehicleOptions = [
    'Car', 'Bike', 'Pickup Truck', 'Truck', 'Bus', 'Train', 'Plane'
  ];

  // ── Services ──────────────────────────────────────────────────────────────
  final OrderService _orderService = OrderService();
  final TripRequestService _tripRequestService = TripRequestService();
  String? currentUserId;

  // ── UI State ──────────────────────────────────────────────────────────────
  bool isLoading = true;
  bool isSearching = false;
  bool _isLocationViewFocused = false;
  String? _focusedField;

  // ── Recent Searches ───────────────────────────────────────────────────────
  final List<Map<String, String>> _recentSearches = [
    {'city': 'Delhi', 'country': 'India'},
    {'city': 'Mumbai', 'country': 'India'},
    {'city': 'Bangalore', 'country': 'India'},
    {'city': 'Kolkata', 'country': 'India'},
  ];

  // ──────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initializeUserAndData();
  }

  @override
  void dispose() {
    departureController.dispose();
    deliveryController.dispose();
    // No other controllers or focus nodes to dispose —
    // they all live inside widget States and are cleaned up automatically.
    super.dispose();
  }

  Future<void> _initializeUserAndData() async {
    setState(() => isLoading = true);
    try {
      currentUserId = await AuthService.getUserId();
      if (currentUserId == null) _showSnackBar('Please log in', Colors.red);
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
    setState(() => isLoading = false);
  }

  // ── Stopover management ───────────────────────────────────────────────────

  void _addStopoverField() {
    final key = GlobalKey<_StopoverRowState>();
    setState(() {
      _stopovers.add(_StopoverData());
      _stopoverKeys.add(key);
      _isLocationViewFocused = true;
      _focusedField = 'stopover_${_stopovers.length - 1}';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) key.currentState?.requestFocus();
    });
  }

  void _removeStopoverField(int index) {
    // No disposal needed — _StopoverRow/_PlacesField States handle their own
    setState(() {
      _stopovers.removeAt(index);
      _stopoverKeys.removeAt(index);
      if (_focusedField == 'stopover_$index') _focusedField = null;
    });
  }

  // ── Location overlay control ──────────────────────────────────────────────

  void _showLocationView(String field) {
    setState(() {
      _isLocationViewFocused = true;
      _focusedField = field;
    });
  }

  void _hideLocationView() {
    setState(() {
      _isLocationViewFocused = false;
      _focusedField = null;
    });
    FocusScope.of(context).unfocus();
  }

  Future<bool> _onWillPop() async {
    if (_isLocationViewFocused) {
      _hideLocationView();
      return false;
    }
    return true;
  }

  // ── Recent search handler ─────────────────────────────────────────────────

  void _onRecentSearch(String city) {
    final field = _focusedField;
    setState(() {
      if (field == 'from') {
        _fromText = city;
      } else if (field == 'to') {
        _toText = city;
      } else if (field != null && field.startsWith('stopover_')) {
        final idx = int.tryParse(field.split('_').last);
        if (idx != null && idx < _stopovers.length) {
          _stopovers[idx].text = city;
        }
      }
    });
  }

  // ── Search Logic ─────────────────────────────────────────────────────────

  Future<void> _handleSearch() async {
    if (_fromText.isEmpty || _toText.isEmpty) {
      _showSnackBar('Please select origin and destination', Colors.orange);
      return;
    }

    if (originPosition == null) {
      _showSnackBar('Origin location not properly selected', Colors.orange);
      return;
    }

    if (_departureDate == null || _departureTime == null || _departureDateTime == null) {
      _showSnackBar('Please select departure date and time', Colors.orange);
      return;
    }

    if (_selectedDate == null || _selectedTime == null || _deliveryDateTime == null) {
      _showSnackBar('Please select delivery date and time', Colors.orange);
      return;
    }
    
    // Date Validation: Starting date should not be greater than ending date
    if (_deliveryDateTime!.isBefore(_departureDateTime!)) {
      _showSnackBar('Delivery date cannot be before departure date', Colors.red);
      return;
    }

    if (selectedVehicle == null) {
      _showSnackBar('Please select a vehicle', Colors.orange);
      return;
    }

    if (currentUserId == null) {
      _showSnackBar('User not found. Please log in.', Colors.red);
      return;
    }

    setState(() => isSearching = true);

    try {
      final stopoversStr = _stopovers
          .where((s) => s.text.isNotEmpty)
          .map((s) => s.text)
          .toList();

      final orders = await _orderService.searchOrders(
        origin: _fromText,
        destination: _toText,
        departureDate: _departureDate!,
        departureTime: _departureTime!,
        pickupDate: _departureDate!, // Using departure as pickup for now
        pickupTime: _departureTime!,
        deliveryDate: _selectedDate!,
        deliveryTime: _selectedTime!,
        originLatitude: originPosition!.latitude,
        originLongitude: originPosition!.longitude,
        vehicle: selectedVehicle!,
        userId: currentUserId!,
        stopovers: stopoversStr.isNotEmpty ? stopoversStr : null,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchResultsPage(
            orders: orders,
            fromLocation: _fromText,
            toLocation: _toText,
            date: departureController.text,
            searchedVehicle: selectedVehicle!,
            departureDate: _departureDate!,
            departureTime: _departureTime!,
            deliveryDate: _selectedDate!,
            deliveryTime: _selectedTime!,
            currentUserId: currentUserId!,
            tripRequestService: _tripRequestService,
            onSendRequest: (order) => _handleSendRequest(order),
          ),
        ),
      );
    } catch (e) {
      _showSnackBar('Search failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => isSearching = false);
    }
  }

  Future<void> _handleSendRequest(Order order) async {
    if (currentUserId == null) {
      _showSnackBar('User not found. Please log in.', Colors.red);
      return;
    }

    try {
      // API expects TripRequestSendRequest fields
      final request = TripRequestSendRequest(
        travelerId: currentUserId!,
        orderId: order.id,
        travelDate: '${_selectedDate}T$_selectedTime', // Updated to ISO format
        vehicleInfo: selectedVehicle ?? 'Car',
        source: _fromText,
        destination: _toText,
        departureDatetime: '${_departureDate}T$_departureTime', // Updated to ISO format
        comments: '',
        vehicleType: selectedVehicle ?? 'Car',
      );

      final response = await _tripRequestService.sendTripRequest(request);

      if (response != null) {
        if (!mounted) return;
        _showSnackBar('Trip request sent successfully!', Colors.green);
        Navigator.pop(context); // Go back from search results
      } else {
        _showSnackBar('Failed to send trip request', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error sending request: $e', Colors.red);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Stack(
                  children: [
                    // Main form always in tree, hidden while overlay shows
                    AnimatedOpacity(
                      opacity: _isLocationViewFocused ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: _isLocationViewFocused,
                        child: _buildMainForm(),
                      ),
                    ),
                    // Location overlay: mounts fresh every time.
                    // _PlacesField creates new controller+focusnode on each mount.
                    // _PlacesField disposes them automatically on unmount.
                    // No stale/disposed objects can ever reach GooglePlaces.
                    if (_isLocationViewFocused)
                      _LocationSearchView(
                        fromText: _fromText,
                        toText: _toText,
                        stopovers: _stopovers,
                        stopoverKeys: _stopoverKeys,
                        recentSearches: _recentSearches,
                        focusedField: _focusedField,
                        onDone: _hideLocationView,
                        onAddStop: _addStopoverField,
                        onRemoveStop: _removeStopoverField,
                        onFieldFocused: (f) =>
                            setState(() => _focusedField = f),
                        onFromSelected: (text, pos) => setState(() {
                          _fromText = text;
                          originPosition = pos;
                        }),
                        onToSelected: (text, pos) => setState(() {
                          _toText = text;
                          destinationPosition = pos;
                        }),
                        onStopoverSelected: (i, text, pos) =>
                            setState(() {
                              if (i < _stopovers.length) {
                                _stopovers[i].text = text;
                                _stopovers[i].position = pos;
                              }
                            }),
                        onRecentSearch: _onRecentSearch,
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => _isLocationViewFocused
                ? _hideLocationView()
                : Navigator.pop(context),
          ),
          const Text(
            'Travel Details',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ── Main form (read-only display) ─────────────────────────────────────────

  Widget _buildMainForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildReadOnlyField(
            label: 'Traveling From',
            value: _fromText,
            onTap: () => _showLocationView('from'),
          ),
          const SizedBox(height: 16),
          _buildReadOnlyField(
            label: 'Traveling To',
            value: _toText,
            onTap: () => _showLocationView('to'),
          ),
          for (int i = 0; i < _stopovers.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: _buildReadOnlyField(
                label: 'Stopover ${i + 1}',
                value: _stopovers[i].text,
                onTap: () => _showLocationView('stopover_$i'),
              ),
            ),
          const SizedBox(height: 24),
          _buildDateTimeField(departureController, 'Departure Date & Time',
              _selectDepartureDateTime),
          const SizedBox(height: 16),
          _buildDateTimeField(deliveryController, 'Delivery Date & Time',
              _selectDeliveryDateTime),
          const SizedBox(height: 16),
          _buildVehicleDropdown(),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSearching ? null : _handleSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              child: isSearching
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white)),
              )
                  : const Text('Search Orders'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              value.isEmpty ? 'Tap to enter location' : value,
              style: TextStyle(
                  color: value.isEmpty ? Colors.grey : Colors.black),
            ),
          ),
        ),
      ],
    );
  }

  // ── Date / Time ───────────────────────────────────────────────────────────

  Widget _buildDateTimeField(
      TextEditingController controller,
      String label,
      Future<void> Function(BuildContext) onTap,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => onTap(context),
          child: Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  controller.text.isEmpty
                      ? 'dd/mm/yyyy HH:MM'
                      : controller.text,
                  style: TextStyle(
                      color: controller.text.isEmpty
                          ? Colors.grey
                          : Colors.black),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDepartureDateTime(BuildContext context) async {
    final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(2101));
    if (date == null || !mounted) return;
    final time =
    await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    final dt =
    DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      _departureDateTime = dt;
      departureController.text =
          DateFormat('dd MMM yyyy, hh:mm a').format(dt);
      _departureDate = DateFormat('yyyy-MM-dd').format(dt);
      _departureTime = DateFormat('HH:mm:ss').format(dt);
    });
  }

  Future<void> _selectDeliveryDateTime(BuildContext context) async {
    final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(2101));
    if (date == null || !mounted) return;
    final time =
    await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    final dt =
    DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      _deliveryDateTime = dt;
      deliveryController.text =
          DateFormat('dd MMM yyyy, hh:mm a').format(dt);
      _selectedDate = DateFormat('yyyy-MM-dd').format(dt);
      _selectedTime = DateFormat('HH:mm:ss').format(dt);
    });
  }

  // ── Vehicle ───────────────────────────────────────────────────────────────

  Widget _buildVehicleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Travel Transport',
            style: TextStyle(fontWeight: FontWeight.w600)),
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
          items: vehicleOptions
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) => setState(() => selectedVehicle = v),
        ),
      ],
    );
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color));
  }
}