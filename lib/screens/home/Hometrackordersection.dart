import 'package:flutter/material.dart';
import 'dart:async';

import '../../Controllers/ordertrackingservice.dart';
import '../../Controllers/AuthService.dart';
import '../orderSection/YourOrders.dart';
import '../orderSection/OrderTrackingScreen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point – drop this anywhere on the home screen
// ─────────────────────────────────────────────────────────────────────────────

class HomeTrackOrdersSection extends StatefulWidget {
  /// Called when the user taps "Send a Parcel" on the empty state
  final VoidCallback? onCreateOrder;

  /// Called when the user taps "> Track" on any card
  final VoidCallback? onViewOrders;

  const HomeTrackOrdersSection({
    super.key,
    this.onCreateOrder,
    this.onViewOrders,
  });

  @override
  State<HomeTrackOrdersSection> createState() => _HomeTrackOrdersSectionState();
}

class _HomeTrackOrdersSectionState extends State<HomeTrackOrdersSection> {
  // ── services ──
  final _trackingService = OrderTrackingService();

  // ── state ──
  bool _loading = true;
  String? _userId;

  /// The active order returned by the home-tracking API
  Map<String, dynamic>? _activeOrder;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    // Refresh every 20 s so status updates surface without user action
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && _userId != null) _refresh(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Data loading
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    _userId = await AuthService.getUserId();
    if (_userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    await _refresh();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);

    if (_userId == null) return;

    try {
      final res = await _trackingService.getHomeTracking(_userId!);
      if (mounted) {
        setState(() {
          if (res != null && res['has_active_order'] == true) {
            _activeOrder = res['order'];
          } else {
            _activeOrder = null;
          }
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ HomeTrackOrdersSection refresh error: $e');
      if (mounted) {
        setState(() {
          _activeOrder = null;
          _loading = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _LoadingPlaceholder();
    }

    if (_activeOrder == null) {
      return _EmptyTrackSection(onCreateOrder: widget.onCreateOrder);
    }

    return _ActiveOrderTrackSection(
      order: _activeOrder!,
      onViewOrders: widget.onViewOrders,
      onRatingSubmitted: () => _refresh(silent: true),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyTrackSection extends StatelessWidget {
  final VoidCallback? onCreateOrder;
  const _EmptyTrackSection({this.onCreateOrder});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.local_shipping_outlined, color: primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track Your Orders',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'No active shipments right now',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onCreateOrder,
            style: TextButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Send Parcel',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active Order container (Replacing Carousel since API returns one latest order)
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveOrderTrackSection extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onViewOrders;
  final VoidCallback onRatingSubmitted;

  const _ActiveOrderTrackSection({
    required this.order,
    this.onViewOrders,
    required this.onRatingSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Track Active Order',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              if (onViewOrders != null)
                GestureDetector(
                  onTap: onViewOrders,
                  child: Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _ActiveOrderCard(
          order: order,
          onRatingSubmitted: onRatingSubmitted,
        ),
      ],
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onRatingSubmitted;

  const _ActiveOrderCard({
    required this.order,
    required this.onRatingSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final myRole = order['my_role']?.toString() ?? 'order_sender';
    final isTraveller = myRole == 'traveller';
    
    // Counterpart details
    final counterpart = isTraveller ? order['sender'] : order['traveller'];
    final counterpartName = counterpart?['name'] ?? (isTraveller ? 'Sender' : 'Traveller');

    final status = (order['status'] ?? 'pending').toString().toLowerCase().trim();
    final statusLabel = order['status_label']?.toString() ?? status;
    final showTrackButton = order['show_track_button'] == true;
    final showRatingButton = order['show_rating_button'] == true;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isTraveller ? 'TRAVELLER' : 'SENDER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                ),
              ),
              _StatusBadge(status: statusLabel),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${order['origin']} → ${order['destination']}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          
          // Stepper-like progress dots
          _buildTrackingProgress(context),

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildMiniAvatar(counterpart?['profile_image'], counterpartName),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTraveller ? 'Sender' : 'Traveller',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                      Text(
                        counterpartName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  if (showRatingButton)
                    ElevatedButton(
                      onPressed: () async {
                        // We push to OrderTrackingScreen which already handles the rating dialog 
                        // logic internally when status is delivered.
                        await _navigateToTracking(context, isTraveller);
                        onRatingSubmitted();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[700],
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Rate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  if (showTrackButton) ...[
                    if (showRatingButton) const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _navigateToTracking(context, isTraveller),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Track', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToTracking(BuildContext context, bool isTraveller) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderTrackingScreen(
          orderId: order['order_id'].toString(),
          orderData: {
            'origin': order['origin'],
            'destination': order['destination'],
            'status': order['status'],
            'my_role': order['my_role'],
          },
          isTraveller: isTraveller,
        ),
      ),
    );
  }

  Widget _buildTrackingProgress(BuildContext context) {
    final progress = order['tracking_progress'] as Map<String, dynamic>? ?? {};
    final isConfirmed = progress['confirmed'] == true;
    final isPicked = progress['picked'] == true;
    final isDelivered = progress['delivered'] == true;

    final inactiveColor = Colors.grey[300]!;
    final activeColor = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        _progressDot(activeColor),
        _progressLine(isConfirmed ? activeColor : inactiveColor),
        _progressDot(isConfirmed ? activeColor : inactiveColor),
        _progressLine(isPicked ? activeColor : inactiveColor),
        _progressDot(isPicked ? activeColor : inactiveColor),
        _progressLine(isDelivered ? activeColor : inactiveColor),
        _progressDot(isDelivered ? activeColor : inactiveColor),
      ],
    );
  }

  Widget _progressDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _progressLine(Color color) {
    return Expanded(
      child: Container(
        height: 2,
        color: color,
      ),
    );
  }

  Widget _buildMiniAvatar(String? imageUrl, String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    
    if (imageUrl != null && imageUrl.isNotEmpty) {
      String fullUrl = imageUrl;
      if (!imageUrl.startsWith('http')) {
        // Assuming ApiConstants.imagebaseUrl is available or just using the relative path if configured in image provider
        // For now, using standard NetworkImage
      }
      return CircleAvatar(
        radius: 14,
        backgroundImage: NetworkImage(imageUrl),
        backgroundColor: Colors.grey[200],
      );
    }
    
    return CircleAvatar(
      radius: 14,
      backgroundColor: Colors.grey[300],
      child: Text(
        initial,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.orange;
    final s = status.toLowerCase();
    if (s.contains('transit') || s.contains('picked') || s.contains('time')) {
      color = Colors.blue;
    } else if (s.contains('arrived')) {
      color = Colors.indigo;
    } else if (s.contains('delivered')) {
      color = Colors.green;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          status.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 100,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
