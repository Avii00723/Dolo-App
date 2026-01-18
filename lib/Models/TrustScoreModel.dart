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
      trustScore: json['trustScore'] ?? 0,
      maxScore: json['maxScore'] ?? 7,
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
}
