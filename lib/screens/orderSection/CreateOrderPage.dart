// Save this as: Pages/CreateOrderPage.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart';
import 'dart:io';
import 'dart:async';
import '../../Controllers/OrderService.dart';
import '../../Controllers/AuthService.dart';
import '../../Controllers/ProfileService.dart';
import '../../Constants/colorconstant.dart';
import '../../Models/OrderModel.dart';
import '../../Models/LoginModel.dart';
import '../LoginScreens/kyc_screen.dart';
import '../../Widgets/FloatingNotification.dart';

// =============================================================================
// DESIGN PRINCIPLE  (same as send_page.dart)
//   GooglePlacesAutoCompleteTextFormField calls addListener() on BOTH the
//   TextEditingController AND the FocusNode in its initState. If either has
//   been disposed before initState runs, you get the "used after disposed" crash.
//
//   Solution: _PlacesField (StatefulWidget) owns BOTH internally.
//   The parent passes only the initial text string and receives updates via
//   callbacks. No disposed object ever crosses a widget-mount boundary.
// =============================================================================

// ─────────────────────────────────────────────────────────────────────────────
// _PlacesField — owns its own controller + focus node
// ─────────────────────────────────────────────────────────────────────────────
class _PlacesField extends StatefulWidget {
  final String initialText;
  final String labelText;
  final String hintText;
  final VoidCallback? onFocusGained;
  final void Function(String text, Position position) onLocationSelected;

  const _PlacesField({
    super.key,
    required this.initialText,
    required this.labelText,
    required this.hintText,
    this.onFocusGained,
    required this.onLocationSelected,
  });

  @override
  State<_PlacesField> createState() => _PlacesFieldState();
}

class _PlacesFieldState extends State<_PlacesField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
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
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LocationSearchView — the overlay shown when a location field is tapped
// Stateless; all lifecycle is in child StatefulWidgets (_PlacesField).
// ─────────────────────────────────────────────────────────────────────────────
class _LocationSearchView extends StatelessWidget {
  final String pickupText;
  final String dropText;
  final List<Map<String, String>> recentSearches;
  final String? focusedField;

  final VoidCallback onDone;
  final void Function(String field) onFieldFocused;
  final void Function(String text, Position pos) onPickupSelected;
  final void Function(String text, Position pos) onDropSelected;
  final void Function(String city) onRecentSearch;

