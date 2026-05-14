import 'package:flutter/material.dart';

import '../../Controllers/AuthService.dart';
import '../../Controllers/ratingservice.dart';
import '../../Models/RatingModel.dart';

class RatingFeedbackDialog extends StatefulWidget {
  final String orderId;
  final bool isTraveller; // true = Traveller rating Sender, false = Sender rating Traveller
  final String displayName;
  final String? travellerId;
  final Map<String, dynamic>? orderDetails;
  final VoidCallback? onSubmitted;

  const RatingFeedbackDialog({
    super.key,
    required this.orderId,
    required this.isTraveller,
    required this.displayName,
    this.travellerId,
    this.orderDetails,
    this.onSubmitted,
  });

  @override
  State<RatingFeedbackDialog> createState() => _RatingFeedbackDialogState();
}

class _RatingFeedbackDialogState extends State<RatingFeedbackDialog> {
  final RatingService _ratingService = RatingService();
  final TextEditingController _feedbackController = TextEditingController();
  int _selectedRating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  String get _title {
    if (widget.isTraveller) {
      return 'How was ${widget.displayName}\'s Order?';
    }
    return 'How was ${widget.displayName}\'s delivery?';
  }

  String get _subtitle {
    if (widget.isTraveller) {
      return 'Your feedback helps us improve future orders.';
    }
    return 'Your feedback helps us improve future deliveries.';
  }

  List<String> get _chips {
    if (widget.isTraveller) {
      return const [
        'Safe Order',
        'Well-Organised',
        'Good Communication',
        'Clear Instructions',
        'Parcel secured',
      ];
    }
    return const [
      'Safe Driver',
      'Punctual',
      'Comfortable driver',
      'Good Driver',
      'Parcel secured',
    ];
  }

  String get _initials {
    final words = widget.displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return widget.isTraveller ? 'OC' : 'TR';
    if (words.length == 1) {
      return words.first
          .substring(0, words.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  String? _readAny(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return null;
    for (final key in keys) {
      final value = source[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') return value;
    }
    return null;
  }

  Map<String, dynamic>? _readMap(
      Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return null;
    for (final key in keys) {
      final value = source[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  String? _resolveTravellerId(String raterUserId) {
    final explicit = widget.travellerId?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final details = widget.orderDetails;
    final order = _readMap(details, const [
      'order',
      'orderDetails',
      'order_details',
    ]);
    final trip = _readMap(details, const [
      'trip',
      'acceptedTrip',
      'accepted_trip',
      'tripRequest',
      'trip_request',
    ]);

    if (widget.isTraveller) {
      return raterUserId;
    }

    return _readAny(trip, const [
          'traveler_hashed_id',
          'traveller_hashed_id',
          'travelerHashedId',
          'travellerHashedId',
          'traveler_id',
          'traveller_id',
          'user_hashed_id',
          'user_id',
          'delivery_person_id',
          'delivery_person_hashed_id',
          'matched_traveler_id',
          'matched_traveller_id',
          'matchedTravellerId',
          'accepted_traveler_id',
          'accepted_traveller_id',
          'acceptedTravellerId',
        ]) ??
        _readAny(order, const [
          'traveler_hashed_id',
          'traveller_hashed_id',
          'travelerHashedId',
          'travellerHashedId',
          'matched_traveler_id',
          'matched_traveller_id',
          'matchedTravellerId',
          'accepted_traveler_id',
          'accepted_traveller_id',
          'acceptedTravellerId',
          'delivery_person_id',
          'delivery_person_hashed_id',
          'matchedTravellerId',
          'deliveryPersonId',
        ]) ??
        _readAny(details, const [
          'traveler_hashed_id',
          'traveller_hashed_id',
          'travelerHashedId',
          'travellerHashedId',
          'matched_traveler_id',
          'matched_traveller_id',
          'matchedTravellerId',
          'accepted_traveler_id',
          'accepted_traveler_id',
          'acceptedTravellerId',
          'delivery_person_id',
          'delivery_person_hashed_id',
          'deliveryPersonId',
        ]);
  }

  void _toggleSuggestion(String chip) {
    final current = _feedbackController.text.trim();
    final parts = current
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.any((part) => part.toLowerCase() == chip.toLowerCase())) {
      parts.removeWhere((part) => part.toLowerCase() == chip.toLowerCase());
    } else {
      parts.add(chip);
    }

    final updated = parts.join(', ');
    _feedbackController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
    );
    setState(() {});
  }

  bool _isSuggestionSelected(String chip) {
    return _feedbackController.text
        .split(',')
        .map((part) => part.trim().toLowerCase())
        .contains(chip.toLowerCase());
  }

  String _errorMessage(Object error) {
    final text = error.toString();
    if (text.contains('RATING_ALREADY_SUBMITTED')) {
      return 'Rating already submitted for this order.';
    }
    if (text.contains('ORDER_NOT_DELIVERED')) {
      return 'This order must be delivered before rating.';
    }
    if (text.contains('UNAUTHORIZED')) {
      return 'You are not allowed to rate this order.';
    }
    if (text.contains('INVALID_INPUT')) {
      return 'Please check the rating details and try again.';
    }
    return 'Error submitting rating. Please try again.';
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    final raterUserId = await AuthService.getUserId();
    final travellerId =
        raterUserId == null ? null : _resolveTravellerId(raterUserId);

    if (raterUserId == null ||
        raterUserId.isEmpty ||
        travellerId == null ||
        travellerId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to find rating user details')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _ratingService.submitRating(
        RatingRequest(
          orderId: widget.orderId,
          travellerId: travellerId,
          raterId: raterUserId,
          rating: _selectedRating,
          feedback: _feedbackController.text.trim(),
        ),
      );

      if (!mounted) return;
      widget.onSubmitted?.call();
      if (widget.onSubmitted == null && mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(e)), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Stack(
        children: [
          Positioned(
            right: 12,
            top: 12,
            child: IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF999999), size: 24),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFD8D8D8),
                    child: Text(
                      _initials,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor.withOpacity(0.55),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final value = index + 1;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedRating = value),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.star,
                            color: _selectedRating >= value
                                ? const Color(0xFFFFC107)
                                : const Color(0xFFE5E5E5),
                            size: 44,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: _chips.map(
                      (chip) {
                        final selected = _isSuggestionSelected(chip);
                        return InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _toggleSuggestion(chip),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF4A4A4A)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFD0D0D0)),
                            ),
                            child: Text(
                              chip,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.black87,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      },
                    ).toList(),
                  ),
                  const SizedBox(height: 32),
                  const Divider(height: 1),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _feedbackController,
                    minLines: 3,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Write a feedback',
                      hintStyle: TextStyle(
                        color: textColor.withOpacity(0.35),
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRating,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A4A4A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Done',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
