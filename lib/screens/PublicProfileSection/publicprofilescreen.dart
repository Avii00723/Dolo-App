import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../Controllers/PublicProfileService.dart';
import '../../Controllers/AuthService.dart';
import '../../Models/PublicProfileModel.dart';
import '../../widgets/ReportScreen.dart'; // adjust path as needed


class PublicProfileScreen extends StatefulWidget {
  final String targetUserHashedId;

  /// Pass orderId when navigating from a chat / order context so the
  /// Report option becomes available. Leave null to hide it (e.g. browsing
  /// from a non-order context).
  final String? orderId;

  /// Pass true only when the order linked to this profile has been accepted.
  /// The Report button is hidden when false, matching backend rules.
  final bool isOrderAccepted;

  const PublicProfileScreen({
    super.key,
    required this.targetUserHashedId,
    this.orderId,
    this.isOrderAccepted = false,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _service = PublicProfileService();

  bool _loading = true;
  String? _error;
  PublicProfileResponse? _data;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final viewerHashedId = await AuthService.getUserId();
      debugPrint(
          '🧪 PublicProfileScreen init - viewerHashedId=$viewerHashedId targetUserHashedId=${widget.targetUserHashedId}');
      if (viewerHashedId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('🌐 Calling PublicProfile endpoint.');
      debugPrint(
          '➡️ userHashedId=${widget.targetUserHashedId} viewerHashedId=$viewerHashedId');

      final res = await _service.getPublicProfile(
        userHashedId: widget.targetUserHashedId,
        viewerHashedId: viewerHashedId,
      );

      if (!mounted) return;
      setState(() {
        _data = res;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  bool get _accepted => _data?.verifiedInformation != null;

  /// Whether the Report option should be shown.
  bool get _canReport =>
      widget.isOrderAccepted &&
          widget.orderId != null &&
          widget.orderId!.isNotEmpty;

  void _openReport() {
    debugPrint(
        '🚩 PublicProfileScreen - opening report for userId=${widget.targetUserHashedId} orderId=${widget.orderId}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportScreen(
          reportedUserId: widget.targetUserHashedId,
          orderId: widget.orderId!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _data == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
        ),
        body: Center(
          child: Text(
            _error ?? 'Failed to load profile',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final data = _data!;
    final memberSinceText =
    DateFormat('MMM d, yyyy').format(data.user.memberSince.toLocal());

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(data.user.name),
        centerTitle: false,
        elevation: 0,
        actions: [
          if (_canReport)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Report', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block, size: 20),
                      SizedBox(width: 12),
                      Text('Block'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'report') _openReport();
                // 'block' handler — wire when block API is ready
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(data, memberSinceText),
          const SizedBox(height: 16),
          if (_accepted) _buildCallMessageOptions(data.permissions),
          _buildRatingsAndFeedback(data),
          const SizedBox(height: 16),
          _buildStatistics(data, memberSinceText),
          if (_accepted) ...[
            const SizedBox(height: 16),
            _buildVerifiedInformation(data.verifiedInformation!),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(PublicProfileResponse data, String memberSinceText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.12),
              child: Text(
                data.user.name.isNotEmpty
                    ? data.user.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.user.name,
                    style:
                    Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Member since $memberSinceText',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCallMessageOptions(PublicProfilePermissions permissions) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: permissions.canCall
                ? OutlinedButton.icon(
              icon: const Icon(Icons.call_outlined),
              label: const Text('Call'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Call action not wired')),
                );
              },
            )
                : OutlinedButton.icon(
              icon: const Icon(Icons.call_outlined),
              label: const Text('Call unavailable'),
              onPressed: null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: permissions.canMessage
                ? OutlinedButton.icon(
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Message'),
              onPressed: () {
                Navigator.pop(context);
              },
            )
                : OutlinedButton.icon(
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Message unavailable'),
              onPressed: null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingsAndFeedback(PublicProfileResponse data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ratings & Feedback',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '${data.statistics.averageRating.toStringAsFixed(1)} average • ${data.statistics.totalReviews} reviews',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.65),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (data.reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No reviews yet'),
            )
          else
            ListView.separated(
              itemCount: data.reviews.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const Divider(height: 18),
              itemBuilder: (context, i) {
                final r = data.reviews[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.raterName,
                      style:
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        for (int s = 1; s <= 5; s++)
                          Icon(
                            s <= r.stars ? Icons.star : Icons.star_border,
                            size: 18,
                            color: Colors.amber.shade700,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          '${r.stars}/5',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r.feedback.isNotEmpty ? r.feedback : '—',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.75),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildVerifiedInformation(VerifiedInformation verified) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verified Information',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _buildVerifiedRow(
              Icons.phone, 'Phone verified', verified.phoneVerified),
          _buildVerifiedRow(
              Icons.email_outlined, 'Email verified', verified.emailVerified),
          _buildVerifiedRow(
              Icons.verified_user_outlined, 'KYC verified', verified.kycVerified),
        ],
      ),
    );
  }

  Widget _buildVerifiedRow(IconData icon, String text, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.cancel,
            size: 20,
            color: ok
                ? Colors.green
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.25),
          ),
          const SizedBox(width: 10),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildStatistics(PublicProfileResponse data, String memberSinceText) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Statistics',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.directions_car,
                  value: data.statistics.deliveredAsTraveller.toString(),
                  label: 'Total deliveries (Traveller)',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  icon: Icons.inventory_2_outlined,
                  value: data.statistics.ordersCreatedAsSender.toString(),
                  label: 'Total orders created (Sender)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _statCard(
            icon: Icons.calendar_today_outlined,
            value: memberSinceText,
            label: 'Member since',
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 20,
              color:
              Theme.of(context).colorScheme.primary.withOpacity(0.75)),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }
}