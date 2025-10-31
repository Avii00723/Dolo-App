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
  static const String getMyTripRequests = '$baseUrl/trip-requests/mytrip';
  static const String deleteTripRequest = '$baseUrl/trip-requests'; // ✅ NEW - Base path for delete

  // Chat
  static const String getChatInbox = '$baseUrl/chat/inbox';
  static const String sendChatMessage = '$baseUrl/chat/send';
  static const String getChatMessages = '$baseUrl/chat';

  // Media - TTS
  static const String ttsStreamUrl = 'https://api.dzdx.in/v1/media/tts/stream';

  // Google Maps API Key
  // ⚠️ IMPORTANT: Replace this with your actual Google Maps API Key
  // Get it from: https://console.cloud.google.com/
  // Required APIs: Directions API, Geocoding API, Maps SDK for Android/iOS
  static const String googleMapsApiKey = 'AIzaSyDQtNoIW22hko1eCS4ItjsO2JvtwDHJwkY';
}