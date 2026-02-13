class TrustScore {
  final int trustScore;
  final int maxScore;
  final Map<String, dynamic> breakdown;

  TrustScore({
    required this.trustScore,
    required this.maxScore,
    required this.breakdown,
  });

  factory TrustScore.fromJson(Map<String, dynamic> json) {
    return TrustScore(
      trustScore: json['trust_score'] ?? json['trustScore'] ?? 0,
      maxScore: json['max_score'] ?? json['maxScore'] ?? 7,
      breakdown: Map<String, dynamic>.from(json['breakdown'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trustScore': trustScore,
      'maxScore': maxScore,
      'breakdown': breakdown,
    };
  }

  // Helper getters for breakdown values
  int get phoneVerification => breakdown['phone'] as int? ?? 0;
  int get emailVerification => breakdown['email'] as int? ?? 0;
  int get profileImage => breakdown['profile_image'] as int? ?? 0;
  int get kycVerification => breakdown['kyc'] as int? ?? 0;

  // Get percentage of completion
  int get completionPercentage {
    if (maxScore == 0) return 0;
    return ((trustScore / maxScore) * 100).round();
  }

  // Check if specific verification is completed
  bool get isPhoneVerified => phoneVerification > 0;
  bool get isEmailVerified => emailVerification > 0;
  bool get isProfileImageUploaded => profileImage > 0;
  bool get isKycVerified => kycVerification > 0;
}

