import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import '../../Controllers/OrderService.dart';
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
  // Page controller for step navigation
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 5;

  // Services
  final OrderService _orderService = OrderService();

  // Text controllers for form fields
  final TextEditingController originController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController imageUrlController = TextEditingController();
  final TextEditingController specialInstructionsController = TextEditingController();

  // Location variables
  Position? originPosition;
  Position? destinationPosition;
  bool isLoadingOriginLocation = false;
  bool isLoadingDestinationLocation = false;

  // Image handling
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isCreatingOrder = false;

  // User ID - Replace with actual user ID from auth
  int userId = 2; // TODO: Get from auth service

  @override
  void dispose() {
    _pageController.dispose();
    originController.dispose();
    destinationController.dispose();
    dateController.dispose();
    weightController.dispose();
    imageUrlController.dispose();
    specialInstructionsController.dispose();
    super.dispose();
  }

  // Navigate to next step
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

  // Navigate to previous step
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

  // Validate current step
  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Origin Location
        if (originController.text.trim().isEmpty) {
          _showSnackBar('Please enter origin location', Colors.orange);
          return false;
        }
        if (originPosition == null) {
          _showSnackBar('Please get coordinates for origin location', Colors.orange);
          return false;
        }
        return true;
      case 1: // Destination Location
        if (destinationController.text.trim().isEmpty) {
          _showSnackBar('Please enter destination location', Colors.orange);
          return false;
        }
        if (destinationPosition == null) {
          _showSnackBar('Please get coordinates for destination location', Colors.orange);
          return false;
        }
        return true;
      case 2: // Date
        if (dateController.text.trim().isEmpty) {
          _showSnackBar('Please select delivery date', Colors.orange);
          return false;
        }
        return true;
      case 3: // Weight
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
      case 4: // Image and Special Instructions (optional)
        return true;
      default:
        return true;
    }
  }

  // Get current location for origin
  Future<void> _getCurrentLocationForOrigin() async {
    setState(() {
      isLoadingOriginLocation = true;
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
          originController.text = address ?? 'Current Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
          isLoadingOriginLocation = false;
        });
        _showSnackBar('✅ Origin coordinates saved', Colors.green);
      } else {
        setState(() {
          isLoadingOriginLocation = false;
        });
        _showSnackBar('Unable to get current location. Please check permissions.', Colors.red);
      }
    } catch (e) {
      setState(() {
        isLoadingOriginLocation = false;
      });
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  // Get current location for destination
  Future<void> _getCurrentLocationForDestination() async {
    setState(() {
      isLoadingDestinationLocation = true;
    });
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        final address = await LocationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        setState(() {
          destinationPosition = position;
          destinationController.text = address ?? 'Current Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
          isLoadingDestinationLocation = false;
        });
        _showSnackBar('✅ Destination coordinates saved', Colors.green);
      } else {
        setState(() {
          isLoadingDestinationLocation = false;
        });
        _showSnackBar('Unable to get current location. Please check permissions.', Colors.red);
      }
    } catch (e) {
      setState(() {
        isLoadingDestinationLocation = false;
      });
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  // Search location from text input
  Future<void> _searchLocation(TextEditingController controller, bool isOrigin) async {
    if (controller.text.trim().isEmpty) {
      _showSnackBar('Please enter a location to search', Colors.orange);
      return;
    }

    if (isOrigin) {
      setState(() {
        isLoadingOriginLocation = true;
      });
    } else {
      setState(() {
        isLoadingDestinationLocation = true;
      });
    }

    try {
      final locations = await LocationService.getCoordinatesFromAddress(controller.text.trim());
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
          if (isOrigin) {
            originPosition = position;
            isLoadingOriginLocation = false;
          } else {
            destinationPosition = position;
            isLoadingDestinationLocation = false;
          }
        });
        _showSnackBar(isOrigin ? '✅ Origin coordinates found' : '✅ Destination coordinates found', Colors.green);
      } else {
        setState(() {
          if (isOrigin) {
            isLoadingOriginLocation = false;
          } else {
            isLoadingDestinationLocation = false;
          }
        });
        _showSnackBar('Location not found. Please try a different search term.', Colors.orange);
      }
    } catch (e) {
      setState(() {
        if (isOrigin) {
          isLoadingOriginLocation = false;
        } else {
          isLoadingDestinationLocation = false;
        }
      });
      _showSnackBar('Error searching location: $e', Colors.red);
    }
  }

  Future<void> _createOrder() async {
    // Validate all required fields
    if (!_validateAllFields()) return;

    try {
      setState(() {
        _isCreatingOrder = true;
      });

      print('DEBUG: Starting order creation process');

      // Prepare order request
      final orderRequest = OrderCreateRequest(
        userId: userId,
        origin: originController.text.trim(),
        originLatitude: originPosition!.latitude,
        originLongitude: originPosition!.longitude,
        destination: destinationController.text.trim(),
        destinationLatitude: destinationPosition!.latitude,
        destinationLongitude: destinationPosition!.longitude,
        deliveryDate: _formatDateForApi(dateController.text.trim()),
        weight: double.parse(weightController.text.trim()),
        imageUrl: imageUrlController.text.trim().isEmpty
            ? 'https://example.com/default.jpg'
            : imageUrlController.text.trim(),
        specialInstructions: specialInstructionsController.text.trim().isEmpty
            ? null
            : specialInstructionsController.text.trim(),
      );

      print('DEBUG: Order request prepared: ${orderRequest.toJson()}');

      // Call API to create order
      final response = await _orderService.createOrder(orderRequest);

      if (response != null) {
        print('DEBUG: Order created successfully: ${response.message}, Order ID: ${response.orderId}');

        // Clear all fields for next order
        _clearAllFields();

        // Reset to first step
        setState(() {
          _currentStep = 0;
          _isCreatingOrder = false;
        });
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );

        // Show success message
        _showSuccessToast('Order created successfully! Order ID: #${response.orderId}');

        // Call callback if provided
        widget.onOrderCreated?.call();
      } else {
        setState(() {
          _isCreatingOrder = false;
        });

        // Check if it's a KYC error by examining the error from OrderService
        // You'll need to modify OrderService to return error details
        _showKycRequiredDialog();
      }
    } catch (e, stackTrace) {
      setState(() {
        _isCreatingOrder = false;
      });
      print('DEBUG: Error creating order: $e');
      print('DEBUG: Stack trace: $stackTrace');

      // Check if error is related to KYC
      if (e.toString().contains('KYC') || e.toString().contains('403')) {
        _showKycRequiredDialog();
      } else {
        _showSnackBar('Failed to create order: $e', Colors.red);
      }
    }
  }

