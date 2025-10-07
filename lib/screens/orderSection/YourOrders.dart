import 'package:flutter/material.dart';
import 'dart:async';
import '../../Controllers/OrderService.dart';
import '../../Controllers/TripRequestService.dart';
import '../../Controllers/AuthService.dart'; // ✅ ADDED
import '../Inbox Section/indoxscreen.dart';
import '../../Models/OrderModel.dart' as OrderModels;
import '../../Models/TripRequestModel.dart';
import '../../screens/orderSection/OrderCard.dart';
import 'TravellerCard.dart';

// Local models for UI display
class OrderDisplay {
  final int id;
  final int userId;
  final String userName;
  final String senderInitial;
  final String origin;
  final String destination;
  final String date;
  final String itemDescription;
  final double weight;
  final String status;
  final String? profileImageUrl;
  final int? matchedTravellerId;
  final double? originLatitude;
  final double? originLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? orderType;
  final double? estimatedDistance;
  final int? expectedPrice;
  final String? requestStatus;
  final String? notes;
  final String? imageUrl;

  OrderDisplay({
    required this.id,
    required this.userId,
    required this.userName,
    required this.senderInitial,
    required this.origin,
    required this.destination,
    required this.date,
    required this.itemDescription,
    required this.weight,
    required this.status,
    this.profileImageUrl,
    this.matchedTravellerId,
    this.originLatitude,
    this.originLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
    this.orderType,
    this.estimatedDistance,
    this.expectedPrice,
    this.requestStatus,
    this.notes,
    this.imageUrl,
  });
}

class TripRequestDisplay {
  final int id;
  final int orderId;
  final int travellerId;
  final String travellerName;
  final String vehicleInfo;
  final String pickupTime;
  final String dropoffTime;
  final String status;
  final String? profileImageUrl;

  TripRequestDisplay({
    required this.id,
    required this.orderId,
    required this.travellerId,
    required this.travellerName,
    required this.vehicleInfo,
    required this.pickupTime,
    required this.dropoffTime,
    required this.status,
    this.profileImageUrl,
  });
}

class YourOrdersPage extends StatefulWidget {
  const YourOrdersPage({Key? key}) : super(key: key);

  @override
  State<YourOrdersPage> createState() => _YourOrdersPageState();
}

