// Save this as: Pages/CreateOrderPage.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import '../../Controllers/OrderService.dart';
import '../../Controllers/AuthService.dart';
import '../LocationinputField.dart';
import '../../Constants/colorconstant.dart';
import '../../Models/OrderModel.dart';
import '../LoginScreens/kyc_screen.dart';
import '../../Widgets/ModernInputField.dart';

class CreateOrderPage extends StatefulWidget {
  final VoidCallback? onOrderCreated;
  const CreateOrderPage({Key? key, this.onOrderCreated}) : super(key: key);

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 6;

  final OrderService _orderService = OrderService();

  final TextEditingController originController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController timeController =
      TextEditingController(); // New time controller
  final TextEditingController weightController = TextEditingController();
  final TextEditingController actualWeightController =
      TextEditingController(); // For "more than 10kg"
  final TextEditingController specialInstructionsController =
      TextEditingController();
  final TextEditingController customCategoryController =
      TextEditingController(); // For "other" category

  Position? originPosition;
  Position? destinationPosition;

  OrderMainCategory? _selectedMainCategory;
  String? _selectedWeightRange;

  List<String> _selectedTransportModes = []; // preference_transport
  bool _isUrgent = false; // is_urgent flag

  List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isCreatingOrder = false;

  String? userId;
  bool _isLoadingUser = true;

