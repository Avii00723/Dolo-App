import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../Constants/colorconstant.dart';
import '../../Constants/ApiConstants.dart';
import '../../Models/OrderModel.dart';
import '../../Controllers/TripRequestService.dart';

import '../Widgets/sendtriprequestpage.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Responsive Helper
// ═══════════════════════════════════════════════════════════════════════════
class _R {
  final double w;

  const _R(this.w);

  factory _R.of(BuildContext context) =>
      _R(MediaQuery.of(context).size.width);

  /// Scale a value relative to a 390-wide baseline
  double s(double base) => (base * w / 390).clamp(base * 0.78, base * 1.18);

  // ── Font sizes ─────────────────────────────────────────────────────────
  double get fontXS => s(10);
  double get fontSM => s(11);
  double get fontBase => s(12);
  double get fontMD => s(13);
  double get fontLG => s(14);
  double get fontXL => s(15);
  double get font2XL => s(16);
  double get font3XL => s(17);
  double get font4XL => s(18);
  double get font5XL => s(20);
  double get font6XL => s(22);

  // ── Spacing ────────────────────────────────────────────────────────────
  double get sp2 => s(2);
  double get sp4 => s(4);
  double get sp6 => s(6);
  double get sp8 => s(8);
  double get sp10 => s(10);
  double get sp12 => s(12);
  double get sp14 => s(14);
  double get sp16 => s(16);
  double get sp20 => s(20);
  double get sp24 => s(24);
  double get sp28 => s(28);
  double get sp32 => s(32);

  // ── Component sizes ────────────────────────────────────────────────────
  double get avatarSM => s(36);
  double get avatarMD => s(52);
  double get iconSM => s(13);
  double get iconMD => s(15);
  double get iconLG => s(18);
  double get iconXL => s(20);
  double get dotSM => s(6);
  double get dotMD => s(8);
  double get chipDot => s(6);
  double get borderRadius => s(12);
  double get cardRadius => s(20);
  double get badgeRadius => s(6);
  double get chipRadius => s(10);
  double get buttonRadius => s(16);
}

// ═══════════════════════════════════════════════════════════════════════════
// Enums
// ═══════════════════════════════════════════════════════════════════════════
enum SearchFilter { all, urgentDelivery, preferredMode }

enum SortOption { newest, priceHighToLow, preferredVehicle }

// ═══════════════════════════════════════════════════════════════════════════
// SearchResultsPage
// ═══════════════════════════════════════════════════════════════════════════
class SearchResultsPage extends StatefulWidget {
  final List<Order> orders;
  final String fromLocation;
  final String toLocation;
  final String date;
  final String searchedVehicle;
  final Function(Order) onSendRequest;
  final String departureDate;
  final String departureTime;
  final String deliveryDate;
  final String deliveryTime;
  final String currentUserId;
  final TripRequestService tripRequestService;

  const SearchResultsPage({
    super.key,
    required this.orders,
    required this.fromLocation,
    required this.toLocation,
    required this.date,
    required this.searchedVehicle,
    required this.onSendRequest,
    required this.departureDate,
    required this.departureTime,
    required this.deliveryDate,
    required this.deliveryTime,
    required this.currentUserId,
    required this.tripRequestService,
  });

