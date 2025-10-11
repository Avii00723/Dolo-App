import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import '../../Controllers/OrderService.dart';
import '../../Controllers/AuthService.dart';
import '../LocationinputField.dart';
import '../LoginScreens/UserProfileHelper.dart';
import '../../Constants/colorconstant.dart';
import '../../Services/LocationService.dart';
import '../../Models/OrderModel.dart';
import '../LoginScreens/kyc_screen.dart';
import '../LoginScreens/signup_page.dart';

class CreateOrderPage extends StatefulWidget {
  final VoidCallback? onOrderCreated;
  const CreateOrderPage({Key? key, this.onOrderCreated}) : super(key: key);

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 5;

  final OrderService _orderService = OrderService();

  final TextEditingController originController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController specialInstructionsController = TextEditingController();

  Position? originPosition;
  Position? destinationPosition;

  // Changed to support multiple images
  List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isCreatingOrder = false;

  int? userId;
  bool _isLoadingUser = true;

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
    weightController.dispose();
    specialInstructionsController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
          _showSnackBar('Please get coordinates for origin location', Colors.orange);
          return false;
        }
        return true;
      case 1:
        if (destinationController.text.trim().isEmpty) {
          _showSnackBar('Please enter destination location', Colors.orange);
          return false;
        }
        if (destinationPosition == null) {
          _showSnackBar('Please get coordinates for destination location', Colors.orange);
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
        if (weightController.text.trim().isEmpty) {
          _showSnackBar('Please enter weight', Colors.orange);
          return false;
        }
        final weight = double.tryParse(weightController.text.trim());
        if (weight == null || weight <= 0) {
          _showSnackBar('Please enter valid weight', Colors.orange);
          return false;
        }
        return true;
      case 4:
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
      print('DEBUG: Starting order creation process');
      print('DEBUG: Uploading ${_selectedImages.length} images');

      final orderRequest = OrderCreateRequest(
        userId: userId!,
        origin: originController.text.trim(),
        originLatitude: originPosition!.latitude,
        originLongitude: originPosition!.longitude,
        destination: destinationController.text.trim(),
        destinationLatitude: destinationPosition!.latitude,
        destinationLongitude: destinationPosition!.longitude,
        deliveryDate: _formatDateForApi(dateController.text.trim()),
        weight: double.parse(weightController.text.trim()),
        images: _selectedImages, // Pass File objects directly
        specialInstructions: specialInstructionsController.text.trim().isEmpty
            ? null
            : specialInstructionsController.text.trim(),
      );

      print('DEBUG: Order request prepared with ${_selectedImages.length} images');

      final response = await _orderService.createOrder(orderRequest);

      if (response != null) {
        print('DEBUG: Order created successfully!');
        print('DEBUG: Message: ${response.message}');
        print('DEBUG: Order ID: ${response.orderId}');

        // Enhanced logging for images
        if (response.imageUrls != null && response.imageUrls!.isNotEmpty) {
          print('DEBUG: ✅ ${response.imageUrls!.length} image(s) uploaded successfully:');
          for (int i = 0; i < response.imageUrls!.length; i++) {
            print('DEBUG:   Image ${i + 1}: ${response.imageUrls![i]}');
          }
        } else {
          print('DEBUG: ℹ️ No images were uploaded (optional)');
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

        // Enhanced success message with image count
        String successMessage = 'Order ID: #${response.orderId}';
        if (response.imageUrls != null && response.imageUrls!.isNotEmpty) {
          successMessage += '\n📸 ${response.imageUrls!.length} image(s) uploaded';
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
        _showSnackBar('Failed to create order: ${e.toString().replaceAll('Exception: ', '')}', Colors.red);
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
                    Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                child: const Icon(Icons.check_circle, color: Colors.white, size: 24),
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
        _showSnackBar('Image added (${_selectedImages.length} total)', Colors.green);
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
          _showSnackBar('${images.length} images added (${_selectedImages.length} total)', Colors.green);
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
        weightController.text.trim().isEmpty) {
      _showSnackBar('Please fill all required fields', Colors.red);
      return false;
    }

    if (originPosition == null || destinationPosition == null) {
      _showSnackBar('Please ensure both origin and destination coordinates are set', Colors.red);
      return false;
    }

    final weight = double.tryParse(weightController.text.trim());
    if (weight == null || weight <= 0) {
      _showSnackBar('Please enter valid weight', Colors.red);
      return false;
    }

    return true;
  }

  void _clearAllFields() {
    originController.clear();
    destinationController.clear();
    dateController.clear();
    weightController.clear();
    specialInstructionsController.clear();
    setState(() {
      _selectedImages.clear();
      originPosition = null;
      destinationPosition = null;
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressIndicator(),
            Expanded(
              child: PageView(
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
                ],
              ),
            ),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            IconButton(
              onPressed: _previousStep,
              icon: const Icon(Icons.arrow_back_ios),
              padding: EdgeInsets.zero,
            ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Order',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Text(
                'Step ${_currentStep + 1} of $_totalSteps',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 4,
              decoration: BoxDecoration(
                color: index <= _currentStep ? AppColors.primary : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1() {
    return _buildStepContainer(
      title: '📍 Origin Location',
      subtitle: 'Where should we collect the package?',
      child: Column(
        children: [
          const SizedBox(height: 40),
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
                    'Tap the field above to open location search. You can use current location or search for an address.',
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

  Widget _buildStepContainer({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
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
                  side: BorderSide(color: AppColors.primary),
                ),
                child: Text(
                  'Previous',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: _currentStep > 0 ? 1 : 2,
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
                  borderRadius: BorderRadius.circular(8),
                ),
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
                  : Text(
                _currentStep == _totalSteps - 1 ? 'Create Order' : 'Next',
                style: const TextStyle(
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

  Widget _buildStep2() {
    return _buildStepContainer(
      title: '🎯 Destination Location',
      subtitle: 'Where should the package be delivered?',
      child: Column(
        children: [
          const SizedBox(height: 40),
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
                    'Tap the field above to open location search. Ensure the delivery address is complete.',
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
    return _buildStepContainer(
      title: '📅 Delivery Date',
      subtitle: 'When do you need this delivered?',
      child: Column(
        children: [
          const SizedBox(height: 40),
          _buildStepInputField(
            controller: dateController,
            icon: Icons.calendar_today,
            label: 'Delivery Date',
            hint: 'Select delivery date',
            helperText: 'Choose your preferred delivery date',
            readOnly: true,
            onTap: () => _selectDate(context),
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

  Widget _buildStep4() {
    return _buildStepContainer(
      title: '⚖️ Package Weight',
      subtitle: 'Tell us about the package weight',
      child: Column(
        children: [
          const SizedBox(height: 40),
          _buildStepInputField(
            controller: weightController,
            icon: Icons.scale,
            label: 'Weight (kg)',
            hint: 'Enter weight in kg',
            keyboardType: TextInputType.number,
            helperText: 'Approximate weight of the package',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.purple[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Enter weight as a decimal number (e.g., 2.5 for 2.5 kg)',
                    style: TextStyle(
                      color: Colors.purple[700],
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

  Widget _buildStep5() {
    return _buildStepContainer(
      title: '📸 Additional Details',
      subtitle: 'Add images and special instructions (optional)',
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Multiple images display
          if (_selectedImages.isEmpty)
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
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
                            border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, color: Colors.grey[400], size: 32),
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
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onTap: onTap,
            maxLines: maxLines,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              prefixIcon: Icon(icon, color: AppColors.primary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              labelStyle: TextStyle(color: AppColors.primary),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 8),
          Text(
            helperText,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}