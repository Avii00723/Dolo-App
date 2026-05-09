/// RatingModel.dart
/// Complete data models for Rating functionality

/// Request model for submitting a rating
class RatingRequest {
  final String orderId; // Order being rated
  final String travellerId; // Traveller assigned to the order
  final String raterId; // User submitting the rating
  final int rating; // Rating value: 1-5 stars (mandatory)
  final String? feedback; // Optional feedback text

  RatingRequest({
    required this.orderId,
    required this.travellerId,
    required this.raterId,
    required this.rating,
    this.feedback,
  }) : assert(rating >= 1 && rating <= 5, 'Rating must be between 1 and 5');

  Map<String, dynamic> toJson() {
    final map = {
      'order_id': orderId,
      'traveller_id': travellerId,
      'rater_id': raterId,
      'rating': rating,
    };

    // Only include feedback if it's not null or empty
    if (feedback != null && feedback!.trim().isNotEmpty) {
      map['feedback'] = feedback!.trim();
    }

    print('📤 Rating Request JSON: $map');
    return map;
  }

  /// Validate rating data before submission
  bool isValid() {
    return orderId.isNotEmpty &&
        travellerId.isNotEmpty &&
        raterId.isNotEmpty &&
        rating >= 1 &&
        rating <= 5;
  }
}

/// Response model after submitting a rating
class RatingResponse {
  final bool success;
  final String message;
  final String? error;

  RatingResponse({
    required this.success,
    required this.message,
    this.error,
  });

  factory RatingResponse.fromJson(Map<String, dynamic> json) {
    return RatingResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? 'Rating submitted successfully',
      error: json['error']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      if (error != null) 'error': error,
    };
  }
}


/// Rating model for displaying rating data
class Rating {
  final String id; // Rating unique ID
  final String orderId; // Associated order ID
  final String raterUserId; // User who gave the rating
  final String ratedUserId; // User who received the rating
  final int rating; // Rating value (1-5)
  final String? feedback; // Feedback text
  final String createdAt; // Timestamp when rating was created

  Rating({
    required this.id,
    required this.orderId,
    required this.raterUserId,
    required this.ratedUserId,
    required this.rating,
    this.feedback,
    required this.createdAt,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: json['id']?.toString() ?? '',
      orderId:
          json['order_id']?.toString() ?? json['orderId']?.toString() ?? '',
      raterUserId:
          json['rater_id']?.toString() ?? json['raterUserId']?.toString() ?? '',
      ratedUserId: json['rated_user_id']?.toString() ??
          json['ratedUserId']?.toString() ??
          json['traveller_id']?.toString() ??
          '',
      rating: _parseInt(json['rating']),
      feedback: json['feedback'],
      createdAt:
          json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'raterUserId': raterUserId,
      'ratedUserId': ratedUserId,
      'rating': rating,
      'feedback': feedback,
      'createdAt': createdAt,
    };
  }

  /// Helper method to parse rating value
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Get rating as a formatted string (e.g., "4.0 stars")
  String get ratingText => '$rating.0 stars';

  /// Check if rating has feedback
  bool get hasFeedback => feedback != null && feedback!.trim().isNotEmpty;
}

/// User rating statistics (optional - for displaying user's overall rating)
class UserRatingStats {
  final String userId;
  final double averageRating; // Average rating (e.g., 4.2)
  final int totalRatings; // Total number of ratings received
  final Map<int, int> ratingDistribution; // Distribution of ratings (1-5 stars)

  UserRatingStats({
    required this.userId,
    required this.averageRating,
    required this.totalRatings,
    required this.ratingDistribution,
  });

  factory UserRatingStats.fromJson(Map<String, dynamic> json) {
    // Parse rating distribution
    Map<int, int> distribution = {};
    if (json['ratingDistribution'] != null) {
      final distData = json['ratingDistribution'] as Map<String, dynamic>;
      distData.forEach((key, value) {
        final starCount = int.tryParse(key) ?? 0;
        final count =
            value is int ? value : int.tryParse(value.toString()) ?? 0;
        distribution[starCount] = count;
      });
    }

    return UserRatingStats(
      userId: json['userId']?.toString() ?? '',
      averageRating: _parseDouble(json['averageRating']),
      totalRatings: _parseInt(json['totalRatings']),
      ratingDistribution: distribution,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'averageRating': averageRating,
      'totalRatings': totalRatings,
      'ratingDistribution': ratingDistribution,
    };
  }

  /// Get percentage of 5-star ratings
  double get fiveStarPercentage {
    if (totalRatings == 0) return 0.0;
    final fiveStarCount = ratingDistribution[5] ?? 0;
    return (fiveStarCount / totalRatings) * 100;
  }

  /// Format average rating as string (e.g., "4.2")
  String get formattedAverageRating => averageRating.toStringAsFixed(1);

  /// Helper methods
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Rating filter options (for filtering ratings list)
enum RatingFilter {
  all,
  fiveStar,
  fourStar,
  threeStar,
  twoStar,
  oneStar,
  withFeedback,
  withoutFeedback;

  String get displayName {
    switch (this) {
      case RatingFilter.all:
        return 'All Ratings';
      case RatingFilter.fiveStar:
        return '5 Stars';
      case RatingFilter.fourStar:
        return '4 Stars';
      case RatingFilter.threeStar:
        return '3 Stars';
      case RatingFilter.twoStar:
        return '2 Stars';
      case RatingFilter.oneStar:
        return '1 Star';
      case RatingFilter.withFeedback:
        return 'With Feedback';
      case RatingFilter.withoutFeedback:
        return 'Without Feedback';
    }
  }
}

/// Rating sort options
enum RatingSortBy {
  newest,
  oldest,
  highestRating,
  lowestRating;

  String get displayName {
    switch (this) {
      case RatingSortBy.newest:
        return 'Newest First';
      case RatingSortBy.oldest:
        return 'Oldest First';
      case RatingSortBy.highestRating:
        return 'Highest Rating';
      case RatingSortBy.lowestRating:
        return 'Lowest Rating';
    }
  }
}
