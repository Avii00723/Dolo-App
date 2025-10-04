class ApiConstants {

  static const String baseUrl = 'http://51.20.193.95:3000/api';

  // User
  static const String login = '$baseUrl/users/login';
  static const String verifyOtp = '$baseUrl/users/verify-otp';
  static const String completeProfile = '$baseUrl/users/complete-profile';
  static const String startKyc = '$baseUrl/users/start-kyc';
  static const String getUserProfile = '$baseUrl/users/profile'; // add userId as path param
  static const String updateUserProfile = '$baseUrl/users/profile'; // add userId as path param
  static const String uploadKyc = '$baseUrl/users/upload-kyc';

  // Orders
  static const String createOrder = '$baseUrl/orders/create';
  static const String searchOrders = '$baseUrl/orders/search';
  static const String updateOrder = '$baseUrl/orders/update';
  static const String myOrders = '$baseUrl/orders/myorders';

  // Trip Requests
  static const String sendTripRequest = '$baseUrl/trip-requests/send';
  static const String acceptTripRequest = '$baseUrl/trip-requests/accept';
  static const String getMyTripRequests = '$baseUrl/trip-requests/mytrip';

  // Chat
  static const String sendChatMessage = '$baseUrl/chat/send';
  static const String getChatMessages = '$baseUrl/chat'; // append /{transaction_id}/{user_id}
}
