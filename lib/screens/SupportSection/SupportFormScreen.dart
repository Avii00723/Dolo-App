import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../Controllers/SupportService.dart';
import '../../Controllers/AuthService.dart';
import '../../Models/SupportTicketModel.dart';

class SupportFormScreen extends StatefulWidget {
  final bool isChatMode; // true = Chat Support, false = Email Support
  final String? orderId; // Optional orderId to auto-populate

  const SupportFormScreen({super.key, required this.isChatMode, this.orderId});

  @override
  State<SupportFormScreen> createState() => _SupportFormScreenState();
}

class _SupportFormScreenState extends State<SupportFormScreen> {
  final SupportService _supportService = SupportService();
  String? _selectedIssueType;
  late final TextEditingController _orderIdController;
  final _descriptionController = TextEditingController();
  File? _attachment;
  bool _isLoading = false;
  bool _submitted = false;
  String? _userId;

  bool get _hasPrefilledOrderId => widget.orderId?.trim().isNotEmpty == true;

  static const _issueTypes = [
    'Late Delivery',
    'Wrong Item Received',
    'Damaged Package',
    'Traveller Not Responding',
    'Payment Issue',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _orderIdController = TextEditingController(text: widget.orderId);
    _loadUser();
  }

  Future<void> _loadUser() async {
    _userId = await AuthService.getUserId();
    setState(() {});
  }

  @override
  void dispose() {
    _orderIdController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _attachment = File(pickedFile.path);
      });
    }
  }

  Future<void> _submit() async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }
    if (_selectedIssueType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a type of issue')),
      );
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final request = CreateTicketRequest(
      userId: _userId!,
      issueType: _selectedIssueType!,
      description: _descriptionController.text.trim(),
      orderId: _orderIdController.text.trim().isEmpty ? null : _orderIdController.text.trim(),
      attachment: _attachment,
    );

    final result = await _supportService.createTicket(request);

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        setState(() => _submitted = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Failed to submit report')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isChatMode ? 'Chat Support' : 'Email Support',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter Details To Chat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '* Indicated required',
                  style: TextStyle(fontSize: 11, color: Colors.red),
                ),
                const SizedBox(height: 20),

                // Type of Issue
                const _FieldLabel(label: '* Type of Issue'),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedIssueType,
                      isExpanded: true,
                      hint: const Text(
                        'Select type of issue',
                        style: TextStyle(color: Colors.black45, fontSize: 14),
                      ),
                      items: _issueTypes
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedIssueType = v),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Order ID
                const _FieldLabel(label: 'Order ID'),
                const SizedBox(height: 6),
                _FormField(
                  controller: _orderIdController,
                  hint: _hasPrefilledOrderId
                      ? 'Order ID added'
                      : 'Enter or select order ID',
                  readOnly: _hasPrefilledOrderId,
                ),

                const SizedBox(height: 16),

                // User ID (autofill)
                const _FieldLabel(label: 'User ID'),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                  ),
                  child: Text(
                    _userId ?? 'Loading...',
                    style: const TextStyle(fontSize: 14, color: Colors.black45),
                  ),
                ),

                const SizedBox(height: 16),

                // Description
                const _FieldLabel(label: '* Description'),
                const SizedBox(height: 6),
                _FormField(
                  controller: _descriptionController,
                  hint: 'Describe your issue...',
                  maxLines: 4,
                ),

                const SizedBox(height: 16),

                // Add attachment
                GestureDetector(
                  onTap: _pickImage,
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file, size: 20, color: Colors.black54),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _attachment == null ? 'Add attachment' : 'Attachment: ${_attachment!.path.split('/').last}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            decoration: TextDecoration.underline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_attachment != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Colors.red),
                          onPressed: () => setState(() => _attachment = null),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            widget.isChatMode ? 'Start Chatting' : 'Submit',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),

          // ── Success overlay ──
          if (_submitted)
            GestureDetector(
              onTap: () {},
              child: Container(
                color: Colors.black26,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              size: 36, color: Colors.black87),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Your report has been submitted.\nWe will get back to you shortly.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black87,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: const Text('OK',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final bool readOnly;

  const _FormField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        filled: true,
        fillColor: readOnly ? Colors.grey[100] : Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black87, width: 1.5),
        ),
      ),
    );
  }
}
