class LoginResponse {
  final String message;
  final String otp;
  final String userId;

  LoginResponse({
    required this.message,
    required this.otp,
    required this.userId,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      message: json['message']?.toString() ?? '',
      otp: json['otp']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
    );
  }
}

class VerifyOtpResponse {
  final String message;
  final String userId;
  final String kycStatus;
  final bool showProfilePrompt;

  VerifyOtpResponse({
    required this.message,
    required this.userId,
    required this.kycStatus,
    required this.showProfilePrompt,
  });

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResponse(
      message: json['message']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      kycStatus: json['kycStatus']?.toString() ?? '',
      showProfilePrompt: json['showProfilePrompt'] ?? false,
    );
  }
}

// For completing profile request and response

class ProfileUpdateRequest {
  final String userId;
  final String name;
  final String email;
  final String aadhaar;
  final String photoURL;

  ProfileUpdateRequest({
    required this.userId,
    required this.name,
    required this.email,
    required this.aadhaar,
    required this.photoURL,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'aadhaar': aadhaar,
      'photoURL': photoURL,
    };
  }
}

class ProfileUpdateResponse {
  final String message;

  ProfileUpdateResponse({required this.message});

  factory ProfileUpdateResponse.fromJson(Map<String, dynamic> json) {
    return ProfileUpdateResponse(
      message: json['message'] ?? '',
    );
  }
}

// For KYC start response

class KycStartResponse {
  final String message;
  final String redirectUrl;

  KycStartResponse({
    required this.message,
    required this.redirectUrl,
  });

  factory KycStartResponse.fromJson(Map<String, dynamic> json) {
    return KycStartResponse(
      message: json['message'] ?? '',
      redirectUrl: json['redirectUrl'] ?? '',
    );
  }
}
class UserProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String kycStatus;
  final String lastLogin;
  final String photoURL;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.kycStatus,
    required this.lastLogin,
    required this.photoURL,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      kycStatus: json['kycStatus'] ?? '',
      lastLogin: json['lastLogin'] ?? '',
      photoURL: json['photoURL'] ?? '',
    );
  }
}
class KycUploadResponse {
  final String message;
  final String kycStatus;
  final String fileURL;

  KycUploadResponse({
    required this.message,
    required this.kycStatus,
    required this.fileURL,
  });

  factory KycUploadResponse.fromJson(Map<String, dynamic> json) {
    return KycUploadResponse(
      message: json['message'] ?? '',
      kycStatus: json['kycStatus'] ?? '',
      fileURL: json['fileURL'] ?? '',
    );
  }
}