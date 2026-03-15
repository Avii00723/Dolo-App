import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart';
import 'dart:io';
import '../../Controllers/KYCService.dart';
import '../../Models/LoginModel.dart';
import '../home/homepage.dart';
import '../../Widgets/FloatingNotification.dart';
import '../../Constants/colorconstant.dart';

// =============================================================================
// DESIGN PRINCIPLE
//   GooglePlacesAutoCompleteTextFormField calls addListener() on BOTH the
//   TextEditingController AND the FocusNode in its initState. If either has
//   been disposed before initState runs, you get the "used after disposed" crash.
//
//   _PlacesField (StatefulWidget) owns BOTH internally — created in initState,
//   disposed in dispose(). The parent stores only the plain text string and
//   receives updates via callback. No disposed object crosses a mount boundary.
//
//   Unlike CreateOrderPage / SendPage, this field is embedded INLINE in the
//   form — no full-screen overlay — so suggestions appear as the standard
//   GooglePlaces dropdown directly beneath the field.
// =============================================================================

class _PlacesField extends StatefulWidget {
  final String initialText;
  final String hintText;
  final void Function(String text, Position? position) onLocationSelected;

  const _PlacesField({
    super.key,
    required this.initialText,
    required this.hintText,
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
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Position? _makePosition(dynamic prediction) {
    if (prediction.lat == null || prediction.lng == null) return null;
    return Position(
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
  }

  /// Called by the parent to read the current text value (e.g. during validation)
  String get currentText => _controller.text;

  @override
  Widget build(BuildContext context) {
    return GooglePlacesAutoCompleteTextFormField(
      textEditingController: _controller,
      focusNode: _focusNode,
      config: const GoogleApiConfig(
        apiKey: 'AIzaSyBin4hsTqp0DSLCzjmQwuB78hBHZRhG_3Y',
        countries: ['in'],
        fetchPlaceDetailsWithCoordinates: true,
        debounceTime: 400,
      ),
      onPredictionWithCoordinatesReceived: (prediction) {
        final text = prediction.description ?? '';
        setState(() => _controller.text = text);
        widget.onLocationSelected(text, _makePosition(prediction));
      },
      onSuggestionClicked: (prediction) {
        final text = prediction.description ?? '';
        _controller.text = text;
        _controller.selection =
            TextSelection.fromPosition(TextPosition(offset: text.length));
        // Also fire the callback so parent text stays in sync even if
        // coordinates aren't available yet
        widget.onLocationSelected(text, null);
      },
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.35)),
        prefixIcon: Icon(Icons.location_city,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.5)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary, width: 2),
        ),
      ),
    );
  }
}

// =============================================================================
// KycUploadScreen
// =============================================================================
class KycUploadScreen extends StatefulWidget {
  final String userId;
  final String? fullName;
  final String? email;
  final String? phone;

  const KycUploadScreen({
    super.key,
    required this.userId,
    this.fullName,
    this.email,
    this.phone,
  });

  @override
  State<KycUploadScreen> createState() => _KycUploadScreenState();
}

class _KycUploadScreenState extends State<KycUploadScreen> {
  final KycService _kycService = KycService();
  final PageController _pageController = PageController();

  // ── Standard form controllers (safe — never passed to GooglePlaces) ────────
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  final TextEditingController _addressController = TextEditingController();
  late final TextEditingController _emailController;

  // ── Home City: plain string + optional position only ──────────────────────
  // The _PlacesField widget owns the TextEditingController internally.
  // We use a GlobalKey to read the current text during validation.
  final GlobalKey<_PlacesFieldState> _homeCityFieldKey = GlobalKey();
  String _homeCityText = '';
  Position? _homeCityPosition;

