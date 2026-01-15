class ApiConstants {
  static const String baseUrl = 'http://51.20.193.95:3000/api';
  static const String imagebaseUrl = 'http://51.20.193.95:3000';

  // User
  static const String login = '$baseUrl/users/login';
  static const String verifyOtp = '$baseUrl/users/verify-otp';
  static const String completeProfile = '$baseUrl/users/complete-profile';
  static const String startKyc = '$baseUrl/users/start-kyc';
  static const String getUserProfile = '$baseUrl/users/profile';
  static const String updateUserProfile = '$baseUrl/users/profile';
  static const String uploadKyc = '$baseUrl/users/upload-kyc';

  // Orders
  static const String createOrder = '$baseUrl/orders/create';
  static const String searchOrders = '$baseUrl/orders/search';
  static const String updateOrder = '$baseUrl/orders/update';
  static const String myOrders = '$baseUrl/orders/myorders';
  static const String completeOrder = '$baseUrl/orders/complete';
  static const String deleteOrder = '$baseUrl/orders/delete';

  // Trip Requests
  static const String sendTripRequest = '$baseUrl/trip-requests/send';
  static const String acceptTripRequest = '$baseUrl/trip-requests/accept';
  static const String withdrawTripRequest = '$baseUrl/trip-requests/withdraw';
  static const String declineTripRequest = '$baseUrl/trip-requests/decline';
  static const String completeTripRequest = '$baseUrl/trip-requests/complete';
  static const String getMyTripRequests =
      '$baseUrl/trip-requests/mytrip'; // Returns all trip requests related to user (filters on backend)
  static const String deleteTripRequest =
      '$baseUrl/trip-requests'; // Base path for delete

  // Chat
  static const String getChatInbox = '$baseUrl/chat/inbox';
  static const String sendChatMessage = '$baseUrl/chat/send';
  static const String getChatMessages = '$baseUrl/chat';

  // Notifications
  static const String getNotifications = '$baseUrl/notifications';
  static const String markNotificationAsRead = '$baseUrl/notifications';

  // Device Tokens
  static const String saveDeviceToken = '$baseUrl/device/save';

  // Media - TTS
  static const String ttsStreamUrl = 'https://api.dzdx.in/v1/media/tts/stream';
  static const String submitRating = '$baseUrl/ratings';
  static const String getUserRatings = '$baseUrl/ratings/user';
  // Google Maps API Key
  // ⚠️ IMPORTANT: Replace this with your actual Google Maps API Key
  // Get it from: https://console.cloud.google.com/
  // Required APIs: Directions API, Geocoding API, Maps SDK for Android/iOS
  static const String googleMapsApiKey =
      'AIzaSyD1p7YCYS0TKCVDqJSGU_x2nJgquJy92Es';
}