  static String formatTimeForDisplay(String? time) {
    if (time == null || time.isEmpty || time == 'N/A') return 'N/A';
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        hour = hour % 12;
        if (hour == 0) hour = 12;
        return '$hour:${minute.toString().padLeft(2, '0')} $period';
      }
      return time;
    } catch (_) {
      return time;
    }
  }

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage>
    with SingleTickerProviderStateMixin {
  SearchFilter _activeFilter = SearchFilter.all;
  SortOption _activeSort = SortOption.newest;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _formatDateForDisplay(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty || isoDate == 'N/A') return 'N/A';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(isoDate));
    } catch (_) {
      return isoDate;
    }
  }

  List<Order> get _processedOrders {
    List<Order> filtered;
    switch (_activeFilter) {
      case SearchFilter.urgentDelivery:
        filtered = widget.orders.where((o) => o.isUrgent == true).toList();
        break;
      case SearchFilter.preferredMode:
        filtered = widget.orders
            .where((o) =>
        o.preferenceTransport != null &&
            o.preferenceTransport!.any((v) =>
            v.toLowerCase() == widget.searchedVehicle.toLowerCase()))
            .toList();
        break;
      case SearchFilter.all:
        filtered = List.from(widget.orders);
        break;
    }

    switch (_activeSort) {
      case SortOption.priceHighToLow:
        filtered.sort((a, b) {
          final priceA = a.calculatedPrice ?? 0.0;
          final priceB = b.calculatedPrice ?? 0.0;
          return priceB.compareTo(priceA);
        });
        break;
      case SortOption.preferredVehicle:
        filtered.sort((a, b) {
          final prefA = a.preferenceTransport?.any((v) =>
          v.toLowerCase() == widget.searchedVehicle.toLowerCase()) ??
              false;
          final prefB = b.preferenceTransport?.any((v) =>
          v.toLowerCase() == widget.searchedVehicle.toLowerCase()) ??
              false;
          if (prefA && !prefB) return -1;
          if (!prefA && prefB) return 1;
          return 0;
        });
        break;
      case SortOption.newest:
        filtered.sort((a, b) {
          final dateA =
              DateTime.tryParse(a.createdAt ?? '') ?? DateTime(2000);
          final dateB =
              DateTime.tryParse(b.createdAt ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });
        break;
    }
    return filtered;
  }

  void _openSendTripRequest(Order order) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            _OrderDetailSheet(
              order: order,
              formatDate: _formatDateForDisplay,
              onSendRequest: () => _handleSendRequest(order),
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
      ),
    );
  }

  void _handleSendRequest(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SendTripRequestPage(
          order: order,
          currentUserId: widget.currentUserId,
          tripRequestService: widget.tripRequestService,
          departureDate: widget.departureDate,
          departureTime: widget.departureTime,
          deliveryDate: widget.deliveryDate,
          deliveryTime: widget.deliveryTime,
          onSuccess: (tripRequestId, orderOwner) {
            Navigator.pop(context);
            Navigator.pop(context);
            final r = _R.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.white, size: r.iconXL),
                    SizedBox(width: r.sp12),
                    Expanded(
                      child: Text(
                        'Request sent to $orderOwner!',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: r.fontMD),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF22C55E),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.borderRadius)),
                margin: EdgeInsets.all(r.sp16),
              ),
            );
            widget.onSendRequest(order);
          },
        ),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) {
        final r = _R.of(context);
        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.fromLTRB(r.sp20, r.sp16, r.sp20, r.sp32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: r.s(40),
                    height: r.s(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: r.sp20),
                Text(
                  'Sort By',
                  style: TextStyle(
                      fontSize: r.font4XL, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: r.sp12),
                _buildSortTile(r, SortOption.newest, 'Newest First',
                    Icons.access_time_rounded),
                _buildSortTile(r, SortOption.priceHighToLow,
                    'Pricing: High to Low', Icons.trending_up_rounded),
                _buildSortTile(r, SortOption.preferredVehicle,
                    'Preferred Vehicle First', Icons.local_shipping_outlined),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortTile(_R r, SortOption option, String title, IconData icon) {
    final isSelected = _activeSort == option;
    return GestureDetector(
      onTap: () {
        setState(() => _activeSort = option);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.symmetric(vertical: r.sp4),
        padding:
        EdgeInsets.symmetric(horizontal: r.sp16, vertical: r.s(14)),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(r.s(14)),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? AppColors.primary : Colors.grey.shade500,
                size: r.iconXL),
            SizedBox(width: r.sp12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.primary : Colors.grey.shade700,
                fontWeight:
                isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: r.fontLG,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: r.iconXL),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final processed = _processedOrders;
    final r = _R.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Sliver App Bar ─────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            floating: false,
            snap: false,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            elevation: 0,
            // toolbarHeight covers back button + title row when collapsed
            toolbarHeight: r.s(56),
            // expandedHeight = toolbarHeight + filter chips bar
            expandedHeight: r.s(56),
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: r.s(36),
                    height: r.s(36),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(r.borderRadius),
                    ),
                    child: Icon(Icons.arrow_back_ios_new,
                        size: r.s(16), color: Colors.black87),
                  ),
                ),
                SizedBox(width: r.sp10),
                // Title block
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.fromLocation} → ${widget.toLocation}',
                        style: TextStyle(
                          fontSize: r.fontMD,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        '${widget.date}  ·  ${SearchResultsPage.formatTimeForDisplay(widget.departureTime)}',
                        style: TextStyle(
                            fontSize: r.fontXS,
                            color: Colors.grey.shade500,
                            height: 1.3),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: r.sp8),
                // Sort button
                GestureDetector(
                  onTap: _showSortOptions,
                  child: Container(
                    padding: EdgeInsets.all(r.sp8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(r.borderRadius),
                    ),
                    child: Icon(Icons.tune_rounded,
                        size: r.iconXL, color: Colors.black87),
                  ),
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(r.s(48)),
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                padding: EdgeInsets.fromLTRB(r.sp16, r.sp4, r.sp16, r.sp10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        r: r,
                        label: 'All',
                        count: widget.orders.length,
                        isActive: _activeFilter == SearchFilter.all,
                        onTap: () =>
                            setState(() => _activeFilter = SearchFilter.all),
                      ),
                      SizedBox(width: r.sp8),
                      _FilterChip(
                        r: r,
                        label: 'Urgent',
                        count:
                        widget.orders.where((o) => o.isUrgent == true).length,
                        isActive:
                        _activeFilter == SearchFilter.urgentDelivery,
                        onTap: () => setState(
                                () => _activeFilter = SearchFilter.urgentDelivery),
                        accentColor: const Color(0xFFEF4444),
                      ),
                      SizedBox(width: r.sp8),
                      _FilterChip(
                        r: r,
                        label: 'Preferred Mode',
                        count: widget.orders
                            .where((o) =>
                        o.preferenceTransport?.any((v) =>
                        v.toLowerCase() ==
                            widget.searchedVehicle.toLowerCase()) ??
                            false)
                            .length,
                        isActive:
                        _activeFilter == SearchFilter.preferredMode,
                        onTap: () => setState(
                                () => _activeFilter = SearchFilter.preferredMode),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Result Count ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(r.sp20, r.sp16, r.sp20, r.sp4),
              child: Text(
                '${processed.length} result${processed.length == 1 ? '' : 's'} found',
                style: TextStyle(
                  fontSize: r.fontMD,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // ── List / Empty ──────────────────────────────────────────
          processed.isEmpty
              ? const SliverFillRemaining(child: _EmptyState())
              : SliverPadding(
            padding:
            EdgeInsets.fromLTRB(r.sp16, r.sp8, r.sp16, r.sp24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final order = processed[index];
                  return _OrderCard(
                    order: order,
                    index: index,
                    formatDate: _formatDateForDisplay,
                    searchedVehicle: widget.searchedVehicle,
                    onTap: () => _openSendTripRequest(order),
                  );
                },
                childCount: processed.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _FilterChip
// ═══════════════════════════════════════════════════════════════════════════
class _FilterChip extends StatelessWidget {
  final _R r;
  final String label;
  final int count;
  final bool isActive;
  final VoidCallback onTap;
  final Color? accentColor;

  const _FilterChip({
    required this.r,
    required this.label,
    required this.count,
    required this.isActive,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
        EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(7)),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: r.fontMD,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? Colors.white : Colors.grey.shade600,
              ),
            ),
            SizedBox(width: r.sp6),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.sp6, vertical: r.sp2),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: r.fontSM,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _OrderCard
// ═══════════════════════════════════════════════════════════════════════════
class _OrderCard extends StatelessWidget {
  final Order order;
  final int index;
  final String Function(String?) formatDate;
  final String searchedVehicle;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.index,
    required this.formatDate,
    required this.searchedVehicle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = _R.of(context);
    final hasPrice =
        order.calculatedPrice != null && order.calculatedPrice! > 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + index * 60),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.only(bottom: r.sp12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(r.cardRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: r.s(12),
                offset: Offset(0, r.sp4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Top section ──────────────────────────────────────
              Padding(
                padding: EdgeInsets.all(r.sp16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vehicle type (left) + Price (right) top row
                    Row(
                      children: [
                        const Spacer(),
                        // Price badge-
                        if (hasPrice)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: r.sp10, vertical: r.sp4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(r.chipRadius),
                            ),
                            child: Text(
                              '₹${order.calculatedPrice!.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: r.fontXL,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ),
                      ],
                    ),

                    SizedBox(height: r.sp10),

                    // Vertical route tracker with separate date + time chips
                    _RouteTracker(
                      r: r,
                      origin: order.origin,
                      destination: order.destination,
                      departureDate: formatDate(order.departureDate),
                      departureTime: SearchResultsPage.formatTimeForDisplay(order.departureTime),
                      deliveryDate: formatDate(order.deliveryDate),
                      deliveryTime: SearchResultsPage.formatTimeForDisplay(order.deliveryTime),
                    ),

                    // ── Preferred Vehicle + Delivery Status ──────
                    if ((order.preferenceTransport != null &&
                        order.preferenceTransport!.isNotEmpty) ||
                        order.isUrgent != null) ...[
                      SizedBox(height: r.sp10),
                      Divider(height: 1, color: Colors.grey.shade100),
                      SizedBox(height: r.sp10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Preferred Vehicle
                          if (order.preferenceTransport != null &&
                              order.preferenceTransport!.isNotEmpty)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Preferred Vehicle',
                                    style: TextStyle(
                                      fontSize: r.fontXS,
                                      color: Colors.grey.shade400,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: r.s(4)),
                                  Row(
                                    children: [
                                      Icon(Icons.local_shipping_outlined,
                                          size: r.s(13),
                                          color: AppColors.primary),
                                      SizedBox(width: r.s(4)),
                                      Flexible(
                                        child: Text(
                                          order.preferenceTransport!.join(', '),
                                          style: TextStyle(
                                            fontSize: r.fontBase,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                          if ((order.preferenceTransport != null &&
                              order.preferenceTransport!.isNotEmpty) &&
                              order.isUrgent != null)
                            SizedBox(width: r.sp12),

                          // Delivery Status
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delivery Status',
                                  style: TextStyle(
                                    fontSize: r.fontXS,
                                    color: Colors.grey.shade400,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: r.s(4)),
                                _UrgentBadge(r: r, isUrgent: order.isUrgent == true),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // ── Divider ──────────────────────────────────────────
              Divider(height: 1, color: Colors.grey.shade100),

              // ── User row ─────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: r.sp16, vertical: r.sp12),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: r.avatarSM,
                      height: r.avatarSM,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.7),
                            AppColors.primary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (order.ownerName?.isNotEmpty == true
                              ? order.ownerName![0]
                              : 'U')
                              .toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: r.fontLG,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: r.sp10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.ownerName ?? 'Unknown',
                            style: TextStyle(
                              fontSize: r.fontMD,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Icon(Icons.star_rounded,
                                  size: r.iconSM,
                                  color: const Color(0xFFFACC15)),
                              SizedBox(width: r.sp2),
                              Text(
                                order.ownerRating?.toStringAsFixed(1) ?? '—',
                                style: TextStyle(
                                  fontSize: r.fontBase,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Send button
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(14), vertical: r.sp8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(r.sp10),
                      ),
                      child: Text(
                        'View Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.fontBase,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _RouteTracker  – vertical origin → destination with date/time chips
// ═══════════════════════════════════════════════════════════════════════════
class _RouteTracker extends StatelessWidget {
  final _R r;
  final String origin;
  final String destination;
  final String departureDate;
  final String departureTime;
  final String deliveryDate;
  final String deliveryTime;

  const _RouteTracker({
    required this.r,
    required this.origin,
    required this.destination,
    required this.departureDate,
    required this.departureTime,
    required this.deliveryDate,
    required this.deliveryTime,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left: vertical icon track ─────────────────────────────
        SizedBox(
          width: r.s(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Origin dot
              Container(
                width: r.s(12),
                height: r.s(12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: r.s(2.5),
                  ),
                ),
              ),
              // Dashed connector line
              SizedBox(
                height: r.s(37),
                child: Column(
                  children: List.generate(
                    5,
                        (_) => Expanded(
                      child: Center(
                        child: Container(
                          width: r.s(1.5),
                          color: Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Destination dot
              Container(
                width: r.s(12),
                height: r.s(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey.shade400,
                    width: r.s(2),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: r.s(4),
                    height: r.s(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(width: r.sp10),

        // ── Right: origin block + destination block ───────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Origin
              _RouteStop(
                r: r,
                locationLabel: 'From',
                location: origin,
                date: departureDate,
                time: departureTime,
                isOrigin: true,
              ),

              SizedBox(height: r.s(10)),

              // Destination
              _RouteStop(
                r: r,
                locationLabel: 'To',
                location: destination,
                date: deliveryDate,
                time: deliveryTime,
                isOrigin: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Single stop row (location + date chip + time chip) ────────────────────
class _RouteStop extends StatelessWidget {
  final _R r;
  final String locationLabel;
  final String location;
  final String date;
  final String time;
  final bool isOrigin;

  const _RouteStop({
    required this.r,
    required this.locationLabel,
    required this.location,
    required this.date,
    required this.time,
    required this.isOrigin,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isOrigin ? AppColors.primary : Colors.grey.shade500;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Location label
        Text(
          locationLabel,
          style: TextStyle(
            fontSize: r.fontXS,
            color: labelColor,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: r.s(2)),
        // Full location name – wraps to next line
        Text(
          location.isNotEmpty ? location : '—',
          style: TextStyle(
            fontSize: r.fontMD,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            height: 1.3,
          ),
          softWrap: true,
        ),
        SizedBox(height: r.s(5)),
        // Date + Time chips
        Wrap(
          spacing: r.sp6,
          runSpacing: r.s(4),
          children: [
            _DateTimeChip(
              r: r,
              icon: Icons.calendar_today_rounded,
              text: date.isNotEmpty ? date : '—',
              color: isOrigin ? AppColors.primary : Colors.grey.shade600,
              bgColor: isOrigin
                  ? AppColors.primary.withValues(alpha: 0.07)
                  : Colors.grey.shade100,
            ),
            _DateTimeChip(
              r: r,
              icon: Icons.access_time_rounded,
              text: time.isNotEmpty ? time : '—',
              color: isOrigin ? AppColors.primary : Colors.grey.shade600,
              bgColor: isOrigin
                  ? AppColors.primary.withValues(alpha: 0.07)
                  : Colors.grey.shade100,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Pill chip for a single date or time value ─────────────────────────────
class _DateTimeChip extends StatelessWidget {
  final _R r;
  final IconData icon;
  final String text;
  final Color color;
  final Color bgColor;

  const _DateTimeChip({
    required this.r,
    required this.icon,
    required this.text,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: r.s(8), vertical: r.s(4)),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(r.s(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: r.s(11), color: color),
          SizedBox(width: r.s(4)),
          Text(
            text,
            style: TextStyle(
              fontSize: r.fontXS,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _InfoTile
// ═══════════════════════════════════════════════════════════════════════════
class _InfoTile extends StatelessWidget {
  final _R r;
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.r,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: r.iconSM, color: Colors.grey.shade400),
        SizedBox(width: r.sp4 + 1),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: r.fontXS,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: r.sp2 / 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: r.fontBase,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _UrgentBadge  – shows "Urgent" (red) or "Standard" (green) delivery status
// ═══════════════════════════════════════════════════════════════════════════
class _UrgentBadge extends StatelessWidget {
  final _R r;
  final bool isUrgent;
  const _UrgentBadge({required this.r, this.isUrgent = true});

  @override
  Widget build(BuildContext context) {
    final bgColor    = isUrgent ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5);
    final borderColor = isUrgent ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0);
    final dotColor   = isUrgent ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
    final textColor  = isUrgent ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    final label      = isUrgent ? 'Urgent' : 'Standard';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.sp10, vertical: r.sp4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(r.badgeRadius),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: r.dotSM,
            height: r.dotSM,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: r.sp4 + 1),
          Text(
            label,
            style: TextStyle(
              fontSize: r.fontSM,
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _OrderDetailSheet
// ═══════════════════════════════════════════════════════════════════════════
class _OrderDetailSheet extends StatelessWidget {
  final Order order;
  final String Function(String?) formatDate;
  final VoidCallback onSendRequest;

  const _OrderDetailSheet({
    required this.order,
    required this.formatDate,
    required this.onSendRequest,
  });

  static void _showImageFullscreen(BuildContext context, List<String> images, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _ImageViewer(images: images, initialIndex: initialIndex),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _R.of(context);
    final hasPrice =
        order.calculatedPrice != null && order.calculatedPrice! > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded,
              color: Colors.black87, size: r.iconXL),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Order Details',
          style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              fontSize: r.font3XL),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.all(r.sp16),
        children: [
          // ── Sender card ──────────────────────────────────────────
          _DetailCard(
            r: r,
            child: Row(
              children: [
                Container(
                  width: r.avatarMD,
                  height: r.avatarMD,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.7),
                        AppColors.primary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (order.ownerName?.isNotEmpty == true
                          ? order.ownerName![0]
                          : 'U')
                          .toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: r.font5XL,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: r.s(14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.ownerName ?? 'Unknown',
                        style: TextStyle(
                          fontSize: r.font2XL,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: r.sp2),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: r.iconMD,
                              color: const Color(0xFFFACC15)),
                          SizedBox(width: r.s(3)),
                          Text(
                            order.ownerRating?.toStringAsFixed(1) ?? '—',
                            style: TextStyle(
                              fontSize: r.fontMD,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _UrgentBadge(r: r, isUrgent: order.isUrgent == true),
              ],
            ),
          ),

          SizedBox(height: r.sp12),

          // ── Route card ───────────────────────────────────────────
          _DetailCard(
            r: r,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vertical route tracker with separate date + time chips
                _RouteTracker(
                  r: r,
                  origin: order.origin,
                  destination: order.destination,
                  departureDate: formatDate(order.departureDate),
                  departureTime: SearchResultsPage.formatTimeForDisplay(order.departureTime),
                  deliveryDate: formatDate(order.deliveryDate),
                  deliveryTime: SearchResultsPage.formatTimeForDisplay(order.deliveryTime),
                ),
                // ── Preferred Vehicle + Delivery Status ──────
                SizedBox(height: r.sp12),
                Divider(height: 1, color: Colors.grey.shade100),
                SizedBox(height: r.sp12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Preferred Vehicle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Preferred Vehicle',
                            style: TextStyle(
                              fontSize: r.fontXS,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(height: r.s(5)),
                          Row(
                            children: [
                              Icon(Icons.local_shipping_outlined,
                                  size: r.s(14), color: AppColors.primary),
                              SizedBox(width: r.s(5)),
                              Flexible(
                                child: Text(
                                  (order.preferenceTransport != null &&
                                      order.preferenceTransport!.isNotEmpty)
                                      ? order.preferenceTransport!.join(', ')
                                      : 'Not specified',
                                  style: TextStyle(
                                    fontSize: r.fontMD,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: r.sp12),

                    // Delivery Status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery Status',
                            style: TextStyle(
                              fontSize: r.fontXS,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(height: r.s(5)),
                          _UrgentBadge(r: r, isUrgent: order.isUrgent == true),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: r.sp12),

          // ── Product details card ─────────────────────────────────
          _DetailCard(
            r: r,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Product Details',
                  style: TextStyle(
                      fontSize: r.fontXL, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: r.s(14)),
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        r: r,
                        icon: Icons.inventory_2_outlined,
                        label: 'Category',
                        value: order.itemDescription,
                      ),
                    ),
                    Expanded(
                      child: _InfoTile(
                        r: r,
                        icon: Icons.scale_outlined,
                        label: 'Weight',
                        value: order.weight,
                      ),
                    ),
                  ],
                ),
                // ── Images ───────────────────────────────────────
                _OrderImageGallery(
                  order: order,
                  r: r,
                  onImageTap: (images, index) => _showImageFullscreen(context, images, index),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: EdgeInsets.fromLTRB(r.sp16, r.sp12, r.sp16, r.sp16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hasPrice) ...[
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Price',
                        style: TextStyle(
                            fontSize: r.fontSM, color: Colors.grey.shade500),
                      ),
                      Text(
                        '₹${order.calculatedPrice!.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: r.font6XL,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: r.sp16),
                ],
                Expanded(
                  child: GestureDetector(
                    onTap: onSendRequest,
                    child: Container(
                      height: r.s(52),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(r.buttonRadius),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: r.sp16,
                            offset: Offset(0, r.sp6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Send Request',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: r.font2XL,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _OrderImageGallery – Horizontally scrollable images with arrow indicators
// ═══════════════════════════════════════════════════════════════════════════
class _OrderImageGallery extends StatefulWidget {
  final Order order;
  final _R r;
  final Function(List<String>, int) onImageTap;

  const _OrderImageGallery({
    required this.order,
    required this.r,
    required this.onImageTap,
  });

  @override
  State<_OrderImageGallery> createState() => _OrderImageGalleryState();
}

class _OrderImageGalleryState extends State<_OrderImageGallery> {
  final ScrollController _scrollController = ScrollController();
  bool _showLeftArrow = false;
  bool _showRightArrow = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    
    setState(() {
      _showLeftArrow = currentScroll > 10;
      _showRightArrow = currentScroll < maxScroll - 10;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final order = widget.order;

    // Resolve relative paths using server base URL
    String resolve(String url) {
      if (url.isEmpty) return '';
      if (url.startsWith('http://') || url.startsWith('https://')) return url;
      return '${ApiConstants.imagebaseUrl}$url';
    }

    final List<String> images = [];
    if (order.imageUrl.isNotEmpty) {
      images.add(resolve(order.imageUrl));
    }
    if (order.imageUrls != null) {
      for (final u in order.imageUrls!) {
        final resolved = resolve(u);
        if (resolved.isNotEmpty && !images.contains(resolved)) {
          images.add(resolved);
        }
      }
    }

    if (images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.s(14)),
        Text(
          'Product Images',
          style: TextStyle(
            fontSize: r.fontXS,
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: r.sp8),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: r.s(110),
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                padding: EdgeInsets.symmetric(horizontal: images.length > 3 ? r.sp12 : 0),
                itemBuilder: (context, i) {
                  return GestureDetector(
                    onTap: () => widget.onImageTap(images, i),
                    child: Container(
                      width: r.s(110),
                      height: r.s(110),
                      margin: EdgeInsets.only(right: r.sp8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(r.borderRadius),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(r.borderRadius),
                        child: Image.network(
                          images[i],
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: r.s(20),
                                height: r.s(20),
                                child: CircularProgressIndicator(
                                  strokeWidth: r.s(2),
                                  color: AppColors.primary,
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (ctx, error, stack) => Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: r.s(28),
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Left Arrow
            if (_showLeftArrow)
              Positioned(
                left: -5,
                child: _ArrowIndicator(icon: Icons.chevron_left_rounded, r: r),
              ),
              
            // Right Arrow
            if (_showRightArrow)
              Positioned(
                right: -5,
                child: _ArrowIndicator(icon: Icons.chevron_right_rounded, r: r),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Arrow Indicator pill ───────────────────────────────────────────────────
class _ArrowIndicator extends StatelessWidget {
  final IconData icon;
  final _R r;
  const _ArrowIndicator({required this.icon, required this.r});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: r.s(28),
      height: r.s(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: r.s(20), color: Colors.black87),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _DetailCard
// ═══════════════════════════════════════════════════════════════════════════
class _DetailCard extends StatelessWidget {
  final _R r;
  final Widget child;
  const _DetailCard({required this.r, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(r.sp16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: r.sp10,
            offset: Offset(0, r.s(3)),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _EmptyState
// ═══════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final r = _R.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(r.sp24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_off_rounded,
                size: r.s(48), color: Colors.grey.shade300),
          ),
          SizedBox(height: r.sp20),
          Text(
            'No orders found',
            style: TextStyle(
              fontSize: r.font3XL,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: r.sp6),
          Text(
            'Try adjusting your filters',
            style: TextStyle(
              fontSize: r.fontMD,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _ImageViewer  – full-screen swipeable image viewer
// ═══════════════════════════════════════════════════════════════════════════
class _ImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _ImageViewer({required this.images, required this.initialIndex});

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late PageController _pageController;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Swipeable image pages
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (ctx, i) => InteractiveViewer(
              child: Center(
                child: Image.network(
                  widget.images[i],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),

          // Page indicator dots (only if multiple images)
          if (widget.images.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.images.length, (i) {
                  final active = i == _current;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}