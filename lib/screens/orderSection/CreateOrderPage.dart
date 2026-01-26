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
  final int _totalSteps = 3;

  final OrderService _orderService = OrderService();

  final TextEditingController pickupCityController = TextEditingController();
  final TextEditingController dropCityController = TextEditingController();
  final TextEditingController pickupDateController = TextEditingController();
  final TextEditingController deliveryDateController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController packageTypeController = TextEditingController();
  final TextEditingController transportController = TextEditingController();
  final TextEditingController restrictionsController = TextEditingController();

  Position? originPosition;
  Position? destinationPosition;

  OrderMainCategory? _selectedMainCategory;
  String? _selectedWeightRange;
  List<String> _selectedTransportModes = [];
  bool _isUrgent = false;

  List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isCreatingOrder = false;

  String? userId;
  bool _isLoadingUser = true;

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
    } catch (e) {
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
    pickupCityController.dispose();
    dropCityController.dispose();
    pickupDateController.dispose();
    deliveryDateController.dispose();
    weightController.dispose();
    packageTypeController.dispose();
    transportController.dispose();
    restrictionsController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      if (_validateCurrentStep()) {
        setState(() {
          _currentStep++;
        });
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
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
        if (pickupCityController.text.trim().isEmpty) {
          _showSnackBar('Please enter pickup city', Colors.orange);
          return false;
        }
        if (dropCityController.text.trim().isEmpty) {
          _showSnackBar('Please enter drop city', Colors.orange);
          return false;
        }
        if (pickupDateController.text.trim().isEmpty) {
          _showSnackBar('Please select pickup date & time', Colors.orange);
          return false;
        }
        if (deliveryDateController.text.trim().isEmpty) {
          _showSnackBar('Please select delivery date & time', Colors.orange);
          return false;
        }
        return true;
      case 1:
        if (_selectedWeightRange == null) {
          _showSnackBar('Please select package weight', Colors.orange);
          return false;
        }
        if (_selectedMainCategory == null) {
          _showSnackBar('Please select package type', Colors.orange);
          return false;
        }
        return true;
      case 2:
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

      String apiCategory = _selectedMainCategory!.apiValue;
      String weightString = _getWeightStringForApi(_selectedWeightRange!);

      final orderRequest = OrderCreateRequest(
        userHashedId: userId!,
        origin: pickupCityController.text.trim(),
        originLatitude: originPosition?.latitude ?? 0.0,
        originLongitude: originPosition?.longitude ?? 0.0,
        destination: dropCityController.text.trim(),
        destinationLatitude: destinationPosition?.latitude ?? 0.0,
        destinationLongitude: destinationPosition?.longitude ?? 0.0,
        deliveryDate: _formatDateForApi(deliveryDateController.text.trim()),
        deliveryTime: '12:00:00',
        weight: weightString,
        actualWeight: null,
        category: apiCategory,
        customCategory: null,
        preferenceTransport: _selectedTransportModes.isNotEmpty ? _selectedTransportModes : null,
        isUrgent: _isUrgent,
        images: _selectedImages,
        specialInstructions: restrictionsController.text.trim().isEmpty ? null : restrictionsController.text.trim(),
      );

      final response = await _orderService.createOrder(orderRequest);

      if (response != null) {
        _clearAllFields();
        setState(() {
          _currentStep = 0;
          _isCreatingOrder = false;
        });
        _pageController.jumpToPage(0);

        _showSuccessToast('Order ID: #${response.orderId}');
        widget.onOrderCreated?.call();
      } else {
        setState(() {
          _isCreatingOrder = false;
        });
        _showKycRequiredDialog();
      }
    } catch (e) {
      setState(() {
        _isCreatingOrder = false;
      });

      if (e.toString().contains('KYC') || e.toString().contains('403')) {
        _showKycRequiredDialog();
      } else {
        _showSnackBar('Failed to create order: ${e.toString().replaceAll('Exception: ', '')}', Colors.red);
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

  bool _validateAllFields() {
    if (pickupCityController.text.trim().isEmpty ||
        dropCityController.text.trim().isEmpty ||
        pickupDateController.text.trim().isEmpty ||
        deliveryDateController.text.trim().isEmpty ||
        _selectedWeightRange == null ||
        _selectedMainCategory == null) {
      _showSnackBar('Please fill all required fields', Colors.red);
      return false;
    }
    return true;
  }

  void _clearAllFields() {
    pickupCityController.clear();
    dropCityController.clear();
    pickupDateController.clear();
    deliveryDateController.clear();
    weightController.clear();
    packageTypeController.clear();
    transportController.clear();
    restrictionsController.clear();
    setState(() {
      _selectedImages.clear();
      originPosition = null;
      destinationPosition = null;
      _selectedMainCategory = null;
      _selectedWeightRange = null;
      _selectedTransportModes = [];
      _isUrgent = false;
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showKycRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('KYC Verification Required'),
        content: const Text('To create orders, you need to complete your KYC verification.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
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
      MaterialPageRoute(builder: (context) => KycUploadScreen(userId: userId!)),
    );
    if (result == true) {
      _showSnackBar('KYC document uploaded successfully!', Colors.green);
    }
  }

  Future<void> _selectDateTime(TextEditingController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          controller.text = '${date.day}/${date.month}/${date.year} · ${time.format(context)}';
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
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      try {
        if (source == ImageSource.gallery) {
          final images = await _picker.pickMultiImage();
          if (images.isNotEmpty) {
            setState(() {
              _selectedImages.addAll(images.map((img) => File(img.path)));
            });
          }
        } else {
          final image = await _picker.pickImage(source: source);
          if (image != null) {
            setState(() {
              _selectedImages.add(File(image.path));
            });
          }
        }
      } catch (e) {
        _showSnackBar('Error picking image: $e', Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
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
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _previousStep,
        )
            : IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Create Order',
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Step Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStepTitle(),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / _totalSteps,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[800]!),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(_currentStep + 1).toString().padLeft(2, '0')} / ${_totalSteps.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
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

          // Bottom Button
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              margin: const EdgeInsets.only(bottom: 30),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isCreatingOrder
                      ? null
                      : (_currentStep == _totalSteps - 1 ? _createOrder : _nextStep),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[850],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: _isCreatingOrder
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : Text(
                    _currentStep == _totalSteps - 1 ? 'POST' : 'NEXT',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildTripDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // UPDATED: Use EnhancedLocationInputField for Pickup
          _buildLocationInputWrapper(
            label: 'Pickup City',
            child: EnhancedLocationInputField(
              controller: pickupCityController,
              label: '',
              hint: 'Eg. Mumbai',
              icon: Icons.trip_origin,
              isOrigin: true,
              onLocationSelected: (position) {
                setState(() {
                  originPosition = position;
                });
              },
            ),
          ),
          const SizedBox(height: 20),

          // UPDATED: Use EnhancedLocationInputField for Drop
          _buildLocationInputWrapper(
            label: 'Drop City',
            child: EnhancedLocationInputField(
              controller: dropCityController,
              label: '',
              hint: 'Eg. Delhi',
              icon: Icons.place,
              isOrigin: false,
              onLocationSelected: (position) {
                setState(() {
                  destinationPosition = position;
                });
              },
            ),
          ),
          const SizedBox(height: 20),
          _buildInputField(
            label: 'Pick-up Date & Time',
            controller: pickupDateController,
            hint: 'dd/mm/yyyy · HH:MM',
            icon: Icons.calendar_today,
            readOnly: true,
            onTap: () => _selectDateTime(pickupDateController),
          ),
          const SizedBox(height: 20),
          _buildInputField(
            label: 'Delivery Date & Time',
            controller: deliveryDateController,
            hint: 'dd/mm/yyyy · HH:MM',
            icon: Icons.calendar_today,
            readOnly: true,
            onTap: () => _selectDateTime(deliveryDateController),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _isUrgent,
                  onChanged: (value) => setState(() => _isUrgent = value ?? false),
                  activeColor: Colors.grey[800],
                ),
                Expanded(
                  child: Text(
                    'Mark this order as urgent for priority handling',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget to wrap location input and maintain consistent label styling
  Widget _buildLocationInputWrapper({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

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
            onChanged: (value) => setState(() => _selectedWeightRange = value),
          ),
          const SizedBox(height: 20),
          _buildCategoryDropdown(),
          const SizedBox(height: 20),
          _buildDropdownField(
            label: 'Preferred Transport',
            hint: 'Eg. Car',
            icon: Icons.directions_car,
            value: _selectedTransportModes.isNotEmpty ? _selectedTransportModes.first : null,
            items: _transportModes,
            onChanged: (value) => setState(() => _selectedTransportModes = value != null ? [value] : []),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Package Photo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 1.5, style: BorderStyle.solid),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.add_photo_alternate_outlined, size: 28, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 12),
                  const Text('Upload File', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  Text('Tap to add photo', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              )
                  : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_selectedImages[index], fit: BoxFit.cover),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildInputField(
            label: 'Restrictions & Requirements',
            controller: restrictionsController,
            hint: 'Eg. no liquid, no fragile items',
            icon: Icons.info_outline,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

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
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(icon, size: 20, color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[400]!),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Text(hint, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            ],
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Package Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<OrderMainCategory>(
          value: _selectedMainCategory,
          hint: Row(
            children: [
              Icon(Icons.category, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Text('Eg. Furniture', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            ],
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: orderCategories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category.name, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedMainCategory = value),
        ),
      ],
    );
  }
}