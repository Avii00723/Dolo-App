import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../Models/ReportModel.dart';
import '../Controllers/ReportService.dart';

// ─────────────────────────────────────────────────────────────
// Entry point: Step 1 — Category selection
// ─────────────────────────────────────────────────────────────
class ReportScreen extends StatelessWidget {
  final String reportedUserId;
  final String orderId;

  const ReportScreen({
    super.key,
    required this.reportedUserId,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _ReportAppBar(step: 1, onBack: () => Navigator.pop(context)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          Text(
            'What went wrong?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          ...ReportCategories.all.map(
            (cat) => _CategoryTile(
              label: cat.label,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportStep2Screen(
                    reportedUserId: reportedUserId,
                    orderId: orderId,
                    category: cat,
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

// ─────────────────────────────────────────────────────────────
// Step 2 — Details form
// ─────────────────────────────────────────────────────────────
class ReportStep2Screen extends StatefulWidget {
  final String reportedUserId;
  final String orderId;
  final ReportCategory category;

  const ReportStep2Screen({
    super.key,
    required this.reportedUserId,
    required this.orderId,
    required this.category,
  });

  @override
  State<ReportStep2Screen> createState() => _ReportStep2ScreenState();
}

class _ReportStep2ScreenState extends State<ReportStep2Screen> {
  final _descriptionController = TextEditingController();
  final _reportService = ReportService(); // Instantiate the service
  ReportSubReason? _selectedSubReason;
  File? _attachment;
  bool _isSubmitting = false;
  String? _descriptionError;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _attachment = File(picked.path));
    }
  }

  void _validate() {
    setState(() {
      _descriptionError = _descriptionController.text.trim().length < 20
          ? 'Please describe the issue (min 20 characters)'
          : null;
    });
  }

  Future<void> _submit() async {
    _validate();
    if (_selectedSubReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a sub-reason')),
      );
      return;
    }
    if (_descriptionError != null) return;

    setState(() => _isSubmitting = true);

    // Call the instance method
    final result = await _reportService.createReport(
      reportedUserId: widget.reportedUserId,
      orderId: widget.orderId,
      category: widget.category.key,
      subReason: _selectedSubReason!.key,
      description: _descriptionController.text.trim(),
      attachment: _attachment,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReportSubmittedScreen(
            orderId: widget.orderId,
            categoryLabel: widget.category.label,
            subReasonLabel: _selectedSubReason!.label,
            attachment: _attachment,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Something went wrong'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _ReportAppBar(step: 2, onBack: () => Navigator.pop(context)),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            Text(
              'Describe your ${widget.category.label}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),

            // Order ID (auto-filled)
            _ReadOnlyField(label: 'Order ID (Autofilled)*', value: widget.orderId),
            const SizedBox(height: 16),

            // Sub-reason dropdown
            DropdownButtonFormField<ReportSubReason>(
              value: _selectedSubReason,
              decoration: _inputDecoration(context, 'Select sub-reason*'),
              items: widget.category.subReasons
                  .map(
                    (sr) => DropdownMenuItem(
                      value: sr,
                      child: Text(sr.label),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedSubReason = val),
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              maxLength: 500,
              onChanged: (_) {
                if (_descriptionError != null) _validate();
              },
              decoration: _inputDecoration(
                context,
                'Tell us a bit more... (min 20 characters)*',
              ).copyWith(
                errorText: _descriptionError,
              ),
            ),
            const SizedBox(height: 16),

            // Attachment
            _AttachmentPicker(
              attachment: _attachment,
              onPick: _pickImage,
              onRemove: () => setState(() => _attachment = null),
            ),

            const SizedBox(height: 32),
            _SubmitButton(isSubmitting: _isSubmitting, onTap: _submit),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Step 3 — Submitted confirmation
// ─────────────────────────────────────────────────────────────
class ReportSubmittedScreen extends StatelessWidget {
  final String orderId;
  final String categoryLabel;
  final String subReasonLabel;
  final File? attachment;

  const ReportSubmittedScreen({
    super.key,
    required this.orderId,
    required this.categoryLabel,
    required this.subReasonLabel,
    this.attachment,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _ReportAppBar(
        step: 2, // stays on step 2 indicator as per wireframe
        onBack: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          Text(
            'Enter Details: $subReasonLabel',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),

          _ReadOnlyField(label: 'Order ID (Autofilled)*', value: orderId),
          const SizedBox(height: 20),

          // Image preview or placeholder
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: attachment != null
                  ? Image.file(
                      attachment!,
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 40,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Image',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Confirmation message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Your report has been submitted.\nWe\'ll get back to you shortly on your email ID.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Ok', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 20),

          // Dimmed attachment note
          Row(
            children: [
              Icon(Icons.attach_file, size: 18,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35)),
              const SizedBox(width: 6),
              Text(
                'Add screenshot for evidence (optional)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────

class _ReportAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int step;
  final VoidCallback onBack;

  const _ReportAppBar({required this.step, required this.onBack});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 24);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBack,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Report Issue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text(
            'Step $step of 2',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(4),
        child: LinearProgressIndicator(
          value: step / 2,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          color: Theme.of(context).colorScheme.primary,
          minHeight: 4,
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CategoryTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.25),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      decoration: _inputDecoration(context, label),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      ),
    );
  }
}

class _AttachmentPicker extends StatelessWidget {
  final File? attachment;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _AttachmentPicker({
    required this.attachment,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (attachment != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              attachment!,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
        ),
        child: Row(
          children: [
            Icon(Icons.attach_file,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
            const SizedBox(width: 10),
            Text(
              'Add screenshot for evidence (optional)',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback onTap;

  const _SubmitButton({required this.isSubmitting, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isSubmitting ? null : onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text(
                'Submit Report',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helper
// ─────────────────────────────────────────────────────────────
InputDecoration _inputDecoration(BuildContext context, String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
      fontSize: 13,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.outline.withOpacity(0.25),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.red),
    ),
  );
}
