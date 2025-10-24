import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../Controllers/LoginService.dart';
import '../../Controllers/AuthService.dart'; // ✅ Import AuthService
import '../../Models/LoginModel.dart';
import 'package:dolo/screens/home/homepage.dart';

class SignupScreen extends StatefulWidget {
  final bool isKycRequired;
  final String? userId;

  const SignupScreen({
    Key? key,
    this.isKycRequired = false,
    this.userId,
  }) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final LoginService _loginService = LoginService();

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _aadhaarController = TextEditingController();

  // KYC Document handling
  File? _aadhaarDocument;
  String? _documentType;
  String? _documentName;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _aadhaarController.dispose();
    super.dispose();
  }

  // ✅ LOAD USER ID FROM SECURE STORAGE
  Future<void> _loadUserId() async {
    try {
      // First check if userId was passed as parameter
      if (widget.userId != null && widget.userId!.isNotEmpty) {
        setState(() {
          _currentUserId = widget.userId;
        });
        debugPrint('✅ UserId loaded from parameter: ${widget.userId}');
        return;
      }

      // ✅ Load from AuthService (secure storage)
      final userId = await AuthService.getUserId();
      setState(() {
        _currentUserId = userId;
      });
      debugPrint('✅ UserId loaded from secure storage: $userId');
    } catch (e) {
      debugPrint('❌ Error loading userId: $e');
    }
  }

  Future<void> _pickAadhaarDocument() async {
    try {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Upload Aadhaar Document'),
          content: const Text('Choose how to upload your Aadhaar document'),
          actions: [
            // Camera option
            TextButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
              onPressed: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                );
                if (image != null) {
                  setState(() {
                    _aadhaarDocument = File(image.path);
                    _documentType = 'image';
                    _documentName = image.name;
                  });
                  debugPrint('✅ Aadhaar image captured from camera: ${image.path}');
                }
              },
            ),
            // Gallery option
            TextButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
              onPressed: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                if (image != null) {
                  setState(() {
                    _aadhaarDocument = File(image.path);
                    _documentType = 'image';
                    _documentName = image.name;
                  });
                  debugPrint('✅ Aadhaar image selected from gallery: ${image.path}');
                }
              },
            ),
            // PDF option
            TextButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF File'),
              onPressed: () async {
                Navigator.pop(context);
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                );
                if (result != null && result.files.single.path != null) {
                  setState(() {
                    _aadhaarDocument = File(result.files.single.path!);
                    _documentType = 'pdf';
                    _documentName = result.files.single.name;
                  });
                  debugPrint('✅ Aadhaar PDF selected: ${result.files.single.path}');
                }
              },
            ),
          ],
        ),
      );
    } catch (e) {
      _showSnackBar('Error picking document: $e', isError: true);
    }
  }

  // ✅ SUBMIT PROFILE AND SAVE TO SECURE STORAGE
  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_aadhaarDocument == null) {
      _showSnackBar('Please upload Aadhaar document (image or PDF)', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get userId from multiple sources
      String? userId = _currentUserId ?? widget.userId;
      if (userId == null || userId.isEmpty) {
        userId = await AuthService.getUserId();
      }

      debugPrint('=== Submit Profile Started ===');
      debugPrint('UserId: $userId');

      if (userId == null || userId.isEmpty) {
        _showSnackBar('User not authenticated. Please login again.', isError: true);
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Step 1: Update profile
      debugPrint('Step 1: Updating profile...');
      final profileRequest = ProfileUpdateRequest(
        userId: userId,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        aadhaar: _aadhaarController.text.trim(),
        photoURL: '',
      );

      final profileResult = await _loginService.completeProfile(profileRequest);
      if (profileResult == null) {
        throw Exception('Failed to update profile');
      }

      debugPrint('✅ Profile updated successfully');

      // Step 2: Upload KYC
      debugPrint('Step 2: Uploading KYC document ($_documentType)...');
      final kycResult = await _loginService.uploadKycDocument(
        userId,
        _aadhaarDocument!,
      );

      if (kycResult == null) {
        debugPrint('❌ KYC upload returned null');
        _showSnackBar(
          'Profile created but KYC upload failed. Please try again from profile settings.',
          isError: true,
        );
      } else {
        debugPrint('✅ KYC uploaded successfully!');
        debugPrint('KYC Status: ${kycResult.kycStatus}');

        // ✅ ENSURE USER SESSION IS SAVED TO SECURE STORAGE
        final phone = await AuthService.getPhone();
        if (phone != null) {
          await AuthService.saveUserSession(
            userId: userId,
            phone: phone,
          );
          debugPrint('✅ User session confirmed in secure storage');
        }

        _showSnackBar(
          'Profile and KYC submitted successfully! Status: ${kycResult.kycStatus}',
        );
      }

      // Navigate to home
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePageWithNav()),
              (route) => false,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error in _submitProfile: $e');
      debugPrint('Stack trace: $stackTrace');
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildDocumentPreview() {
    if (_aadhaarDocument == null) return const SizedBox.shrink();

    if (_documentType == 'pdf') {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.red[700], size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _documentName ?? 'document.pdf',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PDF Document',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () {
                setState(() {
                  _aadhaarDocument = null;
                  _documentType = null;
                  _documentName = null;
                });
              },
            ),
          ],
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _aadhaarDocument!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.red,
                radius: 16,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, color: Colors.white, size: 16),
                  onPressed: () {
                    setState(() {
                      _aadhaarDocument = null;
                      _documentType = null;
                      _documentName = null;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF001127),
        title: const Text(
          'Complete Profile & KYC',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Complete your profile and upload Aadhaar',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF001127),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Fill in your details and upload Aadhaar document (image or PDF) to complete KYC',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'Enter your full name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF001127), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email *',
                    hintText: 'Enter your email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF001127), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _aadhaarController,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  decoration: InputDecoration(
                    labelText: 'Aadhaar Number *',
                    hintText: 'Enter your 12-digit Aadhaar',
                    prefixIcon: const Icon(Icons.credit_card),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF001127), width: 2),
                    ),
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your Aadhaar number';
                    }
                    if (value.trim().length != 12) {
                      return 'Aadhaar must be 12 digits';
                    }
                    if (!RegExp(r'^[0-9]+$').hasMatch(value.trim())) {
                      return 'Aadhaar must contain only numbers';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.upload_file, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          const Text(
                            'Aadhaar Document *',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload Aadhaar as image (JPG/PNG) or PDF file',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickAadhaarDocument,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _aadhaarDocument != null ? Colors.green : Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _aadhaarDocument != null ? Icons.check_circle : Icons.upload_file,
                                color: _aadhaarDocument != null ? Colors.green : Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _aadhaarDocument != null
                                      ? 'Document Selected ✓ (${_documentType?.toUpperCase()})'
                                      : 'Tap to Upload Aadhaar (Image or PDF)',
                                  style: TextStyle(
                                    color: _aadhaarDocument != null ? Colors.green : Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _buildDocumentPreview(),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF001127),
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                      : const Text(
                    'Submit Profile & KYC',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!widget.isKycRequired)
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomePageWithNav(),
                        ),
                      );
                    },
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
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