  // Available transport modes
  final List<String> _transportModes = [
    'Car',
    'Bike',
    'Pickup Truck',
    'Truck',
    'Bus',
    'Train',
    'Plane',
  ];

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    try {
      final fetchedUserId = await AuthService.getUserId();
      if (fetchedUserId == null) {
        print('❌ No user ID found in AuthService');
        if (mounted) {
          _showSnackBar('Please log in to create orders', Colors.red);
          Navigator.of(context).pop();
        }
        return;
      }

      setState(() {
        userId = fetchedUserId;
        _isLoadingUser = false;
      });
      print('✅ User ID loaded from AuthService: $userId');
    } catch (e) {
      print('❌ Error initializing user: $e');
      setState(() {
        _isLoadingUser = false;
      });
      if (mounted) {
        _showSnackBar('Error loading user data: $e', Colors.red);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    originController.dispose();
    destinationController.dispose();
    dateController.dispose();
    timeController.dispose();
    weightController.dispose();
    actualWeightController.dispose();
    specialInstructionsController.dispose();
    customCategoryController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  String _getWeightStringForApi(String range) {
    switch (range) {
      case 'Below 2 kg':
        return 'below 2kg'; // API format
      case '2–5 kg':
        return '2-5kg'; // API format
      case '5–10 kg':
        return '5-10kg'; // API format
      case 'More than 10 kg':
        return 'more than 10kg'; // API format
      default:
        return '5-10kg'; // Default fallback
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (originController.text.trim().isEmpty) {
          _showSnackBar('Please enter origin location', Colors.orange);
          return false;
        }
        if (originPosition == null) {
          _showSnackBar(
              'Please get coordinates for origin location', Colors.orange);
          return false;
        }
        return true;
      case 1:
        if (destinationController.text.trim().isEmpty) {
          _showSnackBar('Please enter destination location', Colors.orange);
          return false;
        }
        if (destinationPosition == null) {
          _showSnackBar(
              'Please get coordinates for destination location', Colors.orange);
          return false;
        }
        return true;
      case 2:
        if (dateController.text.trim().isEmpty) {
          _showSnackBar('Please select delivery date', Colors.orange);
          return false;
        }
        return true;
      case 3:
        if (_selectedWeightRange == null) {
          _showSnackBar('Please select weight range', Colors.orange);
          return false;
        }
        return true;
      case 4:
        if (_selectedMainCategory == null) {
          _showSnackBar('Please select a category', Colors.orange);
          return false;
        }
        // Check if custom category is required and provided
        if (_selectedMainCategory!.apiValue == 'other' &&
            customCategoryController.text.trim().isEmpty) {
          _showSnackBar('Please enter a custom category', Colors.orange);
          return false;
        }
        return true;
      case 5:
        return true;
      default:
        return true;
    }
  }

  Future<void> _createOrder() async {
    if (userId == null) {
      _showSnackBar('User ID not found. Please log in again.', Colors.red);
      return;
    }

    if (!_validateAllFields()) return;

    try {
      setState(() {
        _isCreatingOrder = true;
      });

      // ✅ NEW: Use API value for category only
      String apiCategory = _selectedMainCategory!
          .apiValue; // e.g., 'technology', 'documents', 'fragile'

      print('DEBUG: Starting order creation process');
      print('DEBUG: Category (API): $apiCategory');
      print('DEBUG: Display Category: ${_selectedMainCategory!.name}');
      print('DEBUG: Weight Range: $_selectedWeightRange');
      print('DEBUG: Uploading ${_selectedImages.length} images');

      // Get weight string for API
      String weightString = _getWeightStringForApi(_selectedWeightRange!);

      // Get actual weight if "more than 10kg"
      double? actualWeight;
      if (weightString == 'more than 10kg' &&
          actualWeightController.text.trim().isNotEmpty) {
        actualWeight = double.tryParse(actualWeightController.text.trim());
      }

      // Get custom category if category is "other"
      String? customCategory;
      if (apiCategory == 'other' &&
          customCategoryController.text.trim().isNotEmpty) {
        customCategory = customCategoryController.text.trim();
      }

      // Default time if not provided
      String deliveryTime = timeController.text.trim().isEmpty
          ? '12:00:00'
          : timeController.text.trim();

      final orderRequest = OrderCreateRequest(
        userHashedId: userId!,
        origin: originController.text.trim(),
        originLatitude: originPosition!.latitude,
        originLongitude: originPosition!.longitude,
        destination: destinationController.text.trim(),
        destinationLatitude: destinationPosition!.latitude,
        destinationLongitude: destinationPosition!.longitude,
        deliveryDate: _formatDateForApi(dateController.text.trim()),
        deliveryTime: deliveryTime, // Required time field
        weight:
            weightString, // String value: "less than 5kg", "5-10kg", "more than 10kg"
        actualWeight:
            actualWeight, // Optional, required if weight is "more than 10kg"
        category:
            apiCategory, // fragile, technology, documents, food, clothing, other
        customCategory:
            customCategory, // Optional, required if category is "other"
        preferenceTransport: _selectedTransportModes.isNotEmpty
            ? _selectedTransportModes
            : null, // Optional transport preferences
        isUrgent: _isUrgent, // Urgent flag
        images: _selectedImages,
        specialInstructions: specialInstructionsController.text.trim().isEmpty
            ? null
            : specialInstructionsController.text.trim(),
      );

      print('DEBUG: Order request prepared');
      print('DEBUG: API Category: $apiCategory');
      print('DEBUG: Weight Range: $_selectedWeightRange');

      final response = await _orderService.createOrder(orderRequest);

      if (response != null) {
        print('DEBUG: Order created successfully!');
        print('DEBUG: Message: ${response.message}');
        print('DEBUG: Order ID: ${response.orderId}');

        if (response.imageUrls != null && response.imageUrls!.isNotEmpty) {
          print(
              'DEBUG: ✅ ${response.imageUrls!.length} image(s) uploaded successfully');
        }

        _clearAllFields();

        setState(() {
          _currentStep = 0;
          _isCreatingOrder = false;
        });
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );

        String successMessage = 'Order ID: #${response.orderId}';
        if (response.imageUrls != null && response.imageUrls!.isNotEmpty) {
          successMessage +=
              '\n📸 ${response.imageUrls!.length} image(s) uploaded';
        }

        _showSuccessToast(successMessage);

        widget.onOrderCreated?.call();
      } else {
        setState(() {
          _isCreatingOrder = false;
        });
        _showKycRequiredDialog();
      }
    } catch (e, stackTrace) {
      setState(() {
        _isCreatingOrder = false;
      });
      print('DEBUG: Error creating order: $e');
      print('DEBUG: Stack trace: $stackTrace');

      if (e.toString().contains('KYC') || e.toString().contains('403')) {
        _showKycRequiredDialog();
      } else {
        _showSnackBar(
            'Failed to create order: ${e.toString().replaceAll('Exception: ', '')}',
            Colors.red);
      }
    }
  }

  void _showKycRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.verified_user,
                color: Colors.orange[700],
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'KYC Verification Required',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To create orders, you need to complete your KYC verification.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This is required for security and compliance purposes.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Later',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _navigateToKycScreen();
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Complete KYC'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF001127),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToKycScreen() async {
    if (userId == null) {
      _showSnackBar('User ID not found. Please log in again.', Colors.red);
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KycUploadScreen(
          userId: userId!,
        ),
      ),
    );

