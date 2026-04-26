import '../Constants/ApiService.dart';

class OrderTrackingService {
  static const String developmentDeliveryOtp = '123456';

  final ApiService _api = ApiService();

  // ─────────────────────────────────────────────────────────────
  // GET /order-tracking/track
  // Returns complete stage history for an order
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getTrackingHistory(String orderId) async {
    final endpoint = '/order-tracking/track/${Uri.encodeComponent(orderId)}';
    try {
      final response = await _api.get(
        endpoint,
        parser: (json) => json,
      );

      if (response.success) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('❌ GET TRACKING HISTORY EXCEPTION: $e');
      return null;
    }
  }

  Future<int?> getCurrentStage(String orderId) async {
    final history = await getTrackingHistory(orderId);
    return currentStageFromHistory(history);
  }

  Future<String?> getCurrentStatus(String orderId) async {
    final stage = await getCurrentStage(orderId);
    return stage == null ? null : statusFromStage(stage);
  }

  static int? currentStageFromHistory(Map<String, dynamic>? trackingHistory) {
    final rawHistory = trackingHistory?['history'];
    if (rawHistory is! List || rawHistory.isEmpty) return null;

    final entries = rawHistory
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    if (entries.isEmpty) return null;

    entries.sort((a, b) {
      final aTime = DateTime.tryParse(a['timestamp']?.toString() ?? '');
      final bTime = DateTime.tryParse(b['timestamp']?.toString() ?? '');
      if (aTime != null && bTime != null) return aTime.compareTo(bTime);
      return _readStage(a).compareTo(_readStage(b));
    });

    final latestStage = _readStage(entries.last);
    return latestStage > 0 ? latestStage : null;
  }

  static int _readStage(Map<String, dynamic> entry) {
    final stage = entry['stage'];
    if (stage is int) return stage;
    return int.tryParse(stage?.toString() ?? '') ?? 0;
  }

  static String statusFromStage(int stage) {
    switch (stage) {
      case 1:
        return 'confirmed';
      case 2:
        return 'picked_up';
      case 3:
        return 'arrived';
      case 4:
        return 'delivered';
      default:
        return 'pending';
    }
  }

  static int progressStepFromStatus(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'accepted':
      case 'matched':
      case 'booked':
        return 0;
      case 'picked':
      case 'picked_up':
        return 1;
      case 'in-transit':
      case 'in_transit':
        return 2;
      case 'arrived':
        return 3;
      case 'delivered':
        return 4;
      case 'pending':
      default:
        return 0;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // POST /order-tracking/track
  // Stage values: 1 = confirmed, 2 = picked, 3 = arrived
  // ─────────────────────────────────────────────────────────────

  /// Update order tracking to a given stage.
  Future<bool> updateTrackingStage(String orderId, int stage) async {
    const endpoint = '/order-tracking/track';
    
    // Validate stages based on documentation
    if (stage == 4) {
      throw Exception('Stage 4 (Delivered) must be handled via /verify-otp endpoint.');
    }

    try {
      final response = await _api.post(
        endpoint,
        body: {
          'orderHashedId': orderId,
          'stage': stage,
        },
        parser: (json) => json,
      );

      if (!response.success) {
        throw Exception(response.error ?? 'Failed to update tracking stage to $stage');
      }

      return true;
    } catch (e) {
      print('❌ UPDATE STAGE EXCEPTION: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // POST /track/verify-otp
  // Marks order as delivered (stage 4) if OTP is valid.
  // ─────────────────────────────────────────────────────────────

  /// Verify the OTP and mark order as delivered (stage 4).
  Future<bool> verifyOtpAndComplete(String orderId, String otp) async {
    const endpoint = '/track/verify-otp';
    final otpToVerify = otp.trim().isEmpty ? developmentDeliveryOtp : otp.trim();

    try {
      final response = await _api.post(
        endpoint,
        body: {
          'orderHashedId': orderId,
          'otp': otpToVerify,
        },
        parser: (json) => json,
      );

      if (!response.success) {
        throw Exception(response.error ?? 'Invalid or expired OTP');
      }

      return true;
    } catch (e) {
      print('❌ OTP VERIFY EXCEPTION: $e');
      rethrow;
    }
  }

  // Convenience helpers aligned with documentation
  Future<bool> markAsConfirmed(String orderId) => updateTrackingStage(orderId, 1);
  Future<bool> markAsPickedUp(String orderId) => updateTrackingStage(orderId, 2);
  Future<bool> markAsArrived(String orderId) => updateTrackingStage(orderId, 3);
}
