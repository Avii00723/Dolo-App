class PublicProfileResponse {
  final PublicProfileUser user;
  final PublicProfilePermissions permissions;
  final VerifiedInformation? verifiedInformation;
  final PublicProfileStatistics statistics;
  final List<PublicProfileReview> reviews;

  PublicProfileResponse({
    required this.user,
    required this.permissions,
    this.verifiedInformation,
    required this.statistics,
    required this.reviews,
  });

  factory PublicProfileResponse.fromJson(Map<String, dynamic> json) {
    final verifiedJson = json['verified_information'];

    return PublicProfileResponse(
      user: PublicProfileUser.fromJson(json['user'] as Map<String, dynamic>),
      permissions: PublicProfilePermissions.fromJson(
          json['permissions'] as Map<String, dynamic>),
      verifiedInformation: verifiedJson == null
          ? null
          : VerifiedInformation.fromJson(
              verifiedJson as Map<String, dynamic>,
            ),
      statistics: PublicProfileStatistics.fromJson(
          json['statistics'] as Map<String, dynamic>),
      reviews: (json['reviews'] as List<dynamic>? ?? [])
          .map((e) => PublicProfileReview.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PublicProfileUser {
  final String hashedId;
  final String name;
  final DateTime memberSince;

  PublicProfileUser({
    required this.hashedId,
    required this.name,
    required this.memberSince,
  });

  factory PublicProfileUser.fromJson(Map<String, dynamic> json) {
    return PublicProfileUser(
      hashedId: json['hashed_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      memberSince: DateTime.parse(json['member_since']?.toString() ??
          DateTime.fromMillisecondsSinceEpoch(0).toIso8601String()),
    );
  }
}

class PublicProfilePermissions {
  final bool canCall;
  final bool canMessage;

  PublicProfilePermissions({
    required this.canCall,
    required this.canMessage,
  });

  factory PublicProfilePermissions.fromJson(Map<String, dynamic> json) {
    return PublicProfilePermissions(
      canCall: json['can_call'] == true,
      canMessage: json['can_message'] == true,
    );
  }
}

class VerifiedInformation {
  final bool phoneVerified;
  final bool emailVerified;
  final bool kycVerified;

  VerifiedInformation({
    required this.phoneVerified,
    required this.emailVerified,
    required this.kycVerified,
  });

  factory VerifiedInformation.fromJson(Map<String, dynamic> json) {
    return VerifiedInformation(
      phoneVerified: json['phone_verified'] == true,
      emailVerified: json['email_verified'] == true,
      kycVerified: json['kyc_verified'] == true,
    );
  }
}

class PublicProfileStatistics {
  final int totalReviews;
  final double averageRating;
  final int deliveredAsTraveller;
  final int ordersCreatedAsSender;

  PublicProfileStatistics({
    required this.totalReviews,
    required this.averageRating,
    required this.deliveredAsTraveller,
    required this.ordersCreatedAsSender,
  });

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  factory PublicProfileStatistics.fromJson(Map<String, dynamic> json) {
    return PublicProfileStatistics(
      totalReviews: _toInt(json['total_reviews'] ?? 0),
      averageRating: _toDouble(json['average_rating'] ?? 0),
      deliveredAsTraveller: _toInt(json['delivered_as_traveller'] ?? 0),
      ordersCreatedAsSender: _toInt(json['orders_created_as_sender'] ?? 0),
    );
  }

}

class PublicProfileReview {
  final String raterName;
  final int stars;
  final String feedback;

  PublicProfileReview({
    required this.raterName,
    required this.stars,
    required this.feedback,
  });

  factory PublicProfileReview.fromJson(Map<String, dynamic> json) {
    final rawStars = json['stars'];
    final stars = rawStars is num ? rawStars.toInt() : int.tryParse(rawStars?.toString() ?? '') ?? 0;

    return PublicProfileReview(
      raterName: json['rater_name']?.toString() ?? '',
      stars: stars,
      feedback: json['feedback']?.toString() ?? '',
    );
  }
}