    if (result == true) {
      _showSnackBar(
        'KYC document uploaded successfully! You can now create orders.',
        Colors.green,
      );
    }
  }

  String _formatDateForApi(String dateString) {
    try {
      final parts = dateString.split('/');
      if (parts.length == 3) {
        return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
      }
    } catch (e) {
      print('Error formatting date: $e');
    }
    return dateString;
  }

  void _showSuccessToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '✅ Order Created Successfully!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      message,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'VIEW ORDERS',
          textColor: Colors.white,
          backgroundColor: Colors.white24,
          onPressed: () {
            widget.onOrderCreated?.call();
          },
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Add Package Photos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can add multiple photos',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _getImage(ImageSource.camera);
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _getImages(ImageSource.gallery);
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          foregroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImages.add(File(image.path));
        });
        _showSnackBar(
            'Image added (${_selectedImages.length} total)', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', Colors.red);
    }
  }

  Future<void> _getImages(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> images = await _picker.pickMultiImage(
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );

        if (images.isNotEmpty) {
          setState(() {
            _selectedImages.addAll(images.map((img) => File(img.path)));
          });
          _showSnackBar(
              '${images.length} images added (${_selectedImages.length} total)',
              Colors.green);
        }
      } else {
        await _getImage(source);
      }
    } catch (e) {
      _showSnackBar('Error picking images: $e', Colors.red);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
    _showSnackBar('Image removed', Colors.orange);
  }

  bool _validateAllFields() {
    if (originController.text.trim().isEmpty ||
        destinationController.text.trim().isEmpty ||
        dateController.text.trim().isEmpty ||
        _selectedWeightRange == null ||
        _selectedMainCategory == null) {
      _showSnackBar('Please fill all required fields', Colors.red);
      return false;
    }

    if (originPosition == null || destinationPosition == null) {
      _showSnackBar(
          'Please ensure both origin and destination coordinates are set',
          Colors.red);
      return false;
    }

    return true;
  }

  void _clearAllFields() {
    originController.clear();
    destinationController.clear();
    dateController.clear();
    specialInstructionsController.clear();
    setState(() {
      _selectedImages.clear();
      originPosition = null;
      destinationPosition = null;
      _selectedMainCategory = null;
      _selectedWeightRange = null;
    });
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        dateController.text = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        // Format time as HH:mm:ss
        final hour = picked.hour.toString().padLeft(2, '0');
        final minute = picked.minute.toString().padLeft(2, '0');
        timeController.text = '$hour:$minute:00';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Loading user data...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (userId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                'User not found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please log in to create orders',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentStep = index;
                });
              },
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
                _buildStep5(),
                _buildStep6(),
              ],
            ),

            // Floating Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildFloatingHeader(),
            ),

            // Floating Navigation Buttons
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildFloatingNavigation(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            GestureDetector(
              onTap: _previousStep,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStepTitle(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: List.generate(_totalSteps, (index) {
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 3,
                              decoration: BoxDecoration(
                                color: index <= _currentStep
                                    ? AppColors.primary
                                    : Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_currentStep + 1}/$_totalSteps',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Pickup Location';
      case 1:
        return 'Delivery Location';
      case 2:
        return 'Delivery Date';
      case 3:
        return 'Package Weight';
      case 4:
        return 'Package Category';
      case 5:
        return 'Additional Details';
      default:
        return 'Create Order';
    }
  }

  Widget _buildFloatingNavigation() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AppColors.primary, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Back',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep == 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: _currentStep == _totalSteps - 1
                  ? _createOrder
                  : () {
                      if (_validateCurrentStep()) {
                        _nextStep();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isCreatingOrder
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentStep == _totalSteps - 1
                              ? 'Create Order'
                              : 'Continue',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepPage({
    required String emoji,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 100, bottom: 100, left: 16, right: 16),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return _buildStepPage(
      emoji: '📍',
      title: 'Pickup Location',
      subtitle: 'Where should we collect the package?',
      child: Column(
        children: [
          EnhancedLocationInputField(
            controller: originController,
            label: 'Origin Address',
            hint: 'Tap to search location',
            icon: Icons.my_location,
            isOrigin: true,
            onLocationSelected: (position) {
              setState(() {
                originPosition = position;
              });
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tap the field above to search for your pickup location or use current location.',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return _buildStepPage(
      emoji: '🎯',
      title: 'Delivery Location',
      subtitle: 'Where should the package be delivered?',
      child: Column(
        children: [
          EnhancedLocationInputField(
            controller: destinationController,
            label: 'Destination Address',
            hint: 'Tap to search location',
            icon: Icons.place,
            isOrigin: false,
            onLocationSelected: (position) {
              setState(() {
                destinationPosition = position;
              });
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.local_shipping, color: Colors.green[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Make sure the delivery address is complete and accurate.',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return _buildStepPage(
      emoji: '📅',
      title: 'Delivery Date & Time',
      subtitle: 'When do you need this delivered?',
      child: Column(
        children: [
          _buildStepInputField(
            controller: dateController,
            icon: Icons.calendar_today,
            label: 'Delivery Date',
            hint: 'Select delivery date',
            helperText: 'Choose your preferred delivery date',
            readOnly: true,
            onTap: () => _selectDate(context),
          ),
          const SizedBox(height: 16),
          _buildStepInputField(
            controller: timeController,
            icon: Icons.access_time,
            label: 'Delivery Time',
            hint: 'Select delivery time',
            helperText: 'Choose your preferred delivery time',
            readOnly: true,
            onTap: () => _selectTime(context),
          ),
          const SizedBox(height: 20),

          // Urgent delivery checkbox
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isUrgent ? Colors.red[50] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _isUrgent ? Colors.red[200]! : Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _isUrgent,
                  onChanged: (value) {
                    setState(() {
                      _isUrgent = value ?? false;
                    });
                  },
                  activeColor: Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_fire_department,
                              color: _isUrgent
                                  ? Colors.red[700]
                                  : Colors.grey[600],
                              size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Urgent Delivery',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color:
                                  _isUrgent ? Colors.red[700] : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mark this order as urgent for priority handling',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isUrgent ? Colors.red[600] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Date format: DD/MM/YYYY (e.g., 30/09/2025)',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build weight range dropdown selector
  Widget _buildWeightRangeSelector() {
    final weightRanges = [
      'Below 2 kg',
      '2–5 kg',
      '5–10 kg',
      'More than 10 kg',
    ];

    final weightIcons = {
      'Below 2 kg': Icons.inventory_2_outlined,
      '2–5 kg': Icons.inventory_2,
      '5–10 kg': Icons.move_to_inbox,
      'More than 10 kg': Icons.all_inbox,
    };

    final weightColors = {
      'Below 2 kg': Colors.green,
      '2–5 kg': Colors.blue,
      '5–10 kg': Colors.orange,
      'More than 10 kg': Colors.red,
    };

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
        value: _selectedWeightRange,
        hint: Row(
          children: [
            Icon(Icons.scale, color: Colors.grey[400], size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Select package weight',
                style: TextStyle(color: Colors.grey, fontSize: 16),
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
          return weightRanges.map<Widget>((weight) {
            return Row(
              children: [
                Icon(weightIcons[weight]!, color: weightColors[weight]!, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    weight,
                    style: const TextStyle(
                      fontSize: 16,
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
        items: weightRanges.map((weight) {
          return DropdownMenuItem<String>(
            value: weight,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: weightColors[weight]!.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      weightIcons[weight]!,
                      color: weightColors[weight]!,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      weight,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedWeightRange = newValue;
          });
        },
      ),
    );
  }

  Widget _buildStep4() {
    return _buildStepPage(
      emoji: '⚖️',
      title: 'Package Weight & Transport',
      subtitle: 'Select the weight range and preferred transport modes',
      child: Column(
        children: [
          _buildWeightRangeSelector(),
          const SizedBox(height: 24),

          // Transport Preference Section
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.directions_car,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Preferred Vehicle (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Select your preferred transport mode',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Transport dropdown
          Container(
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
              value: _selectedTransportModes.isNotEmpty
                  ? _selectedTransportModes.first
                  : null,
              hint: Row(
                children: [
                  Icon(Icons.directions_car, color: Colors.grey[400], size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Select preferred vehicle',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 17),
              ),
              icon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              ),
              isExpanded: true,
              menuMaxHeight: 400,
              selectedItemBuilder: (BuildContext context) {
                return _transportModes.map<Widget>((mode) {
                  IconData icon;
                  switch (mode) {
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
                      Icon(icon, color: AppColors.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          mode,
                          style: const TextStyle(
                            fontSize: 16,
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
              items: _transportModes.map((mode) {
                IconData icon;
                switch (mode) {
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
                  value: mode,
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
                            mode,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  if (newValue != null) {
                    _selectedTransportModes = [newValue];
                  } else {
                    _selectedTransportModes = [];
                  }
                });
              },
            ),
          ),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.purple[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Select the weight range that best matches your package. Transport preference helps match you with suitable travelers.',
                    style: TextStyle(
                      color: Colors.purple[700],
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep5() {
    return _buildStepPage(
      emoji: '📦',
      title: 'Package Category',
      subtitle: 'Select the category of your package',
      child: Column(
        children: [
          Container(
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
            child: DropdownButtonFormField<OrderMainCategory>(
              value: _selectedMainCategory,
              hint: Row(
                children: [
                  Icon(Icons.category, color: Colors.grey[400], size: 22),
                  const SizedBox(width: 12),
                  const Text(
                    'Select category',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 17),
              ),
              icon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              ),
              isExpanded: true,
              menuMaxHeight: 400,
              itemHeight: null,
              selectedItemBuilder: (BuildContext context) {
                return orderCategories.map<Widget>((category) {
                  return Row(
                    children: [
                      const SizedBox(width: 4),
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
              items: orderCategories.map((category) {
                return DropdownMenuItem<OrderMainCategory>(
                  value: category,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: category.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(category.icon,
                                style: const TextStyle(fontSize: 20)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            category.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (OrderMainCategory? newValue) {
                setState(() {
                  _selectedMainCategory = newValue;
                  // Clear custom category if not selecting "other"
                  if (newValue?.apiValue != 'other') {
                    customCategoryController.clear();
                  }
                });
              },
            ),
          ),
          const SizedBox(height: 24),
          if (_selectedMainCategory != null)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _selectedMainCategory!.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedMainCategory!.color.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: _selectedMainCategory!.color,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        _selectedMainCategory!.icon,
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Category',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedMainCategory!.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _selectedMainCategory!.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedMainCategory!.color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          // Custom category input field (shown only when category is "other")
          if (_selectedMainCategory != null &&
              _selectedMainCategory!.apiValue == 'other')
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange[700], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Please specify the category of your item',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange[900],
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildStepInputField(
                  controller: customCategoryController,
                  icon: Icons.label,
                  label: 'Custom Category',
                  hint: 'Enter category name (e.g., Books, Toys, etc.)',
                ),
                const SizedBox(height: 24),
              ],
            ),
          if (_selectedMainCategory == null ||
              _selectedMainCategory!.apiValue != 'other')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select the category that best describes the type of package you\'re sending.',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep6() {
    return _buildStepPage(
      emoji: '📸',
      title: 'Additional Details',
      subtitle: 'Add images and special instructions (optional)',
      child: Column(
        children: [
          if (_selectedImages.isEmpty)
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.grey[300]!,
                      width: 2,
                      style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add Package Photos',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to add photos (Optional)',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_selectedImages.length} image(s) selected',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _selectedImages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _selectedImages.length) {
                      return GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.grey[300]!,
                                width: 2,
                                style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add,
                                  color: Colors.grey[400], size: 32),
                              const SizedBox(height: 4),
                              Text(
                                'Add More',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedImages[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          const SizedBox(height: 24),
          _buildStepInputField(
            controller: specialInstructionsController,
            icon: Icons.note,
            label: 'Special Instructions (Optional)',
            hint: 'Any special handling instructions?',
            helperText: 'Fragile items, time preferences, etc.',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildStepInputField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String hint,
    String? helperText,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernInputField(
          controller: controller,
          label: label,
          hint: hint,
          prefixIcon: icon,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          maxLines: maxLines,
          showClearButton: !readOnly,
        ),
        if (helperText != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              helperText,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
