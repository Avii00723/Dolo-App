// YourOrders Page - Redesigned to match new UI design
// Features: "Packages sent" | "Trips posted" toggle tabs, card list

import 'package:flutter/material.dart';
import 'dart:async';
import '../../Controllers/OrderService.dart';
import '../../Controllers/TripRequestService.dart';
import '../../Controllers/AuthService.dart';
import '../../Controllers/ordertrackingservice.dart';
import '../Inbox Section/indoxscreen.dart';
import '../../Models/OrderModel.dart' as OrderModels;
import '../../Models/TripRequestModel.dart';
import '../../screens/orderSection/OrderCard.dart';
import '../../widgets/NotificationBellIcon.dart';
import 'TravellerCard.dart';
import '../CustomRouteMapScreen.dart';

class OrderDisplay {
  final String id;
  final String userId;
  final String userName;
  final String senderInitial;
  final String origin;
  final String destination;
  final String date;
  final String? deliveryTime;
  final String itemDescription;
  final String weight;
  final String status;
  final String? profileImageUrl;
  final String? matchedTravellerId;
  final double originLatitude;
  final double originLongitude;
  final double destinationLatitude;
  final double destinationLongitude;
  final String? orderType;
  final double? estimatedDistance;
  final int? expectedPrice;
  final String? requestStatus;
  final String? notes;
  final String? imageUrl;
  final String? tripRequestId;
  final String? category;
  final List<String>? preferenceTransport;
  final bool? isUrgent;
  final String? createdAt;
  final String? otp; // Added otp field

  OrderDisplay({
    required this.id,
    required this.userId,
    required this.userName,
    required this.senderInitial,
    required this.origin,
    required this.destination,
    required this.date,
    this.deliveryTime,
    required this.itemDescription,
    required this.weight,
    required this.status,
    this.profileImageUrl,
    this.matchedTravellerId,
    this.originLatitude = 0.0,
    this.originLongitude = 0.0,
    this.destinationLatitude = 0.0,
    this.destinationLongitude = 0.0,
    this.orderType,
    this.estimatedDistance,
    this.expectedPrice,
    this.requestStatus,
    this.notes,
    this.imageUrl,
    this.tripRequestId,
    this.category,
    this.preferenceTransport,
    this.isUrgent,
    this.createdAt,
    this.otp, // Added to constructor
  });

  OrderDisplay copyWith({
    String? status,
    String? requestStatus,
    String? otp,
  }) {
    return OrderDisplay(
      id: id,
      userId: userId,
      userName: userName,
      senderInitial: senderInitial,
      origin: origin,
      destination: destination,
      date: date,
      deliveryTime: deliveryTime,
      itemDescription: itemDescription,
      weight: weight,
      status: status ?? this.status,
      profileImageUrl: profileImageUrl,
      matchedTravellerId: matchedTravellerId,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      orderType: orderType,
      estimatedDistance: estimatedDistance,
      expectedPrice: expectedPrice,
      requestStatus: requestStatus ?? this.requestStatus,
      notes: notes,
      imageUrl: imageUrl,
      tripRequestId: tripRequestId,
      category: category,
      preferenceTransport: preferenceTransport,
      isUrgent: isUrgent,
      createdAt: createdAt,
      otp: otp ?? this.otp,
    );
  }
}

class TripRequestDisplay {
  final String id;
  final String orderId;
  final String travellerId;
  final String travellerName;
  final String vehicleInfo;
  final String departureDatetime;
  final String travelDate;
  final String status;
  final String? profileImageUrl;

  TripRequestDisplay({
    required this.id,
    required this.orderId,
    required this.travellerId,
    required this.travellerName,
    required this.vehicleInfo,
    required this.departureDatetime,
    required this.travelDate,
    required this.status,
    this.profileImageUrl,
  });
}

class YourOrdersPage extends StatefulWidget {
  final int initialTabIndex;

  const YourOrdersPage({super.key, this.initialTabIndex = 0});

  @override
  State<YourOrdersPage> createState() => _YourOrdersPageState();
}

