import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../Constants/colorconstant.dart';
import '../../Models/OrderModel.dart';
import '../../Controllers/TripRequestService.dart';
import '../CustomRouteMapScreen.dart';
import '../Widgets/sendtriprequestpage.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Filter Enum
// ═══════════════════════════════════════════════════════════════════════════
enum SearchFilter { all, urgentDelivery, preferredMode }

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

class _SearchResultsPageState extends State<SearchResultsPage> {
  SearchFilter _activeFilter = SearchFilter.all;

  String _formatDateForDisplay(String isoDate) {
    if (isoDate.isEmpty || isoDate == 'N/A') return 'N/A';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(isoDate));
    } catch (_) {
      return isoDate;
    }
  }

  List<Order> get _filteredOrders {
    switch (_activeFilter) {
      case SearchFilter.urgentDelivery:
        return widget.orders
            .where((o) => o.isUrgent == true)
            .toList();
      case SearchFilter.preferredMode:
        return widget.orders
            .where((o) =>
        o.preferenceTransport != null &&
            o.preferenceTransport!.any((v) =>
            v.toLowerCase() == widget.searchedVehicle.toLowerCase()))
            .toList();
      case SearchFilter.all:
      default:
        return widget.orders;
    }
  }

  int get _urgentCount => widget.orders
      .where((o) => o.isUrgent == true)
      .length;

  int get _preferredCount => widget.orders
      .where((o) =>
  o.preferenceTransport != null &&
      o.preferenceTransport!.any((v) =>
      v.toLowerCase() == widget.searchedVehicle.toLowerCase()))
      .length;

  void _openSendTripRequest(Order order) {
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
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.all(16),
              ),
            );
            widget.onSendRequest(order);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = '${widget.fromLocation} to ${widget.toLocation}';
    final subtitle = '${widget.date} ; ${widget.departureTime}';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        titleSpacing: 0,
      ),
      body: Column(
        children: [
          // ── Filter Chips ─────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChipWidget(
                    label: 'All',
                    count: widget.orders.length,
                    isActive: _activeFilter == SearchFilter.all,
                    onTap: () =>
                        setState(() => _activeFilter = SearchFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterChipWidget(
                    label: 'Urgent Delivery',
                    count: _urgentCount,
                    isActive: _activeFilter == SearchFilter.urgentDelivery,
                    onTap: () => setState(
                            () => _activeFilter = SearchFilter.urgentDelivery),
                  ),
                  const SizedBox(width: 8),
                  _FilterChipWidget(
                    label: 'Preferred Mode',
                    count: _preferredCount,
                    isActive: _activeFilter == SearchFilter.preferredMode,
                    onTap: () => setState(
                            () => _activeFilter = SearchFilter.preferredMode),
                  ),
                ],
              ),
            ),
          ),

          // ── Order List ───────────────────────────────────────────────
          Expanded(
            child: _filteredOrders.isEmpty
                ? const _EmptyState()
                : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _filteredOrders.length,
              itemBuilder: (context, index) {
                final order = _filteredOrders[index];
                return _OrderCard(
                  order: order,
                  formatDate: _formatDateForDisplay,
                  searchedVehicle: widget.searchedVehicle,
                  onTap: () => _openSendTripRequest(order),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _FilterChipWidget
// ═══════════════════════════════════════════════════════════════════════════
class _FilterChipWidget extends StatelessWidget {
  final String label;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChipWidget({
    super.key,
    required this.label,
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : Colors.grey[700],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : Colors.grey[700],
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
// _OrderCard  –  matches the screenshot design
// ═══════════════════════════════════════════════════════════════════════════
class _OrderCard extends StatelessWidget {
  final Order order;
  final String Function(String) formatDate;
  final String searchedVehicle;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.formatDate,
    required this.searchedVehicle,
    required this.onTap,
  });

  bool get _isUrgent => order.isUrgent == true;

  Color get _statusColor {
    switch (order.status.toLowerCase()) {
      case 'in transit':
      case 'in-transit':
        return const Color(0xFFF5A623);
      case 'delivered':
        return const Color(0xFF27AE60);
      case 'pending':
        return const Color(0xFF2F80ED);
      default:
        return Colors.grey;
    }
  }

  Color get _statusBgColor {
    switch (order.status.toLowerCase()) {
      case 'in transit':
      case 'in-transit':
        return const Color(0xFFFFF8EE);
      case 'delivered':
        return const Color(0xFFEAF9F0);
      case 'pending':
        return const Color(0xFFEBF3FE);
      default:
        return Colors.grey.shade100;
    }
  }

  String get _preference {
    if (order.preferenceTransport != null &&
        order.preferenceTransport!.isNotEmpty) {
      return order.preferenceTransport!.first;
    }
    return searchedVehicle;
  }

  @override
  Widget build(BuildContext context) {
    final delivery =
        '${formatDate(order.deliveryDate)} ; ${order.deliveryTime ?? ''}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Route dots + dashes + status badge ───────────────────
              Row(
                children: [
                  const _RouteDot(),
                  const SizedBox(width: 4),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final dashCount =
                        (constraints.maxWidth / 8).floor();
                        return Row(
                          children: List.generate(
                            dashCount,
                                (i) => Expanded(
                              child: Container(
                                height: 1.5,
                                color: i.isEven
                                    ? Colors.black54
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Icon(Icons.arrow_forward,
                      size: 14, color: Colors.black87),
                  const SizedBox(width: 4),
                  const _RouteDot(),
                  const SizedBox(width: 10),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusBgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      order.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor,
                      ),
                    ),
                  ),
                ],
              ),

              // ── Route label ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 12),
                child: Text(
                  '${order.origin} ----→ ${order.destination}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),

              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 10),

              // ── Delivery info ──────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _InfoBlock(
                      icon: Icons.local_shipping_outlined,
                      label: 'Delivery',
                      value: delivery,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Preference / Delivery Status ──────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _InfoBlock(
                      icon: Icons.directions_car_outlined,
                      label: 'Preference',
                      value: _preference,
                    ),
                  ),
                  if (_isUrgent)
                    Expanded(
                      child: _InfoBlock(
                        icon: Icons.circle,
                        iconColor: Colors.red,
                        label: 'Delivery Status',
                        value: 'Urgent',
                        valueColor: Colors.red,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 10),

              // ── Traveler info ─────────────────────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey.shade200,
                    child: Icon(Icons.person,
                        size: 18, color: Colors.grey.shade500),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.userName.isNotEmpty
                            ? order.userName
                            : 'Unknown User',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _RouteDot
// ═══════════════════════════════════════════════════════════════════════════
class _RouteDot extends StatelessWidget {
  const _RouteDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: Colors.black87,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _InfoBlock
// ═══════════════════════════════════════════════════════════════════════════
class _InfoBlock extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoBlock({
    super.key,
    required this.icon,
    this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: iconColor ?? Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
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
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No orders found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search criteria',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CompactOrderCard
// Kept for backward-compatibility if referenced elsewhere in the codebase.
// Uses CustomRouteMapScreen for "View Route".
// ═══════════════════════════════════════════════════════════════════════════
class CompactOrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onSendRequest;
  final String Function(String) formatDate;
  final String searchedVehicle;

  const CompactOrderCard({
    super.key,
    required this.order,
    required this.onSendRequest,
    required this.formatDate,
    required this.searchedVehicle,
  });

  bool _isVehiclePreferred() {
    if (order.preferenceTransport == null ||
        order.preferenceTransport!.isEmpty) {
      return false;
    }
    return order.preferenceTransport!.any(
            (v) => v.toLowerCase() == searchedVehicle.toLowerCase());
  }

  Future<void> _showRouteMap(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomRouteMapScreen(
          originCity: order.origin,
          destinationCity: order.destination,
          originLatitude: order.originLatitude,
          originLongitude: order.originLongitude,
          destinationLatitude: order.destinationLatitude,
          destinationLongitude: order.destinationLongitude,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    order.userName.isNotEmpty
                        ? order.userName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    order.userName.isNotEmpty ? order.userName : 'Unknown User',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.green[700], size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Available',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Route
                Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green[600],
                            shape: BoxShape.circle,
                            border:
                            Border.all(color: Colors.green[800]!, width: 2),
                          ),
                        ),
                        Container(width: 2, height: 40, color: Colors.grey[300]),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.red[600],
                            shape: BoxShape.circle,
                            border:
                            Border.all(color: Colors.red[800]!, width: 2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.origin,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87)),
                          const SizedBox(height: 8),
                          if (order.distanceKm != null &&
                              order.distanceKm! > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_forward,
                                      size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${order.distanceKm!.toStringAsFixed(0)} km',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(order.destination,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87)),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey[200]),
                const SizedBox(height: 16),

                // Info grid
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.inventory_2,
                        label: 'Item',
                        value: order.itemDescription,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.scale,
                        label: 'Weight',
                        value: order.weight,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.calendar_today,
                        label: 'Date',
                        value: formatDate(order.deliveryDate),
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.access_time,
                        label: 'Time',
                        value: order.deliveryTime != null
                            ? order.deliveryTime!.substring(0, 5)
                            : 'N/A',
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.local_shipping,
                        label: 'Preferred Vehicle',
                        value: order.preferenceTransport != null &&
                            order.preferenceTransport!.isNotEmpty
                            ? order.preferenceTransport!.join(', ')
                            : 'Any',
                        color: Colors.teal,
                        showPreferredBadge: _isVehiclePreferred(),
                      ),
                    ),
                    if (order.isUrgent == true) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.red[200]!, width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_fire_department,
                                  color: Colors.red[700], size: 18),
                              const SizedBox(width: 6),
                              Text('URGENT',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[700])),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // Price
                if (order.calculatedPrice != null &&
                    order.calculatedPrice! > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade50, Colors.green.shade100],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border:
                      Border.all(color: Colors.green.shade300, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Estimated Earning',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.currency_rupee,
                                    color: Colors.green[800], size: 20),
                                Text(
                                  order.calculatedPrice!.toStringAsFixed(0),
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[800]),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Icon(Icons.currency_rupee,
                            color: Colors.green.shade400, size: 40),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRouteMap(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                          side: BorderSide(
                              color: Colors.blue[300]!, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding:
                          const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.map, size: 20),
                        label: const Text('View Route',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onSendRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding:
                          const EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.send, size: 20),
                        label: const Text('Send Request',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool showPreferredBadge = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
              ),
              if (showPreferredBadge) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[600],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('PREFERRED',
                      style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SimplifiedOrderCard
// Kept for backward-compatibility if referenced elsewhere in the codebase.
// ═══════════════════════════════════════════════════════════════════════════
class SimplifiedOrderCard extends StatelessWidget {
  final Order order;
  final String Function(String) formatDate;
  final VoidCallback onTap;

  const SimplifiedOrderCard({
    super.key,
    required this.order,
    required this.formatDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary,
                child: Text(
                  order.userName.isNotEmpty
                      ? order.userName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.userName.isNotEmpty
                          ? order.userName
                          : 'Unknown User',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 14, color: Colors.green[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(order.origin,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.arrow_downward,
                            size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 6),
                        if (order.distanceKm != null &&
                            order.distanceKm! > 0)
                          Text(
                            '${order.distanceKm!.toStringAsFixed(0)} km',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 14, color: Colors.red[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(order.destination,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 12, color: Colors.blue[600]),
                        const SizedBox(width: 4),
                        Text(formatDate(order.deliveryDate),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time,
                            size: 12, color: Colors.indigo[600]),
                        const SizedBox(width: 4),
                        Text(
                          order.deliveryTime != null
                              ? order.deliveryTime!.substring(0, 5)
                              : 'N/A',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// OrderInfoScreen
// Kept for backward-compatibility if referenced elsewhere in the codebase.
// ═══════════════════════════════════════════════════════════════════════════
class OrderInfoScreen extends StatelessWidget {
  final Order order;
  final String Function(String) formatDate;
  final String searchedVehicle;
  final VoidCallback onSendRequest;

  const OrderInfoScreen({
    super.key,
    required this.order,
    required this.formatDate,
    required this.searchedVehicle,
    required this.onSendRequest,
  });

  bool _isVehiclePreferred() {
    if (order.preferenceTransport == null ||
        order.preferenceTransport!.isEmpty) {
      return false;
    }
    return order.preferenceTransport!.any(
            (v) => v.toLowerCase() == searchedVehicle.toLowerCase());
  }

  Future<void> _showRouteMap(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomRouteMapScreen(
          originCity: order.origin,
          destinationCity: order.destination,
          originLatitude: order.originLatitude,
          originLongitude: order.originLongitude,
          destinationLatitude: order.destinationLatitude,
          destinationLongitude: order.destinationLongitude,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title:
        const Text('Order Details', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      order.userName.isNotEmpty
                          ? order.userName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.userName.isNotEmpty
                              ? order.userName
                              : 'Unknown User',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green[700], size: 14),
                              const SizedBox(width: 6),
                              Text('Available',
                                  style: TextStyle(
                                      color: Colors.green[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Route
            _sectionCard(
              context,
              title: 'Route Information',
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green[600],
                          shape: BoxShape.circle,
                          border:
                          Border.all(color: Colors.green[800]!, width: 2),
                        ),
                      ),
                      Container(
                          width: 2, height: 50, color: Colors.grey[300]),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.red[600],
                          shape: BoxShape.circle,
                          border:
                          Border.all(color: Colors.red[800]!, width: 2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.origin,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                        const SizedBox(height: 10),
                        if (order.distanceKm != null &&
                            order.distanceKm! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${order.distanceKm!.toStringAsFixed(0)} km',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(order.destination,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Order Details
            _sectionCard(
              context,
              title: 'Order Details',
              child: Column(
                children: [
                  _buildDetailRow(
                      icon: Icons.inventory_2,
                      label: 'Item Description',
                      value: order.itemDescription,
                      color: Colors.purple),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                      icon: Icons.scale,
                      label: 'Weight',
                      value: order.weight,
                      color: Colors.orange),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                      icon: Icons.calendar_today,
                      label: 'Delivery Date',
                      value: formatDate(order.deliveryDate),
                      color: Colors.blue),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                      icon: Icons.access_time,
                      label: 'Delivery Time',
                      value: order.deliveryTime != null
                          ? order.deliveryTime!.substring(0, 5)
                          : 'N/A',
                      color: Colors.indigo),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    icon: Icons.local_shipping,
                    label: 'Preferred Vehicle',
                    value: order.preferenceTransport != null &&
                        order.preferenceTransport!.isNotEmpty
                        ? order.preferenceTransport!.join(', ')
                        : 'Any',
                    color: Colors.teal,
                    showBadge: _isVehiclePreferred(),
                    badgeText: 'PREFERRED',
                  ),
                  if (order.isUrgent == true) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.red[200]!, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.local_fire_department,
                              color: Colors.red[700], size: 20),
                          const SizedBox(width: 8),
                          Text('URGENT DELIVERY',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700])),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Price
            if (order.calculatedPrice != null && order.calculatedPrice! > 0)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade50, Colors.green.shade100],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border:
                  Border.all(color: Colors.green.shade300, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Estimated Earning',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.currency_rupee,
                                color: Colors.green[800], size: 28),
                            Text(
                              order.calculatedPrice!.toStringAsFixed(0),
                              style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800]),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Icon(Icons.currency_rupee,
                        color: Colors.green.shade400, size: 50),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRouteMap(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue[700],
                        side: BorderSide(
                            color: Colors.blue[300]!, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.map, size: 20),
                      label: const Text('View Route',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onSendRequest();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.send, size: 20),
                      label: const Text('Send Request',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(BuildContext context,
      {required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool showBadge = false,
    String? badgeText,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500)),
                  if (showBadge && badgeText != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.green[600],
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(badgeText,
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}