// Show KYC Required Dialog
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

// Navigate to KYC Screen
  // Navigate to KYC Screen
  void _navigateToKycScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KycUploadScreen(
          userId: userId,
        ),
      ),
    );

    // If KYC was uploaded successfully
    if (result == true) {
      _showSnackBar(
        'KYC document uploaded successfully! You can now create orders.',
        Colors.green,
      );
    }
  }


  // Format date for API (yyyy-MM-dd)
  String _formatDateForApi(String dateString) {
    // Input format: dd/MM/yyyy
    // Output format: yyyy-MM-dd
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

  // Enhanced success toast message
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
        duration: const Duration(seconds: 4),
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

  // Pick image from gallery or camera
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
                  'Add Package Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
                          _getImage(ImageSource.gallery);
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
          _selectedImage = File(image.path);
          // For demo purposes, set a placeholder URL
          imageUrlController.text = 'https://example.com/image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        });
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', Colors.red);
    }
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
    imageUrlController.clear();
    specialInstructionsController.clear();
    setState(() {
      _selectedImage = null;
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header with progress
            _buildHeader(),
            // Progress indicator
            _buildProgressIndicator(),
            // Step content
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
                  _buildStep1(), // Origin Location
                  _buildStep2(), // Destination Location
                  _buildStep3(), // Delivery Date
                  _buildStep4(), // Weight
                  _buildStep5(), // Image URL and Special Instructions
                ],
              ),
            ),
            // Navigation buttons
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

  // Step 1: Origin Location
  Widget _buildStep1() {
    return _buildStepContainer(
      title: '📍 Origin Location',
      subtitle: 'Where should we collect the package?',
      child: Column(
        children: [
          const SizedBox(height: 40),
          _buildLocationInputField(
            controller: originController,
            icon: Icons.my_location,
            label: 'Origin Address',
            hint: 'Enter origin location',
            helperText: 'Be specific with landmarks for easy pickup',
            isLoading: isLoadingOriginLocation,
            onCurrentLocationPressed: _getCurrentLocationForOrigin,
            onSearchPressed: () => _searchLocation(originController, true),
            position: originPosition,
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
                    'Tap the location icon to use your current location or search icon to find a location.',
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

  Widget _buildLocationInputField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String hint,
    String? helperText,
    required bool isLoading,
    required VoidCallback onCurrentLocationPressed,
    required VoidCallback onSearchPressed,
    Position? position,
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
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              prefixIcon: Icon(icon, color: AppColors.primary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              labelStyle: TextStyle(color: AppColors.primary),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
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
                      icon: const Icon(Icons.my_location),
                      onPressed: onCurrentLocationPressed,
                      tooltip: 'Use current location',
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: onSearchPressed,
                      tooltip: 'Search location',
                    ),
                  ],
                ],
              ),
            ),
            onChanged: (value) {
              if (position != null) {
                setState(() {
                  if (controller == originController) {
                    originPosition = null;
                  } else {
                    destinationPosition = null;
                  }
                });
              }
            },
          ),
        ),
        if (position != null) ...[
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
                    'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}',
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
              onPressed: _currentStep == _totalSteps - 1 ? _createOrder : () {
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

  // Step 2: Destination Location
  Widget _buildStep2() {
    return _buildStepContainer(
      title: '🎯 Destination Location',
      subtitle: 'Where should the package be delivered?',
      child: Column(
        children: [
          const SizedBox(height: 40),
          _buildLocationInputField(
            controller: destinationController,
            icon: Icons.place,
            label: 'Destination Address',
            hint: 'Enter destination location',
            helperText: 'Exact delivery address',
            isLoading: isLoadingDestinationLocation,
            onCurrentLocationPressed: _getCurrentLocationForDestination,
            onSearchPressed: () => _searchLocation(destinationController, false),
            position: destinationPosition,
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
                    'Make sure the delivery address is complete and accessible.',
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

  // Step 3: Delivery Date
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
                    'Date format: YYYY-MM-DD (e.g., 2025-09-30)',
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

  // Step 4: Weight
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

  // Step 5: Image URL and Special Instructions
  Widget _buildStep5() {
    return _buildStepContainer(
      title: '📸 Additional Details',
      subtitle: 'Add image and special instructions (optional)',
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Image section
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                ),
              )
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add Package Photo',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to add photo (Optional)',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedImage != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.edit),
                  label: const Text('Change Photo'),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedImage = null;
                      imageUrlController.clear();
                    });
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          const SizedBox(height: 24),
          _buildStepInputField(
            controller: imageUrlController,
            icon: Icons.link,
            label: 'Image URL (Optional)',
            hint: 'Enter image URL',
            helperText: 'Or upload an image using the photo picker above',
          ),
          const SizedBox(height: 16),
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