class _YourOrdersPageState extends State<YourOrdersPage>
    with SingleTickerProviderStateMixin {
  // Services
  final OrderService _orderService = OrderService();
  final TripRequestService _tripRequestService = TripRequestService();

  // ✅ CHANGED: Fetch from AuthService instead of hardcoding
  int? currentUserId;

  late TabController _tabController;
  Timer? _refreshTimer;

  // Data
  List<OrderDisplay> myOrders = [];
  List<OrderDisplay> myRequestedOrders = [];
  Map<int, List<TripRequestDisplay>> tripRequestsByOrder = {};
  bool isLoadingMyOrders = false;
  bool isLoadingMyRequests = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeUser(); // ✅ ADDED

    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (currentUserId != null) {
        _loadAllData();
      }
    });
  }

  // ✅ ADDED: Initialize user from AuthService
  Future<void> _initializeUser() async {
    try {
      final userId = await AuthService.getUserId();

      if (userId == null) {
        print('❌ No user ID found in AuthService');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in again'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        currentUserId = userId;
      });

      print('✅ User ID loaded from AuthService: $userId');
      await _loadAllData();
    } catch (e) {
      print('❌ Error initializing user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // Load all data from API
  Future<void> _loadAllData() async {
    if (currentUserId == null) {
      print('⚠️ Cannot load data - no user ID');
      return;
    }

    await Future.wait([
      _loadMyOrders(),
      _loadMyRequestedOrders(),
    ]);
  }

  // Load user's created orders from API
  Future<void> _loadMyOrders() async {
    if (currentUserId == null) return; // ✅ ADDED safety check

    setState(() {
      isLoadingMyOrders = true;
    });

    try {
      print('🔍 Loading orders for user: $currentUserId');
      final orders = await _orderService.getMyOrders(currentUserId!);
      print('📦 Received ${orders.length} orders');

      final List<OrderDisplay> displayOrders = [];

      for (var order in orders) {
        displayOrders.add(OrderDisplay(
          id: order.id,
          userId: currentUserId!,
          userName: 'You',
          senderInitial: 'Y',
          origin: order.origin,
          destination: order.destination,
          date: order.deliveryDate,
          itemDescription: order.itemDescription,
          weight: order.weight,
          status: order.status,
          originLatitude: order.originLatitude,
          originLongitude: order.originLongitude,
          destinationLatitude: order.destinationLatitude,
          destinationLongitude: order.destinationLongitude,
          orderType: 'send',
          estimatedDistance: order.distanceKm,
          expectedPrice: order.expectedPrice,
          notes: order.specialInstructions,
          imageUrl: order.imageUrl,
        ));
      }

      // Load trip requests for each order
      if (orders.isNotEmpty) {
        await _loadTripRequestsForOrders(orders.map((o) => o.id).toList());
      }

      setState(() {
        myOrders = displayOrders;
        isLoadingMyOrders = false;
      });

      print('✅ Loaded ${displayOrders.length} orders successfully');
    } catch (e) {
      print('❌ Error loading my orders: $e');
      setState(() {
        isLoadingMyOrders = false;
        myOrders = [];
      });
    }
  }

  // Load trip requests for user's orders
  Future<void> _loadTripRequestsForOrders(List<int> orderIds) async {
    if (currentUserId == null) return; // ✅ ADDED safety check

    try {
      print('🔍 Loading trip requests for orders: $orderIds');

      final allRequests = await _tripRequestService.getMyTripRequests(currentUserId!);
      print('📦 Got ${allRequests.length} total trip requests');

      Map<int, List<TripRequestDisplay>> requestsByOrder = {};

      for (var request in allRequests) {
        print('Processing request: ID=${request.id}, OrderID=${request.orderId}, TravelerID=${request.travelerId}, Status=${request.status}');

        // Only show requests where currentUser created the order
        // The traveler (who sent request) should be different from current user
        if (request.status == 'pending' && orderIds.contains(request.orderId)) {
          final displayRequest = TripRequestDisplay(
            id: request.id,
            orderId: request.orderId,
            travellerId: request.travelerId,
            travellerName: 'Traveler ${request.travelerId}',
            vehicleInfo: request.vehicleInfo,
            pickupTime: request.pickupTime,
            dropoffTime: request.dropoffTime,
            status: request.status,
          );

          if (requestsByOrder.containsKey(request.orderId)) {
            requestsByOrder[request.orderId]!.add(displayRequest);
          } else {
            requestsByOrder[request.orderId] = [displayRequest];
          }

          print('✅ Added request to order ${request.orderId}');
        }
      }

      print('📊 Total requests by order: ${requestsByOrder.length}');

      setState(() {
        tripRequestsByOrder = requestsByOrder;
      });
    } catch (e) {
      print('❌ Error loading trip requests: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load trip requests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Load orders where user sent trip requests (as traveler)
  Future<void> _loadMyRequestedOrders() async {
    if (currentUserId == null) return; // ✅ ADDED safety check

    setState(() {
      isLoadingMyRequests = true;
    });

    try {
      print('🔍 Loading trip requests sent by user: $currentUserId');

      // Get all trip requests sent by this user (as traveler)
      final tripRequests = await _tripRequestService.getMyTripRequests(currentUserId!);
      print('📦 Found ${tripRequests.length} trip requests');

      final List<OrderDisplay> displayOrders = [];
      final Set<int> processedOrderIds = {};

      for (var request in tripRequests) {
        // Only show requests where current user is the TRAVELER
        if (request.travelerId != currentUserId) {
          print('⏭️ Skipping request ${request.id} - not sent by current user');
          continue;
        }

        if (processedOrderIds.contains(request.orderId)) {
          print('⏭️ Skipping duplicate order ${request.orderId}');
          continue;
        }

        processedOrderIds.add(request.orderId);

        // Use order data from trip request response
        displayOrders.add(OrderDisplay(
          id: request.orderId,
          userId: request.orderId, // Order creator's user ID
          userName: 'Order Creator',
          senderInitial: 'O',
          origin: request.source,
          destination: request.destination,
          date: request.travelDate,
          itemDescription: 'Package delivery',
          weight: 0.0,
          status: request.status,
          orderType: 'receive',
          requestStatus: request.status,
          notes: request.vehicleInfo,
        ));

        print('✅ Added order ${request.orderId} to My Requests');
      }

      setState(() {
        myRequestedOrders = displayOrders;
        isLoadingMyRequests = false;
      });

      print('✅ Loaded ${displayOrders.length} requested orders');
    } catch (e) {
      print('❌ Error loading requested orders: $e');
      setState(() {
        isLoadingMyRequests = false;
        myRequestedOrders = [];
      });
    }
  }

  void _openOrderTracking(OrderDisplay order) {
    if (order.originLatitude == null || order.destinationLatitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order coordinates not available for tracking'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _buildTrackingPlaceholder(order),
      ),
    );
  }

  Widget _buildTrackingPlaceholder(OrderDisplay order) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking Order #${order.id}'),
        backgroundColor: const Color(0xFF0A1A2A),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Tracking feature coming soon!'),
          ],
        ),
      ),
    );
  }

  Future<void> _markOrderReceived(OrderDisplay order) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mark as received feature coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _openInbox() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const InboxScreen(),
      ),
    );
  }

  Future<void> _acceptTripRequest(
      TripRequestDisplay request, int orderId) async {
    if (currentUserId == null) return; // ✅ ADDED safety check

    try {
      final negotiatedPrice = await _showPriceNegotiationDialog(request);
      // if (negotiatedPrice == null) return;

      final acceptRequest = TripRequestAcceptRequest(
        orderCreatorId: currentUserId!,
        tripRequestId: request.id,
        negotiatedPrice: negotiatedPrice!,
      );

      final response =
      await _tripRequestService.acceptTripRequest(acceptRequest);

      if (response != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Trip request accepted! Transaction ID: #${response.transactionId}'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAllData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to accept trip request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<int?> _showPriceNegotiationDialog(TripRequestDisplay request) async {
    final priceController = TextEditingController();

    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Accept Trip Request',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Traveler: ${request.travellerName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.info_outline, 'Vehicle Info', request.vehicleInfo),
                  const SizedBox(height: 4),
                  _buildInfoRow(Icons.access_time, 'Pickup Time', request.pickupTime),
                  const SizedBox(height: 4),
                  _buildInfoRow(Icons.access_time_filled, 'Dropoff Time', request.dropoffTime),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // TextField(
            //   controller: priceController,
            //   keyboardType: TextInputType.number,
            //   decoration: InputDecoration(
            //     labelText: 'Negotiated Price (₹)*',
            //     hintText: 'Enter amount',
            //     prefixIcon: const Icon(Icons.currency_rupee),
            //     border: OutlineInputBorder(
            //       borderRadius: BorderRadius.circular(8),
            //     ),
            //   ),
            // ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final price = int.tryParse(priceController.text.trim());
              if (price == null || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid price'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context, price);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Accept', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blue[700]),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ ADDED: Show loading state while fetching user ID
    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Your Orders'),
          backgroundColor: const Color(0xFF0A1A2A),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Your Orders',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0A1A2A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.inbox),
            onPressed: _openInbox,
            tooltip: 'Inbox',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.send),
              text: 'My Orders',
            ),
            Tab(
              icon: Icon(Icons.delivery_dining),
              text: 'My Requests',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyOrdersTab(),
          _buildMyRequestedOrdersTab(),
        ],
      ),
    );
  }

  Widget _buildMyOrdersTab() {
    if (isLoadingMyOrders && myOrders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (myOrders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No Orders Yet',
        subtitle: 'Create your first order to get started',
        actionText: 'Refresh',
        onAction: _loadMyOrders,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: myOrders.length,
        itemBuilder: (context, index) {
          final order = myOrders[index];
          final requests = tripRequestsByOrder[order.id] ?? [];

          return ModernSenderOrderCard(
            order: order,
            tripRequests: requests,
            onAcceptRequest: _acceptTripRequest,
            onTrackOrder: () => _openOrderTracking(order),
            onMarkReceived: () => _markOrderReceived(order),
          );
        },
      ),
    );
  }

  Widget _buildMyRequestedOrdersTab() {
    if (isLoadingMyRequests && myRequestedOrders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (myRequestedOrders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.delivery_dining_outlined,
        title: 'No Trip Requests Yet',
        subtitle:
        'Search for available orders and send trip requests to see them here',
        actionText: 'Refresh',
        onAction: _loadMyRequestedOrders,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyRequestedOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: myRequestedOrders.length,
        itemBuilder: (context, index) {
          return ModernTravellerOrderCard(
            order: myRequestedOrders[index],
            onTrackOrder: () => _openOrderTracking(myRequestedOrders[index]),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: Text(actionText),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A1A2A),
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
