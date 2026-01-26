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
  final String? nextScreen; // Add this field

  VerifyOtpResponse({
    required this.message,
    required this.userId,
    this.nextScreen,
  });

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResponse(
      message: json['message'] ?? '',
      userId: json['userId'] ?? '',
      nextScreen: json['nextScreen'], // Parse this field
    );
  }

  // Add this helper getter
  bool get showProfilePrompt => nextScreen == 'SIGNUP';
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
class SignupRequest {
  final String userId;
  final String name;
  final String? lastName;
  final String email;
  final String? dob;
  final String? gender;
  final bool isEmailVerified;

  SignupRequest({
    required this.userId,
    required this.name,
    required this.lastName,
    required this.email,
    this.dob,
    this.gender,
    this.isEmailVerified = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'last_name': lastName,
      'email': email,
      if (dob != null) 'dob': dob,
      if (gender != null) 'gender': gender,
      'is_email_verified': isEmailVerified,
    };
  }
}

// NEW: Signup Response Model
class SignupResponse {
  final String message;
  final String nextScreen;

  SignupResponse({
    required this.message,
    required this.nextScreen,
  });

  factory SignupResponse.fromJson(Map<String, dynamic> json) {
    return SignupResponse(
      message: json['message'] ?? '',
      nextScreen: json['nextScreen'] ?? '',
    );
  }
}

// UPDATED: Complete Profile Request (now only for profile image)
class CompleteProfileRequest {
  final String userId;
  final String photoURL;

  CompleteProfileRequest({
    required this.userId,
    required this.photoURL,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'photoURL': photoURL,
    };
  }
}

// UPDATED: Complete Profile Response
class CompleteProfileResponse {
  final String message;
  final bool profileCompleted;

  CompleteProfileResponse({
    required this.message,
    required this.profileCompleted,
  });

  factory CompleteProfileResponse.fromJson(Map<String, dynamic> json) {
    return CompleteProfileResponse(
      message: json['message'] ?? '',
      profileCompleted: json['profileCompleted'] ?? false,
    );
  }
}
