import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? profileUrl;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.profileUrl,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  // Mock data - replace with actual API calls
  double rating = 3.5;
  int reviewCount = 40;
  int deliveredOrders = 30;
  int ordersCreated = 160;
  String memberSince = 'Jan 2026';

  Map<String, bool> verifiedInfo = {
    'phone': true,
    'email': true,
    'kyc': true,
  };

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    // TODO: Implement API call to load user profile data
    // For now, using mock data
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).cardColor,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chat Profile',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 16),
            _buildActionButtons(),
            const SizedBox(height: 16),
            _buildVerifiedInformation(),
            const SizedBox(height: 16),
            _buildStatistics(),
            const SizedBox(height: 24),
            _buildReportButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Stack(
            children: [
              _buildProfileAvatar(),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).cardColor, width: 2),
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.userName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          _buildRatingRow(),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    final initial = widget.userName.isNotEmpty
        ? widget.userName[0].toUpperCase()
        : 'U';

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
      ),
      child: widget.profileUrl != null && widget.profileUrl!.isNotEmpty
          ? ClipOval(
        child: Image.network(
          widget.profileUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildInitialAvatar(initial);
          },
        ),
      )
          : _buildInitialAvatar(initial),
    );
  }

  Widget _buildInitialAvatar(String initial) {
    return Center(
      child: Icon(
        Icons.person_outline,
        size: 50,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildRatingRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.star,
          color: Colors.amber.shade600,
          size: 18,
        ),
        const SizedBox(width: 4),
        Text(
          '$rating/4 ($reviewCount reviews)',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement call functionality
                _showSnackBar('Call functionality not implemented yet');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.phone, size: 20),
              label: const Text(
                'Call',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement search functionality
                _showSnackBar('Search functionality not implemented yet');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.search, size: 20),
              label: const Text(
                'Search',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedInformation() {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_user,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                'Verified Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildVerificationItem(
            'Confirmed phone number',
            verifiedInfo['phone'] ?? false,
          ),
          const SizedBox(height: 12),
          _buildVerificationItem(
            'Confirmed email address',
            verifiedInfo['email'] ?? false,
          ),
          const SizedBox(height: 12),
          _buildVerificationItem(
            'Confirmed KYC',
            verifiedInfo['kyc'] ?? false,
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationItem(String text, bool isVerified) {
    return Row(
      children: [
        Icon(
          isVerified ? Icons.check_circle : Icons.cancel,
          size: 20,
          color: isVerified ? Colors.green : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }

  Widget _buildStatistics() {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.local_shipping_outlined,
              label: 'Delivered',
              value: deliveredOrders.toString(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.inventory_2_outlined,
              label: 'Orders Created',
              value: ordersCreated.toString(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.calendar_today_outlined,
              label: 'Member since',
              value: memberSince,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReportButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: () {
          _showReportDialog();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: BorderSide(color: Colors.red.shade300),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: const Icon(Icons.flag_outlined, size: 20),
        label: Text(
          'Report ${widget.userName.split(' ')[0]}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report User'),
        content: const Text(
          'Are you sure you want to report this user? Please provide a reason.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('Report submitted successfully');
              // TODO: Implement report functionality
            },
            child: const Text(
              'Report',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}