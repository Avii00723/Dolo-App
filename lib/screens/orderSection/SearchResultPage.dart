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

class _SearchResultsPageState extends State<SearchResultsPage> {
  SearchFilter _activeFilter = SearchFilter.all;
  SortOption _activeSort = SortOption.newest;

  String _formatDateForDisplay(String isoDate) {
    if (isoDate.isEmpty || isoDate == 'N/A') return 'N/A';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(isoDate));
    } catch (_) {
      return isoDate;
    }
  }

  List<Order> get _processedOrders {
    // 1. Filter
    List<Order> filtered;
    switch (_activeFilter) {
      case SearchFilter.urgentDelivery:
        filtered = widget.orders.where((o) => o.isUrgent == true).toList();
        break;
      case SearchFilter.preferredMode:
        filtered = widget.orders.where((o) =>
        o.preferenceTransport != null &&
            o.preferenceTransport!.any((v) =>
            v.toLowerCase() == widget.searchedVehicle.toLowerCase())).toList();
        break;
      case SearchFilter.all:
      default:
        filtered = List.from(widget.orders);
    }

    // 2. Sort
    switch (_activeSort) {
      case SortOption.priceHighToLow:
        filtered.sort((a, b) {
          final priceA = a.calculatedPrice ?? 0.0;
          final priceB = b.calculatedPrice ?? 0.0;
          return priceB.compareTo(priceA);
        });
        break;
      case SortOption.preferredVehicle:
      // Sort so those with the preferred vehicle come first
        filtered.sort((a, b) {
          final prefA = a.preferenceTransport?.any((v) =>
          v.toLowerCase() == widget.searchedVehicle.toLowerCase()) ?? false;
          final prefB = b.preferenceTransport?.any((v) =>
          v.toLowerCase() == widget.searchedVehicle.toLowerCase()) ?? false;
          if (prefA && !prefB) return -1;
          if (!prefA && prefB) return 1;
          return 0;
        });
        break;
      case SortOption.newest:
      default:
        filtered.sort((a, b) {
          final dateA = DateTime.tryParse(a.createdAt ?? '') ?? DateTime(2000);
          final dateB = DateTime.tryParse(b.createdAt ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });
    }

    return filtered;
  }

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
                    const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Request sent to $orderOwner!',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sort By',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildSortTile(SortOption.newest, 'Newest First', Icons.history),
              _buildSortTile(SortOption.priceHighToLow, 'Pricing: High to Low', Icons.trending_up),
              _buildSortTile(SortOption.preferredVehicle, 'Preferred Vehicle First', Icons.directions_car),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortTile(SortOption option, String title, IconData icon) {
    final isSelected = _activeSort == option;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primary : Colors.grey),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.primary : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check_circle, color: AppColors.primary) : null,
      onTap: () {
        setState(() => _activeSort = option);
        Navigator.pop(context);
      },
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChipWidget(
                          label: 'All',
                          count: widget.orders.length,
                          isActive: _activeFilter == SearchFilter.all,
                          onTap: () => setState(() => _activeFilter = SearchFilter.all),
                        ),
                        const SizedBox(width: 8),
                        _FilterChipWidget(
                          label: 'Urgent',
                          count: widget.orders.where((o) => o.isUrgent == true).length,
                          isActive: _activeFilter == SearchFilter.urgentDelivery,
                          onTap: () => setState(() => _activeFilter = SearchFilter.urgentDelivery),
                        ),
                        const SizedBox(width: 8),
                        _FilterChipWidget(
                          label: 'Preferred Mode',
                          count: widget.orders.where((o) => o.preferenceTransport?.any((v) => v.toLowerCase() == widget.searchedVehicle.toLowerCase()) ?? false).length,
                          isActive: _activeFilter == SearchFilter.preferredMode,
                          onTap: () => setState(() => _activeFilter = SearchFilter.preferredMode),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Order List
          Expanded(
            child: _processedOrders.isEmpty
                ? const _EmptyState()
                : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _processedOrders.length,
              itemBuilder: (context, index) {
                final order = _processedOrders[index];
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
          border: Border.all(color: isActive ? AppColors.primary : Colors.grey.shade300),
        ),
        child: Row(
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
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : Colors.grey[700],
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
  final String Function(String) formatDate;
  final String searchedVehicle;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.formatDate,
    required this.searchedVehicle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrice = order.calculatedPrice != null && order.calculatedPrice! > 0;

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${order.origin} → ${order.destination}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasPrice)
                    Text(
                      '₹${order.calculatedPrice!.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(order.itemDescription, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  const SizedBox(width: 12),
                  Icon(Icons.scale_outlined, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(order.weight, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Delivery: ${formatDate(order.deliveryDate)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (order.isUrgent == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4)),
                      child: Text('URGENT', style: TextStyle(fontSize: 10, color: Colors.red[700], fontWeight: FontWeight.bold)),
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
            style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
