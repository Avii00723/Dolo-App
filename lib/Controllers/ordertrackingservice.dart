import '../Constants/ApiService.dart';
import 'AuthService.dart';

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
      final userHashedId = await AuthService.getUserId();
      final response = await _api.get(
        endpoint,
        queryParameters: {
          if (userHashedId != null) 'userHashedId': userHashedId,
        },
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
    final rawHistory =
        trackingHistory?['history'] ?? trackingHistory?['tracking'];
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
      case 'arrived':
      case 'in-transit':
      case 'in_transit':
        return 2;
      case 'delivered':
        return 3;
      case 'pending':
      default:
        return 0;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PUT /order-tracking/track/{orderHashedId}
  // Stage values:
  // 1 = confirmed
  // 2 = pickup confirmation requested (sender confirmation gates "picked up")
  // 3 = arrived (generates OTP)
  // Stage 4 is delivered and must go through OTP verification.
  // ─────────────────────────────────────────────────────────────

  /// Update order tracking to a given stage.
  Future<bool> updateTrackingStage(String orderId, int stage) async {
    final endpoint = '/order-tracking/track/${Uri.encodeComponent(orderId)}';

    // Allow stages 1..4. Stage 4 (delivered) is typically gated by OTP,
    // but some callers may update it directly so accept it here.
    if (stage < 1 || stage > 4) {
      throw Exception('Invalid tracking stage. Use stages 1–4 only.');
    }

    try {
      final userHashedId = await AuthService.getUserId();
      if (userHashedId == null || userHashedId.isEmpty) {
        throw Exception('User authentication required to update status');
      }

      final response = await _api.put(
        endpoint,
        body: {
          'stage': stage,
          'userHashedId': userHashedId,
        },
        parser: (json) => json,
      );

      // Log response for debugging
      try {
        print('🔁 UPDATE TRACKING RESPONSE (stage $stage): ${response.data}');
      } catch (_) {}

      if (!response.success) {
        print('❌ UPDATE TRACKING FAILED: ${response.error}; details: ${response.details}');
        throw Exception(
            response.error ?? 'Failed to update tracking stage to $stage');
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
    const endpoint = '/order-tracking/track/verify-otp';
    final otpToVerify =
        otp.trim().isEmpty ? developmentDeliveryOtp : otp.trim();

    try {
      final userHashedId = await AuthService.getUserId();
      final response = await _api.post(
        endpoint,
        body: {
          'orderHashedId': orderId,
          'otp': otpToVerify,
          if (userHashedId != null) 'userHashedId': userHashedId,
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

  /// Resends the delivery OTP for an order.
  Future<bool> resendOtp(String orderId) async {
    const endpoint = '/order-tracking/track/resend-otp';
    try {
      final response = await _api.post(
        endpoint,
        body: {'orderHashedId': orderId},
        parser: (json) => json,
      );
      if (!response.success) {
        throw Exception(response.error ?? 'Failed to resend OTP');
      }
      return true;
    } catch (e) {
      print('❌ RESEND OTP EXCEPTION: $e');
      rethrow;
    }
  }

  /// Confirm or reject a traveller pickup request.
  Future<bool> confirmPickup({
    required String orderHashedId,
    required bool confirmed,
    String? userHashedId,
  }) async {
    const endpoint = '/order-tracking/track/confirm-pickup';

    try {
      final currentUserHashedId = userHashedId ?? await AuthService.getUserId();
      if (currentUserHashedId == null || currentUserHashedId.isEmpty) {
        throw Exception('User not authenticated');
      }

      final response = await _api.post(
        endpoint,
        body: {
          'orderHashedId': orderHashedId,
          'confirmed': confirmed,
          'userHashedId': currentUserHashedId,
        },
        parser: (json) => json,
      );

      if (!response.success) {
        throw Exception(
            response.error ?? 'Failed to update pickup confirmation');
      }

      return true;
    } catch (e) {
      print('❌ PICKUP CONFIRMATION EXCEPTION: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // GET /order-tracking/track/{orderHashedId}/details
  // Returns order info, tracking history, and accepted trip vehicle details.
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getOrderDetails(
    String orderHashedId, {
    String? userHashedId,
  }) async {
    final endpoint =
        '/order-tracking/track/${Uri.encodeComponent(orderHashedId)}/details';
    try {
      final currentUserHashedId = userHashedId ?? await AuthService.getUserId();
      final response = await _api.get(
        endpoint,
        queryParameters: {
          if (currentUserHashedId != null && currentUserHashedId.isNotEmpty)
            'userHashedId': currentUserHashedId,
        },
        parser: (json) => json,
      );
      if (response.success) return response.data;
      return null;
    } catch (e) {
      print('❌ GET ORDER DETAILS EXCEPTION: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // GET /order-tracking/track/{orderHashedId}/otp
  // Returns the latest OTP and its expiry for an order.
  // ─────────────────────────────────────────────────────────────

  /// Fetches the current OTP for an order.
  Future<Map<String, dynamic>?> getOrderOtp(String orderHashedId) async {
    final endpoint =
        '/order-tracking/track/${Uri.encodeComponent(orderHashedId)}/otp';
    try {
      final userHashedId = await AuthService.getUserId();
      final response = await _api.get(
        endpoint,
        queryParameters: {
          if (userHashedId != null) 'userHashedId': userHashedId,
        },
        parser: (json) => json,
      );
      if (response.success) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('❌ GET ORDER OTP EXCEPTION: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // GET /orders/home-tracking/{userHashedId}
  // Returns latest active order tracking for homepage
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getHomeTracking(String userHashedId) async {
    final endpoint =
        '/orders/home-tracking/${Uri.encodeComponent(userHashedId)}';
    try {
      final response = await _api.get(
        endpoint,
        parser: (json) => json,
      );
      if (response.success) return response.data;
      return null;
    } catch (e) {
      print('❌ GET HOME TRACKING EXCEPTION: $e');
      return null;
    }
  }

  // Convenience helpers aligned with documentation
  Future<bool> markAsConfirmed(String orderId) =>
      updateTrackingStage(orderId, 1);
  Future<bool> markAsPickedUp(String orderId) =>
      updateTrackingStage(orderId, 2);
  Future<bool> markAsArrived(String orderId) => updateTrackingStage(orderId, 3);
}
