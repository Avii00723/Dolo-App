import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../Constants/colorconstant.dart';
import '../../Models/OrderModel.dart';
import '../../Controllers/TripRequestService.dart';
import '../CustomRouteMapScreen.dart';
import '../Widgets/sendtriprequestpage.dart';

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

  String _formatDateForDisplay(String isoDate) {
    if (isoDate.isEmpty || isoDate == 'N/A') return 'N/A';
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
      default:
        filtered = List.from(widget.orders);
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
      default:
        filtered.sort((a, b) {
          final dateA =
              DateTime.tryParse(a.createdAt ?? '') ?? DateTime(2000);
          final dateB =
              DateTime.tryParse(b.createdAt ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Request sent to $orderOwner!',
                        style:
                        const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF22C55E),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
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
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sort By',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _buildSortTile(SortOption.newest, 'Newest First',
                  Icons.access_time_rounded),
              _buildSortTile(SortOption.priceHighToLow,
                  'Pricing: High to Low', Icons.trending_up_rounded),
              _buildSortTile(SortOption.preferredVehicle,
                  'Preferred Vehicle First', Icons.local_shipping_outlined),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortTile(
      SortOption option, String title, IconData icon) {
    final isSelected = _activeSort == option;
    return GestureDetector(
      onTap: () {
        setState(() => _activeSort = option);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.08)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withOpacity(0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color:
                isSelected ? AppColors.primary : Colors.grey.shade500,
                size: 20),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color:
                isSelected ? AppColors.primary : Colors.grey.shade700,
                fontWeight: isSelected
                    ? FontWeight.w700
                    : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final processed = _processedOrders;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Sliver App Bar ─────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            elevation: 0,
            expandedHeight: 110,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      size: 18, color: Colors.black87),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
              const EdgeInsets.only(left: 56, bottom: 14, right: 56),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.fromLocation} → ${widget.toLocation}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${widget.date}  ·  ${widget.departureTime}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: _showSortOptions,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.tune_rounded,
                        size: 20, color: Colors.black87),
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        count: widget.orders.length,
                        isActive: _activeFilter == SearchFilter.all,
                        onTap: () => setState(
                                () => _activeFilter = SearchFilter.all),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Urgent',
                        count: widget.orders
                            .where((o) => o.isUrgent == true)
                            .length,
                        isActive:
                        _activeFilter == SearchFilter.urgentDelivery,
                        onTap: () => setState(() =>
                        _activeFilter = SearchFilter.urgentDelivery),
                        accentColor: const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Preferred Mode',
                        count: widget.orders
                            .where((o) =>
                        o.preferenceTransport?.any((v) =>
                        v.toLowerCase() ==
                            widget.searchedVehicle
                                .toLowerCase()) ??
                            false)
                            .length,
                        isActive:
                        _activeFilter == SearchFilter.preferredMode,
                        onTap: () => setState(() =>
                        _activeFilter = SearchFilter.preferredMode),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Result Count ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
              const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                '${processed.length} result${processed.length == 1 ? '' : 's'} found',
                style: TextStyle(
                  fontSize: 13,
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
  final String label;
  final int count;
  final bool isActive;
  final VoidCallback onTap;
  final Color? accentColor;

  const _FilterChip({
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
        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                fontSize: 13,
                fontWeight:
                isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? Colors.white : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withOpacity(0.25)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
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
// _OrderCard  (redesigned)
// ═══════════════════════════════════════════════════════════════════════════
class _OrderCard extends StatelessWidget {
  final Order order;
  final int index;
  final String Function(String) formatDate;
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
    final hasPrice =
        order.calculatedPrice != null && order.calculatedPrice! > 0;
    final isPreferred = order.preferenceTransport?.any((v) =>
    v.toLowerCase() == searchedVehicle.toLowerCase()) ??
        false;

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
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Top section ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Route row
                    Row(
                      children: [
                        _RouteDots(),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${order.origin}  ⟶  ${order.destination}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasPrice) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '₹${order.calculatedPrice!.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Dates row
                    Row(
                      children: [
                        Expanded(
                          child: _InfoTile(
                            icon: Icons.flight_takeoff_rounded,
                            label: 'Departure',
                            value:
                            '${formatDate(order.departureDate ?? '')}  ·  ${order.departureTime ?? ''}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _InfoTile(
                            icon: Icons.flag_rounded,
                            label: 'Delivery',
                            value:
                            '${formatDate(order.deliveryDate)}  ·  ${order.deliveryTime ?? ''}',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Preference + Status row
                    Row(
                      children: [
                        if (isPreferred) ...[
                          _InfoTile(
                            icon: Icons.local_shipping_outlined,
                            label: 'Preference',
                            value: order.preferenceTransport
                                ?.join(', ') ??
                                '—',
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (order.isUrgent == true)
                          _UrgentBadge(),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Divider ──────────────────────────────────────────
              Divider(height: 1, color: Colors.grey.shade100),

              // ── User row ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.7),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.ownerName ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 13,
                                  color: Color(0xFFFACC15)),
                              const SizedBox(width: 2),
                              Text(
                                order.ownerRating?.toStringAsFixed(1) ??
                                    '—',
                                style: TextStyle(
                                  fontSize: 12,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'View Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
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
// _RouteDots  – two dots connected by a dashed line
// ═══════════════════════════════════════════════════════════════════════════
class _RouteDots extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 2),
        ...List.generate(
          3,
              (_) => Container(
            width: 3,
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        const SizedBox(width: 2),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _InfoTile
// ═══════════════════════════════════════════════════════════════════════════
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade400),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
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
// _UrgentBadge
// ═══════════════════════════════════════════════════════════════════════════
class _UrgentBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'Urgent',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFFDC2626),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _OrderDetailSheet  – replaces old NavigateTo SendTripRequest preview
// ═══════════════════════════════════════════════════════════════════════════
class _OrderDetailSheet extends StatelessWidget {
  final Order order;
  final String Function(String) formatDate;
  final VoidCallback onSendRequest;

  const _OrderDetailSheet({
    required this.order,
    required this.formatDate,
    required this.onSendRequest,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrice =
        order.calculatedPrice != null && order.calculatedPrice! > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Order Details',
          style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Sender card ──────────────────────────────────────────
          _DetailCard(
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.7),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.ownerName ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 15, color: Color(0xFFFACC15)),
                          const SizedBox(width: 3),
                          Text(
                            order.ownerRating?.toStringAsFixed(1) ?? '—',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (order.isUrgent == true) _UrgentBadge(),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Route card ───────────────────────────────────────────
          _DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _RouteDots(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${order.origin}  ⟶  ${order.destination}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.flight_takeoff_rounded,
                        label: 'Departure',
                        value:
                        '${formatDate(order.departureDate ?? '')}  ·  ${order.departureTime ?? ''}',
                      ),
                    ),
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.flag_rounded,
                        label: 'Delivery',
                        value:
                        '${formatDate(order.deliveryDate)}  ·  ${order.deliveryTime ?? ''}',
                      ),
                    ),
                  ],
                ),
                if (order.preferenceTransport != null &&
                    order.preferenceTransport!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InfoTile(
                    icon: Icons.local_shipping_outlined,
                    label: 'Preference',
                    value: order.preferenceTransport!.join(', '),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Product details card ─────────────────────────────────
          _DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Product Details',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.inventory_2_outlined,
                        label: 'Category',
                        value: order.itemDescription,
                      ),
                    ),
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.scale_outlined,
                        label: 'Weight',
                        value: order.weight,
                      ),
                    ),
                  ],
                ),
                // Product images placeholder
                if (order.imageUrls != null &&
                    order.imageUrls!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Images',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: order.imageUrls!.length,
                      itemBuilder: (context, i) => Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image:
                            NetworkImage(order.imageUrls![i]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Row(
          children: [
            if (hasPrice) ...[
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                  Text(
                    '₹${order.calculatedPrice!.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: GestureDetector(
                onTap: onSendRequest,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Send Request',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
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
// _DetailCard
// ═══════════════════════════════════════════════════════════════════════════
class _DetailCard extends StatelessWidget {
  final Widget child;
  const _DetailCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_off_rounded,
                size: 48, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 20),
          const Text(
            'No orders found',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your filters',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}