class _YourOrdersPageState extends State<YourOrdersPage>
    with WidgetsBindingObserver {
  final OrderService _orderService = OrderService();
  final TripRequestService _tripRequestService = TripRequestService();
  final OrderTrackingService _trackingService = OrderTrackingService();
  String? currentUserId;
  Timer? _refreshTimer;

  // 0 = Packages sent, 1 = Trips posted
  int _selectedTab = 0;

  List<OrderDisplay> myOrders = [];
  List<OrderDisplay> myRequestedOrders = [];
  Map<String, List<TripRequestDisplay>> tripRequestsByOrder = {};
  bool isLoadingMyOrders = false;
  bool isLoadingMyRequests = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeUser();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (currentUserId != null && mounted) {
        _loadAllData(silent: true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && currentUserId != null) {
      _loadAllData();
    }
  }

  Future<void> _initializeUser() async {
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) {
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
      await _loadAllData();
    } catch (e) {
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
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData({bool silent = false}) async {
    if (currentUserId == null) return;
    await Future.wait([
      _loadMyOrders(silent: silent),
      _loadMyRequestedOrders(silent: silent),
    ]);
  }

  Future<void> _loadMyOrders({bool silent = false}) async {
    if (currentUserId == null) return;
    if (!silent) setState(() => isLoadingMyOrders = true);

    try {
      final orders = await _orderService.getMyOrders(currentUserId!);
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
          deliveryTime: order.deliveryTime,
          itemDescription: order.itemDescription,
          weight: order.weight,
          status: order.status,
          originLatitude: order.originLatitude,
          originLongitude: order.originLongitude,
          destinationLatitude: order.destinationLatitude,
          destinationLongitude: order.destinationLongitude,
          orderType: 'send',
          estimatedDistance: order.distanceKm,
          expectedPrice: order.expectedPrice ?? order.calculatedPrice?.toInt(),
          notes: order.specialInstructions,
          imageUrl: order.imageUrl,
          category: order.category,
          preferenceTransport: order.preferenceTransport,
          isUrgent: order.isUrgent,
          createdAt: order.createdAt,
          otp: order.deliveryOtp, // Map OTP from model
        ));
      }

      if (orders.isNotEmpty) {
        await _loadTripRequestsForOrders(orders.map((o) => o.id).toList());
      }

      final trackedOrders = await _applyTrackingStatus(displayOrders);

      if (mounted) {
        setState(() {
          myOrders = trackedOrders;
          isLoadingMyOrders = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingMyOrders = false;
          myOrders = [];
        });
      }
    }
  }

  Future<void> _loadTripRequestsForOrders(List<String> orderIds) async {
    if (currentUserId == null) return;
    try {
      final allRequests =
      await _tripRequestService.getTripRequestsForMyOrders(currentUserId!);
      Map<String, List<TripRequestDisplay>> requestsByOrder = {};

      for (var request in allRequests) {
        if (request.status == 'pending' && orderIds.contains(request.orderId)) {
          final displayRequest = TripRequestDisplay(
            id: request.id,
            orderId: request.orderId,
            travellerId: request.travelerId,
            travellerName: request.travelerName ?? request.travelerId,
            vehicleInfo: request.vehicleInfo,
            departureDatetime: request.departureDatetime,
            travelDate: request.travelDate,
            status: request.status,
          );

          if (requestsByOrder.containsKey(request.orderId)) {
            requestsByOrder[request.orderId]!.add(displayRequest);
          } else {
            requestsByOrder[request.orderId] = [displayRequest];
          }
        }
      }

      if (mounted) {
        setState(() {
          tripRequestsByOrder = requestsByOrder;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading trip requests: $e');
    }
  }

  Future<void> _loadMyRequestedOrders({bool silent = false}) async {
    if (currentUserId == null) return;
    if (!silent) setState(() => isLoadingMyRequests = true);

    try {
      final tripRequests =
      await _tripRequestService.getMyTripRequests(currentUserId!);
      final List<OrderDisplay> displayOrders = [];
      final Set<String> processedOrderIds = {};

      for (var request in tripRequests) {
        if (processedOrderIds.contains(request.orderId)) continue;
        processedOrderIds.add(request.orderId);

        displayOrders.add(OrderDisplay(
          id: request.orderId,
          userId: request.orderId,
          userName: request.counterpartName ?? 'Order Creator',
          senderInitial: (request.counterpartName != null && request.counterpartName!.isNotEmpty)
              ? request.counterpartName![0].toUpperCase()
              : 'O',
          origin: request.source,
          destination: request.destination,
          date: request.travelDate,
          itemDescription: 'Package delivery',
          weight: '0kg',
          status: request.status,
          orderType: 'receive',
          requestStatus: request.status,
          notes:
          '${request.vehicleInfo} • Departure: ${request.departureDatetime} • Delivery: ${request.travelDate}',
          tripRequestId: request.id,
        ));
      }

      final trackedOrders = await _applyTrackingStatus(displayOrders);

      if (mounted) {
        setState(() {
          myRequestedOrders = trackedOrders;
          isLoadingMyRequests = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingMyRequests = false;
          myRequestedOrders = [];
        });
      }
    }
  }

  // ── ACTION HANDLERS ──

  void _viewRoute(OrderDisplay order) {
    Navigator.push(
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

  Future<void> _acceptTripRequest(
      TripRequestDisplay request, String orderId) async {
    if (currentUserId == null) return;
    try {
      final acceptReq = TripRequestAcceptRequest(
        orderCreatorId: currentUserId!,
        tripRequestId: request.id,
        negotiatedPrice: 0, // In UI, you might want to ask for this
      );

      final response = await _tripRequestService.acceptTripRequest(acceptReq);
      if (response != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: Colors.green),
        );
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _declineTripRequest(
      TripRequestDisplay request, String orderId) async {
    if (currentUserId == null) return;
    try {
      final declineReq = TripRequestDeclineRequest(
        orderCreatorHashedId: currentUserId!,
        tripRequestId: request.id,
      );

      final response = await _tripRequestService.declineTripRequest(declineReq);
      if (response != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: Colors.orange),
        );
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _withdrawTripRequest(String tripRequestId) async {
    if (currentUserId == null) return;
    try {
      final withdrawReq = TripRequestWithdrawRequest(
        travelerHashedId: currentUserId!,
        tripRequestHashedId: tripRequestId,
      );

      final response = await _tripRequestService.withdrawTripRequest(withdrawReq);
      if (response != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: Colors.orange),
        );
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteTripRequest(String tripRequestId) async {
    try {
      final success = await _tripRequestService.deleteTripRequest(tripRequestId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip request deleted'), backgroundColor: Colors.blue),
        );
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateOrder(OrderDisplay updatedOrder) async {
    if (currentUserId == null) return;
    try {
      final updateReq = OrderModels.OrderUpdateRequest(
        userHashedId: currentUserId!,
        itemDescription: updatedOrder.itemDescription,
        origin: updatedOrder.origin,
        originLatitude: updatedOrder.originLatitude,
        originLongitude: updatedOrder.originLongitude,
        destination: updatedOrder.destination,
        destinationLatitude: updatedOrder.destinationLatitude,
        destinationLongitude: updatedOrder.destinationLongitude,
        deliveryDate: updatedOrder.date,
        weight: updatedOrder.weight,
        specialInstructions: updatedOrder.notes,
      );

      final response = await _orderService.updateOrder(updatedOrder.id, updateReq);
      if (response != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order updated successfully'), backgroundColor: Colors.green),
        );
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating order: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteOrder(String orderId) async {
    if (currentUserId == null) return;
    try {
      final success = await _orderService.deleteOrder(orderId, currentUserId!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order deleted'), backgroundColor: Colors.blue),
        );
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting order: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markOrderReceived(OrderDisplay order) async {
    if (currentUserId == null) return;
    try {
      final success = await _orderService.completeOrder(order.id, currentUserId!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order marked as received'), backgroundColor: Colors.green),
        );
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _completeOrder(OrderDisplay order) async {
    if (currentUserId == null) return;
    try {
      final success = await _orderService.completeOrder(order.id, currentUserId!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order completed successfully'), backgroundColor: Colors.green),
        );
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateTravellerStatus(String orderId, int stage) async {
    await _trackingService.updateTrackingStage(orderId, stage);
    _loadAllData(silent: true);
  }

  Future<void> _completeTravellerOrderWithOtp(String orderId, String otp) async {
    await _trackingService.verifyOtpAndComplete(orderId, otp);
    _loadAllData(silent: true);
  }

  Future<List<OrderDisplay>> _applyTrackingStatus(List<OrderDisplay> orders) async {
    return Future.wait(orders.map((order) async {
      final status = await _trackingService.getCurrentStatus(order.id);
      if (status == null) return order;

      return order.copyWith(
        status: status,
        requestStatus: order.requestStatus == null ? null : status,
      );
    }));
  }

  void _openInbox() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InboxScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: const Text(
          'Your Orders',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
        actions: [
          NotificationBellIcon(
            onNotificationHandled: () => _loadAllData(),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.6)),
            onPressed: () => _loadAllData(),
          ),
          IconButton(
            icon: Icon(Icons.inbox_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.6)),
            onPressed: _openInbox,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Toggle Tabs ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildTab(0, 'Packages sent'),
                  _buildTab(1, 'Trips posted'),
                ],
              ),
            ),
          ),

          // ── Tab Content ──
          Expanded(
            child: _selectedTab == 0
                ? _buildMyOrdersTab()
                : _buildMyRequestedOrdersTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
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
        title: 'No Packages Sent Yet',
        subtitle: 'Create your first order to get started',
        onAction: () => _loadMyOrders(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadMyOrders(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: myOrders.length,
        itemBuilder: (context, index) {
          final order = myOrders[index];
          final requests = tripRequestsByOrder[order.id] ?? [];
          return ModernSenderOrderCard(
            order: order,
            tripRequests: requests,
            onAcceptRequest: _acceptTripRequest,
            onDeclineRequest: _declineTripRequest,
            onTrackOrder: () => _viewRoute(order),
            onMarkReceived: () => _markOrderReceived(order),
            onCompleteOrder: () => _completeOrder(order),
            onUpdateOrder: _updateOrder,
            onDeleteOrder: _deleteOrder,
            onUpdateStatus: _updateTravellerStatus,
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
        title: 'No Trips Posted Yet',
        subtitle: 'Your trip requests will appear here',
        onAction: () => _loadMyRequestedOrders(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadMyRequestedOrders(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: myRequestedOrders.length,
        itemBuilder: (context, index) {
          final order = myRequestedOrders[index];
          return ModernTravellerOrderCard(
            order: order,
            onTrackOrder: () => _viewRoute(order),
            onWithdrawRequest: _withdrawTripRequest,
            onDeleteRequest: _deleteTripRequest,
            onUpdateStatus: _updateTravellerStatus,
            onCompleteOrderWithOtp: _completeTravellerOrderWithOtp,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 40, color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.3)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.5)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
