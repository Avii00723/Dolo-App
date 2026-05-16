// HomeTrackOrdersSection
// Homescreen widget – "Track Your Orders" card carousel
//
// Behaviour per spec (Task 4):
//   • New user (no active orders)  → shows a "Send a Parcel" prompt button
//   • Status == picked_up / in-transit / confirmed / arrived
//       → compact tracking card (order-id + 3-step progress bar)
//         left-card  = traveller view  (Trips posted)
//         right-card = order-sender view (Packages sent)
//   • Status == delivered && rating NOT completed
//       → rating/feedback card
//         left-card  = ORDER SENDER rates traveller
//         right-card = TRAVELLER rates order-sender
//   • Status == delivered && rating completed → card disappears

import 'dart:async';
import 'package:flutter/material.dart';
import '../../Controllers/AuthService.dart';
import '../../Controllers/OrderService.dart';
import '../../Controllers/TripRequestService.dart';
import '../../Controllers/ordertrackingservice.dart';
import '../orderSection/RatingFeedbackDialog.dart';
import '../orderSection/YourOrders.dart';

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
  final _orderService = OrderService();
  final _tripService = TripRequestService();
  final _trackingService = OrderTrackingService();

  // ── state ──
  bool _loading = true;
  String? _userId;

  /// Active sender orders (Packages sent) – only those that are "in-flight"
  List<OrderDisplay> _senderOrders = [];

  /// Active traveller orders (Trips posted) – only those that are "in-flight"
  List<OrderDisplay> _travellerOrders = [];

  Timer? _refreshTimer;

  // ── carousel page index (for dot indicator) ──
  int _pageIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _bootstrap();
    // Refresh every 20 s so status updates surface without user action
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && _userId != null) _refresh(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pageController.dispose();
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

    await Future.wait([
      _loadSenderOrders(),
      _loadTravellerOrders(),
    ]);

    if (mounted) setState(() => _loading = false);
  }

  // ── sender orders ──────────────────────────────────────────────────────────

  Future<void> _loadSenderOrders() async {
    if (_userId == null) return;
    try {
      final raw = await _orderService.getMyOrders(_userId!);

      // Build OrderDisplay list (same logic as YourOrders._loadMyOrders)
      final displays = raw.map((o) => OrderDisplay(
        id: o.id,
        userId: _userId!,
        userName: 'You',
        senderInitial: 'Y',
        origin: o.origin,
        destination: o.destination,
        date: o.deliveryDate,
        deliveryTime: o.deliveryTime,
        itemDescription: o.itemDescription,
        weight: o.weight,
        status: o.status,
        originLatitude: o.originLatitude,
        originLongitude: o.originLongitude,
        destinationLatitude: o.destinationLatitude,
        destinationLongitude: o.destinationLongitude,
        orderType: 'send',
        estimatedDistance: o.distanceKm,
        expectedPrice: o.expectedPrice ?? o.calculatedPrice?.toInt(),
        notes: o.specialInstructions,
        imageUrl: o.imageUrl,
        category: o.category,
        preferenceTransport: o.preferenceTransport,
        isUrgent: o.isUrgent,
        createdAt: o.createdAt,
        otp: o.deliveryOtp,
      )).toList();

      // Enrich with live tracking status + rating flags
      final enriched = await _applyTracking(displays);

      // Keep only cards we should show on the home screen
      final active = enriched.where(_shouldShowOnHome).toList();

      if (mounted) setState(() => _senderOrders = active);
    } catch (_) {
      if (mounted) setState(() => _senderOrders = []);
    }
  }

  // ── traveller orders ───────────────────────────────────────────────────────

  Future<void> _loadTravellerOrders() async {
    if (_userId == null) return;
    try {
      final requests = await _tripService.getMyTripRequests(_userId!);
      final seen = <String>{};
      final displays = <OrderDisplay>[];

      for (final r in requests) {
        if (seen.contains(r.orderId)) continue;
        seen.add(r.orderId);
        final creatorName = r.orderCreatorName?.trim() ?? r.counterpartName?.trim();
        displays.add(OrderDisplay(
          id: r.orderId,
          userId: r.orderId,
          userName: creatorName?.isNotEmpty == true ? creatorName! : 'Order Creator',
          senderInitial: creatorName?.isNotEmpty == true
              ? creatorName![0].toUpperCase()
              : 'O',
          origin: r.source,
          destination: r.destination,
          date: r.travelDate,
          itemDescription: 'Package delivery',
          weight: '0kg',
          status: r.status,
          orderType: 'receive',
          requestStatus: r.status,
          tripRequestId: r.id,
          notes: '${r.vehicleInfo} • Departure: ${r.departureDatetime}',
        ));
      }

      final enriched = await _applyTracking(displays);
      final active = enriched.where(_shouldShowOnHome).toList();

      if (mounted) setState(() => _travellerOrders = active);
    } catch (_) {
      if (mounted) setState(() => _travellerOrders = []);
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  Future<List<OrderDisplay>> _applyTracking(List<OrderDisplay> orders) async {
    return Future.wait(orders.map((order) async {
      try {
        final details = await _trackingService.getOrderDetails(order.id);
        final apiOrder = details?['order'] is Map
            ? Map<String, dynamic>.from(details!['order'] as Map)
            : null;

        String? read(Map<String, dynamic>? src, String key) {
          final v = src?[key]?.toString().trim().toLowerCase();
          return v == null || v.isEmpty || v == 'null' ? null : v;
        }

        final status = read(apiOrder, 'status') ??
            await _trackingService.getCurrentStatus(order.id);

        return order.copyWith(
          status: status ?? order.status,
          requestStatus:
          order.requestStatus == null ? null : status ?? order.requestStatus,
          myRatingStatus: read(apiOrder, 'my_rating_status') ??
              read(details, 'my_rating_status'),
          otherUserRatingStatus: read(apiOrder, 'other_user_rating_status') ??
              read(details, 'other_user_rating_status'),
        );
      } catch (_) {
        return order;
      }
    }));
  }

  /// Show the card when the order is in a trackable or needs-rating state.
  bool _shouldShowOnHome(OrderDisplay o) {
    final s = (o.requestStatus ?? o.status).toLowerCase().trim();
    // Always show trackable statuses
    if (const {
      'confirmed',
      'accepted',
      'matched',
      'picked_up',
      'picked',
      'in-transit',
      'in_transit',
      'arrived',
    }.contains(s)) {
      return true;
    }
    // Show delivered only until rating is done
    if (s == 'delivered') {
      return o.myRatingStatus?.toLowerCase() != 'completed';
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _LoadingPlaceholder();
    }

    // Merge cards: traveller first (spec: left = traveller), sender second (right)
    final cards = <_TrackCard>[
      ..._travellerOrders.map((o) => _TrackCard(order: o, isTraveller: true)),
      ..._senderOrders.map((o) => _TrackCard(order: o, isTraveller: false)),
    ];

    if (cards.isEmpty) {
      return _EmptyTrackSection(onCreateOrder: widget.onCreateOrder);
    }

    return _CarouselTrackSection(
      cards: cards,
      pageController: _pageController,
      pageIndex: _pageIndex,
      userId: _userId,
      trackingService: _trackingService,
      onPageChanged: (i) => setState(() => _pageIndex = i),
      onViewOrders: widget.onViewOrders,
      onRatingSubmitted: () => _refresh(silent: true),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Model that combines an order + role context
// ─────────────────────────────────────────────────────────────────────────────

class _TrackCard {
  final OrderDisplay order;
  final bool isTraveller;
  const _TrackCard({required this.order, required this.isTraveller});
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
// Carousel container
// ─────────────────────────────────────────────────────────────────────────────

class _CarouselTrackSection extends StatelessWidget {
  final List<_TrackCard> cards;
  final PageController pageController;
  final int pageIndex;
  final String? userId;
  final OrderTrackingService trackingService;
  final ValueChanged<int> onPageChanged;
  final VoidCallback? onViewOrders;
  final VoidCallback onRatingSubmitted;

  const _CarouselTrackSection({
    required this.cards,
    required this.pageController,
    required this.pageIndex,
    required this.userId,
    required this.trackingService,
    required this.onPageChanged,
    this.onViewOrders,
    required this.onRatingSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Text(
                'Track Your Orders',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (cards.length > 1)
                _DotIndicator(count: cards.length, active: pageIndex),
            ],
          ),
        ),

        // ── Card PageView ──────────────────────────────────────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final card = cards[pageIndex < cards.length ? pageIndex : 0];
            final maxH = constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight
                : MediaQuery.of(context).size.height;

            // Responsive card sizing to avoid RenderFlex overflows.
            // Delivered/rating needs a bit more vertical space.
            final isDelivered = (card.order.requestStatus ?? card.order.status)
                .toLowerCase()
                .trim() == 'delivered';

            final targetFraction = isDelivered ? 0.35 : 0.25;
            final target = maxH * targetFraction;
            final clamped = target.clamp(
              isDelivered ? 300.0 : 185.0,
              isDelivered ? 420.0 : 280.0,
            );

            return SizedBox(
              height: clamped.toDouble(),
              child: PageView.builder(
                controller: pageController,
                itemCount: cards.length,
                onPageChanged: onPageChanged,
                itemBuilder: (context, i) {
                  final card = cards[i];
                  final s = (card.order.requestStatus ?? card.order.status)
                      .toLowerCase()
                      .trim();
                  if (s == 'delivered') {
                    return _RatingCard(
                      card: card,
                      onRatingSubmitted: onRatingSubmitted,
                    );
                  }
                  return _TrackingCard(
                    card: card,
                    onViewOrders: onViewOrders,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tracking card  (status != delivered)
// ─────────────────────────────────────────────────────────────────────────────

class _TrackingCard extends StatelessWidget {
  final _TrackCard card;
  final VoidCallback? onViewOrders;

  const _TrackingCard({required this.card, this.onViewOrders});

  @override
  Widget build(BuildContext context) {
    final order = card.order;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final status = (order.requestStatus ?? order.status).toLowerCase().trim();
    final step = OrderTrackingService.progressStepFromStatus(status);

    // Short order-id to display  (#GHS43NDNJUD → last 8 chars)
    final displayId = order.id.length > 8
        ? '#${order.id.substring(order.id.length - 8).toUpperCase()}'
        : '#${order.id.toUpperCase()}';

    final onTimeBadge = _isOnTime(order);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: order-id + on-time badge ─────────────────────────
            Row(
              children: [
                Text(
                  displayId,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const Spacer(),
                if (onTimeBadge)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6F0E0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'On time',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A7A43),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Route labels ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    _shortCity(order.origin),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Expanded(
                  child: Text(
                    _shortCity(order.destination),
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Progress bar ──────────────────────────────────────────────
            _ThreeStepProgress(
              step: step,
              activeColor: primary,
              labels: const ['Order confirmed', 'Picked Up', 'Delivered'],
            ),

            const SizedBox(height: 14),

            // ── Bottom row: delivery info + Track button ───────────────────
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 14,
                  backgroundColor: primary.withValues(alpha: 0.15),
                  backgroundImage: order.profileImageUrl != null
                      ? NetworkImage(order.profileImageUrl!)
                      : null,
                  child: order.profileImageUrl == null
                      ? Text(
                    order.senderInitial,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.isTraveller
                            ? 'Created by ${order.userName}'
                            : 'Delivery by ${order.userName}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (order.date.isNotEmpty)
                        Text(
                          _formatDate(order.date),
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Track button
                GestureDetector(
                  onTap: onViewOrders,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.my_location_outlined,
                            size: 14, color: primary),
                        const SizedBox(width: 4),
                        Text(
                          '> Track',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isOnTime(OrderDisplay o) {
    // Treat as on-time unless the status is 'late' (future-proofing).
    // For now, delivered and in-flight orders with a delivery date in
    // the future are "on time".
    try {
      final deliveryDate = DateTime.parse(o.date);
      return !deliveryDate.isBefore(DateTime.now().subtract(const Duration(days: 1)));
    } catch (_) {
      return false;
    }
  }

  String _shortCity(String address) {
    // Return first token before ',' to keep card compact
    return address.split(',').first.trim();
  }

  String _formatDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      const m = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final hour = d.hour.toString().padLeft(2, '0');
      final min = d.minute.toString().padLeft(2, '0');
      return '${d.day} ${m[d.month - 1]} ${d.year} $hour:$min PM';
    } catch (_) {
      return raw.split('T').first;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rating card (status == delivered)
// ─────────────────────────────────────────────────────────────────────────────

class _RatingCard extends StatefulWidget {
  final _TrackCard card;
  final VoidCallback onRatingSubmitted;

  const _RatingCard({
    required this.card,
    required this.onRatingSubmitted,
  });

  @override
  State<_RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends State<_RatingCard> {
  int _hoveredStar = 0;
  int _selectedStar = 0;
  final TextEditingController _feedbackCtrl = TextEditingController();

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  String get _subjectName => widget.card.order.userName.isNotEmpty
      ? widget.card.order.userName
      : (widget.card.isTraveller ? 'Order Creator' : 'Traveller');

  String get _promptText => widget.card.isTraveller
      ? "How was $_subjectName's Order?"
      : "How was $_subjectName's delivery?";

  Future<void> _submit() async {
    if (_selectedStar == 0) return;
    // Open the full RatingFeedbackDialog which handles all API logic.
    // We pass the inline-selected star + feedback as context via the
    // existing dialog interface.  The dialog itself drives the submission.
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RatingFeedbackDialog(
        orderId: widget.card.order.id,
        isTraveller: widget.card.isTraveller,
        displayName: _subjectName,
        travellerId: widget.card.order.matchedTravellerId,
        orderDetails: null,
        onSubmitted: widget.onRatingSubmitted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.card.order;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // Short order-id
    final displayId = order.id.length > 8
        ? '#${order.id.substring(order.id.length - 8).toUpperCase()}'
        : '#${order.id.toUpperCase()}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: order-id + route ─────────────────────────────────────
            Row(
              children: [
                Text(
                  displayId,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // ── Mini progress (all steps done) ──────────────────────────────
            _ThreeStepProgress(
              step: 4, // fully delivered
              activeColor: primary,
              labels: const ['Order confirmed', 'Picked Up', 'Delivered'],
            ),

            const SizedBox(height: 14),
            Divider(height: 1, color: theme.dividerColor),
            const SizedBox(height: 12),

            // ── Rating prompt ────────────────────────────────────────────────
            Text(
              _promptText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),

            // ── Stars ────────────────────────────────────────────────────────
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                final filled =
                    star <= (_hoveredStar > 0 ? _hoveredStar : _selectedStar);
                return GestureDetector(
                  onTap: () => setState(() => _selectedStar = star),
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hoveredStar = star),
                    onExit: (_) => setState(() => _hoveredStar = 0),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        filled ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: filled
                            ? const Color(0xFFFFC107)
                            : Colors.grey.shade400,
                        size: 30,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),

            // ── Feedback text field ──────────────────────────────────────────
            TextField(
              controller: _feedbackCtrl,
              maxLines: 1,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Give feedback (optional)',
                hintStyle: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: primary),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Submit button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedStar > 0 ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Submit',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3-step progress bar  (Order confirmed → Picked Up → Delivered)
// ─────────────────────────────────────────────────────────────────────────────

class _ThreeStepProgress extends StatelessWidget {
  final int step; // 0 = confirmed, 1 = picked up, 2+ = arrived/delivered
  final Color activeColor;
  final List<String> labels;

  const _ThreeStepProgress({
    required this.step,
    required this.activeColor,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    // Map the 0-4 progressStep from OrderTrackingService to a 0-2 visual step
    // 0 = confirmed (step 0)  →  visual 0
    // 1 = picked_up (step 1)  →  visual 1
    // 2 = in-transit (step 2) →  visual 1 (still en route)
    // 3 = arrived (step 3)    →  visual 2
    // 4 = delivered (step 4)  →  visual 2 (fully done)
    final int visualStep;
    if (step <= 0) {
      visualStep = 0;
    } else if (step == 1 || step == 2) {
      visualStep = 1;
    } else {
      visualStep = 2;
    }

    return Column(
      children: [
        // Dots + connecting lines
        Row(
          children: [
            _Dot(active: visualStep >= 0, color: activeColor),
            _Line(active: visualStep >= 1, color: activeColor),
            _Dot(active: visualStep >= 1, color: activeColor),
            _Line(active: visualStep >= 2, color: activeColor),
            _Dot(active: visualStep >= 2, color: activeColor),
          ],
        ),
        const SizedBox(height: 4),
        // Labels
        Row(
          children: labels.asMap().entries.map((entry) {
            final i = entry.key;
            final l = entry.value;
            return Expanded(
              child: Text(
                l,
                textAlign: i == 0
                    ? TextAlign.left
                    : (i == labels.length - 1
                    ? TextAlign.right
                    : TextAlign.center),
                style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  final Color color;
  const _Dot({required this.active, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : Colors.transparent,
        border: Border.all(
          color: active ? color : Colors.grey.shade300,
          width: 1.8,
        ),
      ),
      child: active
          ? const Icon(Icons.check, size: 8, color: Colors.white)
          : null,
    );
  }
}

class _Line extends StatelessWidget {
  final bool active;
  final Color color;
  const _Line({required this.active, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        color: active ? color : Colors.grey.shade300,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page-dot indicator
// ─────────────────────────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  final int count;
  final int active;
  const _DotIndicator({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? primary : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer-style loading placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 140,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}