import 'package:flutter/material.dart';
import '../../Models/TrustScoreModel.dart';

class TrustScoreWidget extends StatelessWidget {
  final TrustScore? trustScore;
  final bool showBreakdown;
  final bool isCompact;

  const TrustScoreWidget({
    Key? key,
    required this.trustScore,
    this.showBreakdown = true,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (trustScore == null) {
      return _buildLoadingState();
    }

    if (isCompact) {
      return _buildCompactView(context);
    }

    return _buildDetailedView(context);
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildCompactView(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trust Score',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF001127),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${trustScore!.trustScore}/${trustScore!.maxScore}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: trustScore!.trustScore / trustScore!.maxScore,
              backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF001127)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedView(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trust Score',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF001127),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${trustScore!.trustScore}/${trustScore!.maxScore}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: trustScore!.trustScore / trustScore!.maxScore,
              backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF001127)),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${trustScore!.completionPercentage}% Complete',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),

          // Breakdown section
          if (showBreakdown)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verification Breakdown',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                _buildBreakdownItem(context,
                  'Phone Verification',
                  trustScore!.phoneVerification,
                  Icons.phone,
                ),
                const SizedBox(height: 8),
                _buildBreakdownItem(context,
                  'Email Verification',
                  trustScore!.emailVerification,
                  Icons.email,
                ),
                const SizedBox(height: 8),
                _buildBreakdownItem(context,
                  'Profile Picture',
                  trustScore!.profileImage,
                  Icons.image,
                ),
                const SizedBox(height: 8),
                _buildBreakdownItem(context,
                  'KYC Verification',
                  trustScore!.kycVerification,
                  Icons.verified_user,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(BuildContext context, String label, int points, IconData icon) {
    final isCompleted = points > 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.shade50 : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? Colors.green.shade300 : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green.shade200 : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 16,
              color: isCompleted ? Colors.green.shade700 : Colors.grey[600],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  isCompleted ? 'Verified' : 'Not verified',
                  style: TextStyle(
                    fontSize: 11,
                    color: isCompleted ? Colors.green : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green.shade100 : Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+$points',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isCompleted ? Colors.green.shade700 : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}