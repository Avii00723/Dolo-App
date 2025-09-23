import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import '../LoginScreens/UserProfileHelper.dart';
import '../../Constants/colorconstant.dart';
import '../../Services/LocationService.dart';

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({Key? key}) : super(key: key);

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  // Page controller for step navigation
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 5;

  // Text controllers for form fields
  final TextEditingController pickupController = TextEditingController();
  final TextEditingController dropoffController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController itemDescriptionController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  // Location variables
  Position? pickupPosition;
  Position? dropoffPosition;
  bool isLoadingPickupLocation = false;
  bool isLoadingDropoffLocation = false;

  // Image handling
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _pageController.dispose();
    pickupController.dispose();
    dropoffController.dispose();
    dateController.dispose();
    itemDescriptionController.dispose();
    weightController.dispose();
    priceController.dispose();
    notesController.dispose();
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
      case 0: // Pickup Location
        if (pickupController.text.trim().isEmpty) {
          _showSnackBar('Please enter pickup location', Colors.orange);
          return false;
        }
        return true;
      case 1: // Dropoff Location
        if (dropoffController.text.trim().isEmpty) {
          _showSnackBar('Please enter dropoff location', Colors.orange);
          return false;
        }
        return true;
      case 2: // Date and Item Details
        if (dateController.text.trim().isEmpty || itemDescriptionController.text.trim().isEmpty) {
          _showSnackBar('Please fill in date and item description', Colors.orange);
          return false;
        }
        return true;
      case 3: // Weight and Price
        if (weightController.text.trim().isEmpty || priceController.text.trim().isEmpty) {
          _showSnackBar('Please enter weight and expected price', Colors.orange);
          return false;
        }
        return true;
      case 4: // Image and Notes
        return true; // Image and notes are optional
      default:
        return true;
    }
  }

  // Get current location for pickup
  Future<void> _getCurrentLocationForPickup() async {
    setState(() {
      isLoadingPickupLocation = true;
    });

    try {
      final position = await LocationService.getCurrentPosition();

      if (position != null) {
        final address = await LocationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );

        setState(() {
          pickupPosition = position;
          pickupController.text = address ?? 'Current Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
          isLoadingPickupLocation = false;
        });
      } else {
        setState(() {
          isLoadingPickupLocation = false;
        });
        _showSnackBar('Unable to get current location. Please check permissions.', Colors.red);
      }
    } catch (e) {
      setState(() {
        isLoadingPickupLocation = false;
      });
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  // Get current location for dropoff
  Future<void> _getCurrentLocationForDropoff() async {
    setState(() {
      isLoadingDropoffLocation = true;
    });

    try {
      final position = await LocationService.getCurrentPosition();

      if (position != null) {
        final address = await LocationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );

        setState(() {
          dropoffPosition = position;
          dropoffController.text = address ?? 'Current Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
          isLoadingDropoffLocation = false;
        });
      } else {
        setState(() {
          isLoadingDropoffLocation = false;
        });
        _showSnackBar('Unable to get current location. Please check permissions.', Colors.red);
      }
    } catch (e) {
      setState(() {
        isLoadingDropoffLocation = false;
      });
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  // Search location from text input
  Future<void> _searchLocation(TextEditingController controller, bool isPickup) async {
    if (controller.text.trim().isEmpty) {
      _showSnackBar('Please enter a location to search', Colors.orange);
      return;
    }

    if (isPickup) {
      setState(() {
        isLoadingPickupLocation = true;
      });
    } else {
      setState(() {
        isLoadingDropoffLocation = true;
      });
    }

    try {
      final locations = await LocationService.getCoordinatesFromAddress(controller.text.trim());

      if (locations != null && locations.isNotEmpty) {
        final location = locations.first;
        // Create Position from Location
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
          if (isPickup) {
            pickupPosition = position;
            isLoadingPickupLocation = false;
          } else {
            dropoffPosition = position;
            isLoadingDropoffLocation = false;
          }
        });
      } else {
        setState(() {
          if (isPickup) {
            isLoadingPickupLocation = false;
          } else {
            isLoadingDropoffLocation = false;
          }
        });
        _showSnackBar('Location not found. Please try a different search term.', Colors.orange);
      }
    } catch (e) {
      setState(() {
        if (isPickup) {
          isLoadingPickupLocation = false;
        } else {
          isLoadingDropoffLocation = false;
        }
      });
      _showSnackBar('Error searching location: $e', Colors.red);
    }
  }

  // Pick image from gallery or camera
  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Add Package Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
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
                          padding: EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
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
                          padding: EdgeInsets.symmetric(vertical: 15),
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
        });
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', Colors.red);
    }
  }

  // Upload image to Firebase Storage
  Future<String?> _uploadImage(File imageFile) async {
    try {
      final String fileName = 'order_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      final UploadTask uploadTask = storageRef.putFile(imageFile);

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      _showSnackBar('Error uploading image: $e', Colors.red);
      return null;
    }
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
                onPageChanged: (index) {
                  setState(() {
                    _currentStep = index;
                  });
                },
                children: [
                  _buildStep1(), // Pickup Location
                  _buildStep2(), // Dropoff Location
                  _buildStep3(), // Date and Item Details
                  _buildStep4(), // Weight and Price
                  _buildStep5(), // Image and Notes
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

  // Step 1: Pickup Location
  Widget _buildStep1() {
    return _buildStepContainer(
      title: '📍 Pickup Location',
      subtitle: 'Where should we collect your package?',
      child: Column(
        children: [
          const SizedBox(height: 40),
          _buildLocationInputField(
            controller: pickupController,
            icon: Icons.my_location,
            label: 'Pickup Address',
            hint: 'Enter your pickup location',
            helperText: 'Be specific with landmarks for easy pickup',
            isLoading: isLoadingPickupLocation,
            onCurrentLocationPressed: _getCurrentLocationForPickup,
            onSearchPressed: () => _searchLocation(pickupController, true),
            position: pickupPosition,
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

  // Step 2: Dropoff Location
  Widget _buildStep2() {
    return _buildStepContainer(
      title: '🎯 Dropoff Location',
      subtitle: 'Where should your package be delivered?',
      child: Column(
        children: [
          const SizedBox(height: 40),
          _buildLocationInputField(
            controller: dropoffController,
            icon: Icons.place,
            label: 'Delivery Address',
            hint: 'Enter destination location',
            helperText: 'Exact delivery address with contact details',
            isLoading: isLoadingDropoffLocation,
            onCurrentLocationPressed: _getCurrentLocationForDropoff,
            onSearchPressed: () => _searchLocation(dropoffController, false),
            position: dropoffPosition,
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

  // Step 3: Date and Item Details
  Widget _buildStep3() {
    return _buildStepContainer(
      title: '📅 Schedule & Details',
      subtitle: 'When do you need this delivered?',
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildStepInputField(
            controller: dateController,
            icon: Icons.calendar_today,
            label: 'Preferred Date',
            hint: 'Select delivery date',
            readOnly: true,
            onTap: () => _selectDate(context),
          ),
          const SizedBox(height: 16),
          _buildStepInputField(
            controller: itemDescriptionController,
            icon: Icons.inventory,
            label: 'Package Description',
            hint: 'What are you sending?',
            helperText: 'Describe your package contents (e.g., documents, electronics, gifts)',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // Step 4: Weight and Price
  Widget _buildStep4() {
    return _buildStepContainer(
      title: '⚖️ Package Details',
      subtitle: 'Tell us about your package specifications',
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildStepInputField(
            controller: weightController,
            icon: Icons.scale,
            label: 'Package Weight',
            hint: 'Enter weight in kg',
            keyboardType: TextInputType.number,
            helperText: 'Approximate weight helps us match with suitable travelers',
          ),
          const SizedBox(height: 16),
          _buildStepInputField(
            controller: priceController,
            icon: Icons.currency_rupee,
            label: 'Expected Price',
            hint: 'Enter your budget (₹)',
            keyboardType: TextInputType.number,
            helperText: 'This is your budget - final price will be negotiated',
          ),
        ],
      ),
    );
  }

  // Step 5: Image and Notes
  Widget _buildStep5() {
    return _buildStepContainer(
      title: '📸 Package Photo & Notes',
      subtitle: 'Add a photo and any special instructions (optional)',
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
            controller: notesController,
            icon: Icons.note,
            label: 'Special Instructions',
            hint: 'Any special handling instructions?',
            helperText: 'Fragile items, time preferences, etc.',
            maxLines: 3,
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
              // Clear position when user types manually
              if (position != null) {
                setState(() {
                  if (controller == pickupController) {
                    pickupPosition = null;
                  } else {
                    dropoffPosition = null;
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
              child: _isUploading
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

  Future<void> _createOrder() async {
    // Profile gate check
    final canProceed = await UserProfileHelper.checkProfileForAction(context, 'create_order');
    if (!canProceed) return;

    // Get current user ID
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnackBar('User not logged in', Colors.red);
      return;
    }

    // Validate all required fields
    if (!_validateAllFields()) return;

    try {
      setState(() {
        _isUploading = true;
      });

      // Upload image if selected
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage(_selectedImage!);
        if (imageUrl == null) {
          setState(() {
            _isUploading = false;
          });
          return;
        }
      }

      // Create order document with location data
      await firestore.collection('orders').add({
        'sender_id': uid,
        'origin': pickupController.text.trim(),
        'destination': dropoffController.text.trim(),
        'date': dateController.text.trim(),
        'item_description': itemDescriptionController.text.trim(),
        'weight': weightController.text.trim(),
        'expected_price': priceController.text.trim(),
        'notes': notesController.text.trim(),
        'image_url': imageUrl,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
        // Location coordinates
        'pickup_coordinates': pickupPosition != null ? {
          'latitude': pickupPosition!.latitude,
          'longitude': pickupPosition!.longitude,
        } : null,
        'dropoff_coordinates': dropoffPosition != null ? {
          'latitude': dropoffPosition!.latitude,
          'longitude': dropoffPosition!.longitude,
        } : null,
      });

      // Clear all fields
      _clearAllFields();

      // Reset to first step
      setState(() {
        _currentStep = 0;
        _isUploading = false;
      });
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      _showSnackBar('Order created successfully! 🎉', Colors.green);
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showSnackBar('Failed to create order: $e', Colors.red);
    }
  }

  bool _validateAllFields() {
    if (pickupController.text.trim().isEmpty ||
        dropoffController.text.trim().isEmpty ||
        dateController.text.trim().isEmpty ||
        itemDescriptionController.text.trim().isEmpty ||
        weightController.text.trim().isEmpty ||
        priceController.text.trim().isEmpty) {
      _showSnackBar('Please fill all required fields', Colors.red);
      return false;
    }
    return true;
  }

  void _clearAllFields() {
    pickupController.clear();
    dropoffController.clear();
    dateController.clear();
    itemDescriptionController.clear();
    weightController.clear();
    priceController.clear();
    notesController.clear();
    setState(() {
      _selectedImage = null;
      pickupPosition = null;
      dropoffPosition = null;
    });
  }
}
