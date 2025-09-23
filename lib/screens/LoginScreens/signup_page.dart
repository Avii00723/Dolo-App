import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class SignupScreen extends StatefulWidget {
  final bool isKycRequired;
  final Map<String, dynamic>? existingUserData; // For edit mode

  const SignupScreen({
    Key? key,
    this.isKycRequired = false,
    this.existingUserData,
  }) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Basic Profile Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // KYC Controllers
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();

  String _selectedUserType = 'sender';
  bool _isLoading = false;
  File? _profileImage;
  File? _licenseImage;
  bool _isEditMode = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.existingUserData != null;
    if (_isEditMode) {
      _populateExistingData();
    }
  }

  void _populateExistingData() {
    final data = widget.existingUserData!;
    _nameController.text = data['name'] ?? '';
    _emailController.text = data['email'] ?? '';
    _aadhaarController.text = data['aadhaar'] ?? '';
    _selectedUserType = data['userType'] ?? 'sender';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _aadhaarController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  Future<void> _pickLicenseImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _licenseImage = File(image.path);
      });
    }
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check KYC requirement
    if (widget.isKycRequired && _selectedUserType == 'traveller') {
      if (_aadhaarController.text.isEmpty || (!_isEditMode && _licenseImage == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KYC documents are required for trip creators'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String userId = _auth.currentUser?.uid ?? '';
      final String phoneNumber = _auth.currentUser?.phoneNumber ?? '';

      // Prepare user data
      Map<String, dynamic> userData = {
        'uid': userId,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': phoneNumber,
        'userType': _selectedUserType,
        'profileCompleted': true,
        'lastLogin': FieldValue.serverTimestamp(),
      };

      // Add creation timestamp only for new profiles
      if (!_isEditMode) {
        userData['createdAt'] = FieldValue.serverTimestamp();
        userData['walletBalance'] = 0;
      }

      // Handle profile image
      if (_profileImage != null) {
        userData['profileUrl'] = 'profile_uploaded'; // In real app, upload to storage
      } else if (_isEditMode && widget.existingUserData!['profileUrl'] != null) {
        userData['profileUrl'] = widget.existingUserData!['profileUrl'];
      }

      // ✅ FIXED KYC LOGIC - Check if requirements are actually met
      if (widget.isKycRequired && _selectedUserType == 'traveller') {
        // Check if KYC is actually complete
        bool hasAadhaar = _aadhaarController.text.trim().isNotEmpty;
        bool hasLicense = _licenseImage != null ||
            (_isEditMode && widget.existingUserData!['licenseStatus'] == 'uploaded');

        String kycStatus;
        if (hasAadhaar && hasLicense) {
          kycStatus = 'verified'; // ✅ KYC complete - allow trip creation
        } else {
          kycStatus = 'pending'; // ❌ KYC incomplete - block trip creation
        }

        userData.addAll({
          'kycStatus': kycStatus,
          'aadhaar': _aadhaarController.text.trim(),
          'licenseStatus': hasLicense ? 'uploaded' : 'not_uploaded',
        });
      } else if (_selectedUserType == 'traveller') {
        // Traveller without explicit KYC requirement
        bool hasAadhaar = _aadhaarController.text.trim().isNotEmpty;
        bool hasLicense = _licenseImage != null ||
            (_isEditMode && widget.existingUserData!['licenseStatus'] == 'uploaded');

        String kycStatus;
        if (hasAadhaar && hasLicense) {
          kycStatus = 'verified'; // ✅ Optional KYC complete
        } else if (hasAadhaar || hasLicense) {
          kycStatus = 'pending'; // ❌ Partial KYC
        } else {
          kycStatus = 'not_required'; // No KYC provided
        }

        userData['kycStatus'] = kycStatus;
        if (hasAadhaar) {
          userData['aadhaar'] = _aadhaarController.text.trim();
        }
        userData['licenseStatus'] = hasLicense ? 'uploaded' : 'not_uploaded';
      } else {
        userData['kycStatus'] = 'not_required';
      }

      // Save to Firestore (merge for edit mode)
      if (_isEditMode) {
        await _firestore.collection('users').doc(userId).update(userData);
      } else {
        await _firestore.collection('users').doc(userId).set(userData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'Profile updated successfully!' : 'Profile completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      Navigator.of(context).pop(true);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'Failed to update profile: ${e.toString()}' : 'Failed to complete profile: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode ? 'Update Profile' : 'Complete Profile',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  _isEditMode ? 'Update your profile' : 'Set up your profile',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF001127),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isEditMode
                      ? 'Update your information and preferences'
                      : widget.isKycRequired
                      ? 'Complete your profile with KYC to start creating trips'
                      : 'Complete your profile to get started',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),

                // Profile Image Section
                Center(
                  child: GestureDetector(
                    onTap: _pickProfileImage,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: _profileImage != null
                          ? ClipOval(
                        child: Image.file(
                          _profileImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                          : _isEditMode && widget.existingUserData!['profileUrl'] != null &&
                          widget.existingUserData!['profileUrl'].isNotEmpty
                          ? ClipOval(
                        child: Image.network(
                          widget.existingUserData!['profileUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.camera_alt,
                              size: 40,
                              color: Colors.grey,
                            );
                          },
                        ),
                      )
                          : const Icon(
                        Icons.camera_alt,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Tap to add/change profile photo',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Name Field
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name*',
                  hint: 'Enter your full name',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email Field
                _buildTextField(
                  controller: _emailController,
                  label: 'Email*',
                  hint: 'Enter your email address',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // User Type Selection
                const Text(
                  'I am a*',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Sender'),
                        subtitle: const Text('Send packages'),
                        value: 'sender',
                        groupValue: _selectedUserType,
                        onChanged: (value) {
                          setState(() {
                            _selectedUserType = value!;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Traveller'),
                        subtitle: const Text('Carry packages'),
                        value: 'traveller',
                        groupValue: _selectedUserType,
                        onChanged: (value) {
                          setState(() {
                            _selectedUserType = value!;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),

                // KYC Section (shown if required or if user selects traveller)
                if (widget.isKycRequired || _selectedUserType == 'traveller') ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.security, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              'KYC Verification',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.isKycRequired
                              ? 'KYC is required for trip creators to ensure safety and trust.'
                              : _selectedUserType == 'traveller'
                              ? 'KYC is recommended for trip creators to build trust with senders.'
                              : 'KYC verification helps build trust in the community.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Aadhaar Field
                        _buildTextField(
                          controller: _aadhaarController,
                          label: (widget.isKycRequired && _selectedUserType == 'traveller')
                              ? 'Aadhaar Number*'
                              : 'Aadhaar Number (${_selectedUserType == 'traveller' ? 'Recommended' : 'Optional'})',
                          hint: 'Enter your Aadhaar number',
                          keyboardType: TextInputType.number,
                          validator: (widget.isKycRequired && _selectedUserType == 'traveller')
                              ? (value) {
                            if (value == null || value.isEmpty) {
                              return 'Aadhaar number is required for travellers';
                            }
                            if (value.length != 12) {
                              return 'Enter a valid 12-digit Aadhaar number';
                            }
                            return null;
                          }
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // License Upload
                        GestureDetector(
                          onTap: _pickLicenseImage,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  _licenseImage != null ||
                                      (_isEditMode && widget.existingUserData!['licenseStatus'] == 'uploaded')
                                      ? Icons.check_circle
                                      : Icons.upload_file,
                                  size: 40,
                                  color: _licenseImage != null ||
                                      (_isEditMode && widget.existingUserData!['licenseStatus'] == 'uploaded')
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _licenseImage != null
                                      ? 'New license selected'
                                      : _isEditMode && widget.existingUserData!['licenseStatus'] == 'uploaded'
                                      ? 'License already uploaded (tap to change)'
                                      : 'Upload Driving License${(widget.isKycRequired && _selectedUserType == 'traveller') ? '*' : ' (${_selectedUserType == 'traveller' ? 'Recommended' : 'Optional'})'}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _licenseImage != null ||
                                        (_isEditMode && widget.existingUserData!['licenseStatus'] == 'uploaded')
                                        ? Colors.green
                                        : Colors.grey[700],
                                    fontWeight: _licenseImage != null ||
                                        (_isEditMode && widget.existingUserData!['licenseStatus'] == 'uploaded')
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Complete/Update Profile Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF001127),
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _completeProfile,
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Text(
                      _isEditMode ? 'Update Profile' : 'Complete Profile',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Skip Button (only if not editing and KYC is not required)
                if (!_isEditMode && !widget.isKycRequired)
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[500]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF001127), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}