  const _LocationSearchView({
    super.key,
    required this.pickupText,
    required this.dropText,
    required this.recentSearches,
    required this.focusedField,
    required this.onDone,
    required this.onFieldFocused,
    required this.onPickupSelected,
    required this.onDropSelected,
    required this.onRecentSearch,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        height: MediaQuery.of(context).size.height,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // PICKUP
                _PlacesField(
                  initialText: pickupText,
                  labelText: 'Pickup City',
                  hintText: 'Eg. Mumbai',
                  onFocusGained: () => onFieldFocused('pickup'),
                  onLocationSelected: onPickupSelected,
                ),
                const SizedBox(height: 16),
                // DROP
                _PlacesField(
                  initialText: dropText,
                  labelText: 'Drop City',
                  hintText: 'Eg. Delhi',
                  onFocusGained: () => onFieldFocused('drop'),
                  onLocationSelected: onDropSelected,
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
                  child: SizedBox(
                    width: double.infinity,
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
// CreateOrderPage
// =============================================================================
class CreateOrderPage extends StatefulWidget {
  final VoidCallback? onOrderCreated;
  final VoidCallback? onReturnHome;

  const CreateOrderPage({
    Key? key,
    this.onOrderCreated,
    this.onReturnHome,
  }) : super(key: key);

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 3;

  final OrderService _orderService = OrderService();
  final ProfileService _profileService = ProfileService();

  // ── Date / Time controllers (safe — never passed to GooglePlaces) ─────────
  final TextEditingController pickupDateController = TextEditingController();
  final TextEditingController deliveryDateController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController packageTypeController = TextEditingController();
  final TextEditingController transportController = TextEditingController();
  final TextEditingController restrictionsController = TextEditingController();

  // ── Location: plain strings + positions only. NO controllers, NO nodes. ───
  String _pickupText = '';
  String _dropText = '';
  Position? originPosition;
  Position? destinationPosition;

  // ── Location overlay state ─────────────────────────────────────────────────
  bool _isLocationViewFocused = false;
  String? _focusedField;

  // ── Recent Searches ────────────────────────────────────────────────────────
  final List<Map<String, String>> _recentSearches = [
    {'city': 'Delhi', 'country': 'India'},
    {'city': 'Mumbai', 'country': 'India'},
    {'city': 'Bangalore', 'country': 'India'},
    {'city': 'Kolkata', 'country': 'India'},
  ];

  // ── Order fields ───────────────────────────────────────────────────────────
  DateTime? _pickupDateTime;
  DateTime? _deliveryDateTime;

  OrderMainCategory? _selectedMainCategory;
  String? _selectedWeightRange;
  List<String> _selectedTransportModes = [];
  bool _isUrgent = false;

  List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isCreatingOrder = false;

  // ── Success overlay ────────────────────────────────────────────────────────
  bool _showSuccessOverlay = false;
  String? _createdOrderId;

  // ── Auth ───────────────────────────────────────────────────────────────────
  String? userId;
  UserProfile? _userProfile;
  bool _isLoadingUser = true;

  final List<String> _transportModes = [
    'Car', 'Bike', 'Pickup Truck', 'Truck', 'Bus', 'Train', 'Plane',
  ];

  // ──────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  @override
  void dispose() {
    _pageController.dispose();
    pickupDateController.dispose();
    deliveryDateController.dispose();
    weightController.dispose();
    packageTypeController.dispose();
    transportController.dispose();
    restrictionsController.dispose();
    // No location controllers/nodes to dispose — they live inside _PlacesField.
    super.dispose();
  }

  Future<void> _initializeUser() async {
    try {
      final fetchedUserId = await AuthService.getUserId();
      if (fetchedUserId == null) {
        if (mounted) {
          FloatingNotification.show(context,
              isSuccess: false,
              title: 'Auth Error',
              subtitle: 'Please log in to create orders');
          if (Navigator.canPop(context)) Navigator.of(context).pop();
        }
        return;
      }
      final profile = await _profileService.getUserProfile(fetchedUserId);
      setState(() {
        userId = fetchedUserId;
        _userProfile = profile;
        _isLoadingUser = false;
      });
    } catch (e) {
      setState(() => _isLoadingUser = false);
      if (mounted) {
        FloatingNotification.show(context,
            isSuccess: false,
            title: 'Load Error',
            subtitle: 'Error loading user data: $e');
      }
    }
  }

  // ── Location overlay control ───────────────────────────────────────────────

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

  void _onRecentSearch(String city) {
    setState(() {
      if (_focusedField == 'pickup') {
        _pickupText = city;
      } else if (_focusedField == 'drop') {
        _dropText = city;
      }
    });
  }

  // ── Step navigation ────────────────────────────────────────────────────────

  void _nextStep() {
    if (_currentStep < _totalSteps - 1 && _validateCurrentStep()) {
      setState(() => _currentStep++);
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_pickupText.trim().isEmpty) {
          FloatingNotification.show(context,
              isSuccess: false,
              title: 'Required',
              subtitle: 'Please enter pickup city');
          return false;
        }
        if (_dropText.trim().isEmpty) {
          FloatingNotification.show(context,
              isSuccess: false,
              title: 'Required',
              subtitle: 'Please enter drop city');
          return false;
        }
        if (_pickupDateTime == null) {
          FloatingNotification.show(context,
              isSuccess: false,
              title: 'Required',
              subtitle: 'Please select pickup date & time');
          return false;
        }
        if (_deliveryDateTime == null) {
          FloatingNotification.show(context,
              isSuccess: false,
              title: 'Required',
              subtitle: 'Please select delivery date & time');
          return false;
        }
        if (_deliveryDateTime!.isBefore(_pickupDateTime!)) {
          FloatingNotification.show(context,
              isSuccess: false,
              title: 'Date Error',
              subtitle: 'Delivery date cannot be before pickup date');
          return false;
        }
        return true;
      case 1:
        if (_selectedWeightRange == null) {
          FloatingNotification.show(context,
              isSuccess: false,
              title: 'Required',
              subtitle: 'Please select package weight');
          return false;
        }
        if (_selectedMainCategory == null) {
          FloatingNotification.show(context,
              isSuccess: false,
              title: 'Required',
              subtitle: 'Please select package type');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  bool _validateAllFields() {
    if (_pickupText.trim().isEmpty ||
        _dropText.trim().isEmpty ||
        _pickupDateTime == null ||
        _deliveryDateTime == null ||
        _selectedWeightRange == null ||
        _selectedMainCategory == null) {
      FloatingNotification.show(context,
          isSuccess: false,
          title: 'Validation',
          subtitle: 'Please fill all required fields');
      return false;
    }
    if (_deliveryDateTime!.isBefore(_pickupDateTime!)) {
      FloatingNotification.show(context,
          isSuccess: false,
          title: 'Date Error',
          subtitle: 'Delivery date cannot be before pickup date');
      return false;
    }
    return true;
  }

  // ── Order creation ─────────────────────────────────────────────────────────

  Future<void> _createOrder() async {
    if (userId == null) {
      FloatingNotification.show(context,
          isSuccess: false,
          title: 'Auth Error',
          subtitle: 'User ID not found. Please log in again.');
      return;
    }
    if (!_validateAllFields()) return;

    try {
      setState(() => _isCreatingOrder = true);

      final orderRequest = OrderCreateRequest(
        userHashedId: userId!,
        itemDescription: _selectedMainCategory!.name,
        origin: _pickupText.trim(),
        originLatitude: originPosition?.latitude ?? 0.0,
        originLongitude: originPosition?.longitude ?? 0.0,
        destination: _dropText.trim(),
        destinationLatitude: destinationPosition?.latitude ?? 0.0,
        destinationLongitude: destinationPosition?.longitude ?? 0.0,
        pickupDate: _formatDateForApi(_pickupDateTime!),
        pickupTime: _formatTimeForApi(_pickupDateTime!),
        deliveryDate: _formatDateForApi(_deliveryDateTime!),
        deliveryTime: _formatTimeForApi(_deliveryDateTime!),
        weight: _getWeightStringForApi(_selectedWeightRange!),
        actualWeight: null,
        category: _selectedMainCategory!.apiValue,
        customCategory: null,
        preferenceTransport:
        _selectedTransportModes.isNotEmpty ? _selectedTransportModes : null,
        isUrgent: _isUrgent,
        images: _selectedImages,
        specialInstructions: restrictionsController.text.trim().isEmpty
            ? null
            : restrictionsController.text.trim(),
      );

      final response = await _orderService.createOrder(orderRequest);

      if (response != null) {
        _clearAllFields();
        setState(() {
          _currentStep = 0;
          _isCreatingOrder = false;
          _createdOrderId = response.orderId;
          _showSuccessOverlay = true;
        });
        _pageController.jumpToPage(0);
      } else {
        setState(() => _isCreatingOrder = false);
        _showKycRequiredDialog();
      }
    } catch (e) {
      setState(() => _isCreatingOrder = false);
      if (e.toString().contains('KYC') || e.toString().contains('403')) {
        _showKycRequiredDialog();
      } else {
        FloatingNotification.show(context,
            isSuccess: false,
            title: 'Order Failed',
            subtitle: e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  String _getWeightStringForApi(String range) {
    switch (range) {
      case 'Below 2 kg':
        return 'below 2kg';
      case '2–5 kg':
        return '2-5kg';
      case '5–10 kg':
        return '5-10kg';
      case 'More than 10 kg':
        return 'more than 10kg';
      default:
        return '5-10kg';
    }
  }

  String _formatDateForApi(DateTime dt) =>
      "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";

  String _formatTimeForApi(DateTime dt) =>
      "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:00";

  void _clearAllFields() {
    pickupDateController.clear();
    deliveryDateController.clear();
    weightController.clear();
    packageTypeController.clear();
    transportController.clear();
    restrictionsController.clear();
    setState(() {
      _pickupText = '';
      _dropText = '';
      _selectedImages.clear();
      originPosition = null;
      destinationPosition = null;
      _pickupDateTime = null;
      _deliveryDateTime = null;
      _selectedMainCategory = null;
      _selectedWeightRange = null;
      _selectedTransportModes = [];
      _isUrgent = false;
    });
  }

  void _showKycRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('KYC Verification Required'),
        content: const Text(
            'To create orders, you need to complete your KYC verification.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Later')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _navigateToKycScreen();
            },
            child: const Text('Complete KYC'),
          ),
        ],
      ),
    );
  }

  void _navigateToKycScreen() async {
    if (userId == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KycUploadScreen(
          userId: userId!,
          fullName: _userProfile?.name,
          email: _userProfile?.email,
          phone: _userProfile?.phone != null
              ? '+91 ${_userProfile?.phone}'
              : null,
        ),
      ),
    );
    if (result == true) {
      FloatingNotification.show(context,
          isSuccess: true,
          title: 'KYC Success',
          subtitle: 'KYC document uploaded successfully!');
    }
  }

  Future<void> _selectDateTime(
      TextEditingController controller, bool isPickup) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      final time =
      await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) {
        final dt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
        setState(() {
          if (isPickup) {
            _pickupDateTime = dt;
          } else {
            _deliveryDateTime = dt;
          }
          controller.text =
          '${date.day}/${date.month}/${date.year} · ${time.format(context)}';
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera)),
            ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
          ],
        ),
      ),
    );
    if (source != null) {
      try {
        if (source == ImageSource.gallery) {
          final images = await _picker.pickMultiImage();
          if (images.isNotEmpty) {
            setState(() =>
                _selectedImages.addAll(images.map((img) => File(img.path))));
          }
        } else {
          final image = await _picker.pickImage(source: source);
          if (image != null) {
            setState(() => _selectedImages.add(File(image.path)));
          }
        }
      } catch (e) {
        FloatingNotification.show(context,
            isSuccess: false,
            title: 'Image Error',
            subtitle: 'Error picking image: $e');
      }
    }
  }

  // ── Success overlay ────────────────────────────────────────────────────────

  Widget _buildSuccessOverlay() {
    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: _showSuccessOverlay ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          color: Colors.black.withOpacity(0.55),
          child: Center(
            child: _OrderSuccessCard(
              orderId: _createdOrderId,
              onTrackOrder: () {
                setState(() => _showSuccessOverlay = false);
                widget.onOrderCreated?.call();
                if (Navigator.canPop(context)) Navigator.of(context).pop();
              },
              onReturnHome: () {
                setState(() => _showSuccessOverlay = false);
                widget.onReturnHome?.call();
                if (Navigator.canPop(context)) Navigator.of(context).pop();
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (userId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('User not found'),
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back')),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_isLocationViewFocused,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_isLocationViewFocused) _hideLocationView();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              if (_isLocationViewFocused) {
                _hideLocationView();
              } else if (_currentStep > 0) {
                _previousStep();
              } else if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: const Text('Create Order',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          centerTitle: false,
        ),
        body: Stack(
          children: [
            // ── Main multi-step form ─────────────────────────────────────────
            AnimatedOpacity(
              opacity: _isLocationViewFocused ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: _isLocationViewFocused,
                child: Column(
                  children: [
                    // Step header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_getStepTitle(),
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: (_currentStep + 1) / _totalSteps,
                                  backgroundColor:
                                  Theme.of(context).colorScheme.surface,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.primary),
                                  minHeight: 4,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${(_currentStep + 1).toString().padLeft(2, '0')} / ${_totalSteps.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Page content
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildTripDetailsPage(),
                          _buildPackageDetailsPage(),
                          _buildAdditionalDetailsPage(),
                        ],
                      ),
                    ),
                    // Bottom button
                    SafeArea(
                      child: Container(
                        padding:
                        const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        margin: const EdgeInsets.only(bottom: 30),
                        decoration: BoxDecoration(
                          color:
                          Theme.of(context).scaffoldBackgroundColor,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, -2))
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isCreatingOrder
                                ? null
                                : (_currentStep == _totalSteps - 1
                                ? _createOrder
                                : _nextStep),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              Theme.of(context).colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: _isCreatingOrder
                                ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                                : Text(
                                _currentStep == _totalSteps - 1
                                    ? 'POST'
                                    : 'NEXT',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Location search overlay ──────────────────────────────────────
            // Mounts fresh each time → _PlacesField creates new
            // controller+focusNode on mount, disposes on unmount.
            // No stale/disposed objects ever reach GooglePlaces.
            if (_isLocationViewFocused)
              _LocationSearchView(
                pickupText: _pickupText,
                dropText: _dropText,
                recentSearches: _recentSearches,
                focusedField: _focusedField,
                onDone: _hideLocationView,
                onFieldFocused: (f) => setState(() => _focusedField = f),
                onPickupSelected: (text, pos) => setState(() {
                  _pickupText = text;
                  originPosition = pos;
                }),
                onDropSelected: (text, pos) => setState(() {
                  _dropText = text;
                  destinationPosition = pos;
                }),
                onRecentSearch: _onRecentSearch,
              ),

            // ── Success overlay ──────────────────────────────────────────────
            if (_showSuccessOverlay) _buildSuccessOverlay(),
          ],
        ),
      ),
    );
  }

  // ── Step title ─────────────────────────────────────────────────────────────

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Trip Details';
      case 1:
        return 'Package Details';
      case 2:
        return 'Additional Details';
      default:
        return 'Create Order';
    }
  }

  // ── Page: Trip Details ─────────────────────────────────────────────────────
  // Location fields are now read-only tappable tiles that open the overlay.

  Widget _buildTripDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pickup city — tappable read-only tile
          _buildReadOnlyLocationField(
            label: 'Pickup City',
            value: _pickupText,
            hint: 'Tap to enter pickup city',
            onTap: () => _showLocationView('pickup'),
          ),
          const SizedBox(height: 20),
          // Drop city — tappable read-only tile
          _buildReadOnlyLocationField(
            label: 'Drop City',
            value: _dropText,
            hint: 'Tap to enter drop city',
            onTap: () => _showLocationView('drop'),
          ),
          const SizedBox(height: 20),
          _buildInputField(
              label: 'Pick-up Date & Time',
              controller: pickupDateController,
              hint: 'dd/mm/yyyy · HH:MM',
              icon: Icons.calendar_today,
              readOnly: true,
              onTap: () => _selectDateTime(pickupDateController, true)),
          const SizedBox(height: 20),
          _buildInputField(
              label: 'Delivery Date & Time',
              controller: deliveryDateController,
              hint: 'dd/mm/yyyy · HH:MM',
              icon: Icons.calendar_today,
              readOnly: true,
              onTap: () => _selectDateTime(deliveryDateController, false)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _isUrgent,
                  onChanged: (value) =>
                      setState(() => _isUrgent = value ?? false),
                  activeColor: Colors.grey[800],
                ),
                Expanded(
                  child: Text(
                    'Mark this order as urgent (additional charges may apply)',
                    style:
                    TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Read-only location tile (mirrors SendPage's _buildReadOnlyField) ───────

  Widget _buildReadOnlyLocationField({
    required String label,
    required String value,
    required String hint,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 20, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value.isEmpty ? hint : value,
                    style: TextStyle(
                      fontSize: 14,
                      color: value.isEmpty
                          ? Colors.grey[400]
                          : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Page: Package Details ──────────────────────────────────────────────────

  Widget _buildPackageDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropdownField(
              label: 'Package Weight (kg)',
              hint: 'Eg. Below 2 kg',
              icon: Icons.scale,
              value: _selectedWeightRange,
              items: ['Below 2 kg', '2–5 kg', '5–10 kg', 'More than 10 kg'],
              onChanged: (value) =>
                  setState(() => _selectedWeightRange = value)),
          const SizedBox(height: 20),
          _buildCategoryDropdown(),
          const SizedBox(height: 20),
          _buildDropdownField(
              label: 'Preferred Transport',
              hint: 'Eg. Car',
              icon: Icons.directions_car,
              value: _selectedTransportModes.isNotEmpty
                  ? _selectedTransportModes.first
                  : null,
              items: _transportModes,
              onChanged: (value) => setState(() =>
              _selectedTransportModes = value != null ? [value] : [])),
        ],
      ),
    );
  }

  // ── Page: Additional Details ───────────────────────────────────────────────

  Widget _buildAdditionalDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Package Photo',
              style:
              TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 1.5),
              ),
              child: _selectedImages.isEmpty
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.add_photo_alternate_outlined,
                        size: 28, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 12),
                  const Text('Upload File',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  Text('Tap to add photo',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500])),
                ],
              )
                  : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8),
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_selectedImages[index],
                      fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildInputField(
              label: 'Remarks',
              controller: restrictionsController,
              hint: 'take parcel carefully',
              icon: Icons.info_outline,
              maxLines: 3),
        ],
      ),
    );
  }

  // ── Shared input widgets ───────────────────────────────────────────────────

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
            TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon:
            Icon(icon, size: 20, color: Colors.grey[600]),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                BorderSide(color: Theme.of(context).dividerColor)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                BorderSide(color: Theme.of(context).dividerColor)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String hint,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          hint: Row(children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Text(hint,
                style:
                TextStyle(color: Colors.grey[400], fontSize: 14)),
          ]),
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                BorderSide(color: Theme.of(context).dividerColor)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                BorderSide(color: Theme.of(context).dividerColor)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
          items: items
              .map((item) => DropdownMenuItem(
              value: item,
              child: Text(item,
                  style: const TextStyle(fontSize: 14))))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Package Type',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<OrderMainCategory>(
          value: _selectedMainCategory,
          hint: Row(children: [
            Icon(Icons.category, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Text('Eg. Furniture',
                style:
                TextStyle(color: Colors.grey[400], fontSize: 14)),
          ]),
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                BorderSide(color: Theme.of(context).dividerColor)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                BorderSide(color: Theme.of(context).dividerColor)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
          items: orderCategories
              .map((category) => DropdownMenuItem(
              value: category,
              child: Text(category.name,
                  style: const TextStyle(fontSize: 14))))
              .toList(),
          onChanged: (value) =>
              setState(() => _selectedMainCategory = value),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  _OrderSuccessCard
// ════════════════════════════════════════════════════════════════════════════
class _OrderSuccessCard extends StatefulWidget {
  final String? orderId;
  final VoidCallback onTrackOrder;
  final VoidCallback onReturnHome;

  const _OrderSuccessCard({
    required this.orderId,
    required this.onTrackOrder,
    required this.onReturnHome,
  });

  @override
  State<_OrderSuccessCard> createState() => _OrderSuccessCardState();
}

class _OrderSuccessCardState extends State<_OrderSuccessCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding:
          const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: Color(0xFF5C5C5C),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 52),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Order is successfully\npublished',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                  height: 1.35,
                ),
              ),
              if (widget.orderId != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Order #${widget.orderId}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onTrackOrder,
                      style: OutlinedButton.styleFrom(
                        padding:
                        const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Track Your Order',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onReturnHome,
                      style: OutlinedButton.styleFrom(
                        padding:
                        const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Return to Home',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}