  int _currentStep = 0;
  String? _selectedDocumentType;
  File? _selectedFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.fullName);
    _phoneController = TextEditingController(text: widget.phone);
    _emailController = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _pageController.dispose();
    // _PlacesField disposes its own controller + focusNode automatically.
    super.dispose();
  }

  // ── Validation helpers ─────────────────────────────────────────────────────

  /// Returns the current home-city text: prefers the live field value (via key)
  /// but falls back to the last callback-reported string.
  String get _currentHomeCityText =>
      _homeCityFieldKey.currentState?.currentText ?? _homeCityText;

  void _goToNextStep() {
    if (_currentStep == 0) {
      if (_fullNameController.text.trim().isEmpty ||
          _currentHomeCityText.trim().isEmpty ||
          _phoneController.text.trim().isEmpty ||
          _addressController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty) {
        FloatingNotification.show(
          context,
          isSuccess: false,
          title: 'Missing Info',
          subtitle: 'Please fill all fields',
        );
        return;
      }
      setState(() => _currentStep = 1);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_currentStep == 1) {
      if (_selectedDocumentType == null) {
        FloatingNotification.show(
          context,
          isSuccess: false,
          title: 'Selection Required',
          subtitle: 'Please select a document type',
        );
        return;
      }
      _pickFile();
    }
  }

  void _skipKyc() => Navigator.of(context).pop();

  // ── File picker ────────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: false,
      );
      if (result != null) {
        setState(() => _selectedFile = File(result.files.single.path!));
        _uploadKyc();
      }
    } catch (e) {
      if (!mounted) return;
      FloatingNotification.show(
        context,
        isSuccess: false,
        title: 'Error',
        subtitle: 'Error selecting file: $e',
      );
    }
  }

  // ── KYC upload ─────────────────────────────────────────────────────────────

  Future<void> _uploadKyc() async {
    if (_selectedFile == null) {
      FloatingNotification.show(
        context,
        isSuccess: false,
        title: 'Missing File',
        subtitle: 'Please select a document first',
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final response = await _kycService.uploadKyc(
        userId: widget.userId,
        permanentAddress: _addressController.text.trim(),
        homeCity: _currentHomeCityText.trim(),
        file: _selectedFile!,
      );

      if (response != null) {
        if (!mounted) return;
        _showSuccessDialog(response);
      } else {
        if (!mounted) return;
        setState(() => _isUploading = false);
        FloatingNotification.show(
          context,
          isSuccess: false,
          title: 'Upload Failed',
          subtitle: 'KYC upload failed. Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      FloatingNotification.show(
        context,
        isSuccess: false,
        title: 'Error',
        subtitle: 'Upload failed: $e',
      );
    }
  }

  // ── Success dialog ─────────────────────────────────────────────────────────

  void _showSuccessDialog(KycUploadResponse response) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'KYC Uploaded Successfully',
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: ${response.kycStatus}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                response.message,
                style: TextStyle(
                    fontSize: 14,
                    color:
                    Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Your KYC document has been submitted for verification.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) => const HomePageWithNav()),
                    (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF001127),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: const Text('KYC Verification',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) =>
                  setState(() => _currentStep = index),
              children: [
                _buildPersonalInfoPage(),
                _buildIdVerificationPage(),
              ],
            ),
          ),

          // Bottom buttons
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isUploading ? null : _goToNextStep,
                    style: OutlinedButton.styleFrom(
                      padding:
                      const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(
                          color:
                          Theme.of(context).colorScheme.onSurface,
                          width: 2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                            Colors.black),
                      ),
                    )
                        : Text(
                      _currentStep == 1
                          ? 'UPLOAD DOCUMENT'
                          : 'NEXT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isUploading ? null : _skipKyc,
                  child: Text(
                    "I'll do that later",
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.75),
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

  // ── Page 1: Personal Information ───────────────────────────────────────────

  Widget _buildPersonalInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 32),

          // Full Name
          _buildLabel('Full Name'),
          const SizedBox(height: 8),
          _buildTextField(
              controller: _fullNameController,
              hint: 'Enter your full name'),
          const SizedBox(height: 20),

          // Home City — inline Google Places field (no overlay / page switch)
          _buildLabel('Home City'),
          const SizedBox(height: 8),
          // _PlacesField mounts fresh here; it owns controller + focusNode.
          // Suggestions drop down inline — no navigation required.
          _PlacesField(
            key: _homeCityFieldKey,
            initialText: _homeCityText,
            hintText: 'Enter your city',
            onLocationSelected: (text, position) {
              setState(() {
                _homeCityText = text;
                _homeCityPosition = position;
              });
            },
          ),
          const SizedBox(height: 20),

          // Phone Number
          _buildLabel('Phone Number'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _phoneController,
            hint: 'Enter your phone number',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),

          // Permanent Address
          _buildLabel('Permanent Address'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _addressController,
            hint: 'Enter your address',
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          // Email Address
          _buildLabel('Email Address'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _emailController,
            hint: 'Enter your email',
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
    );
  }

  // ── Page 2: ID Verification ────────────────────────────────────────────────

  Widget _buildIdVerificationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ID Verification',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select a document type to confirm your identity',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 32),
          _buildDocumentOption('Aadhar Card'),
          const SizedBox(height: 16),
          _buildDocumentOption('Passport'),
          const SizedBox(height: 16),
          _buildDocumentOption('Drivers License'),
        ],
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: 0.8),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.35)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide:
          BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide:
          BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2),
        ),
      ),
    );
  }

  Widget _buildDocumentOption(String title) {
    final isSelected = _selectedDocumentType == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedDocumentType = title),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.75),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.35),
                  width: 2,
                ),
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check,
                  size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}