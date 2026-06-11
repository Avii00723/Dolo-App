// YourOrders Page - Full UI Restored with fixes for "User not found" error
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
import '../BackendDownScreen.dart';


class OrderDisplay {
  String? get travelerName => userName;

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
  final double? actualWeight;
  final String? customCategory;
  final List<String>? preferenceTransport;
  final bool? isUrgent;
  final String? createdAt;
  final String? otp;
  final String? myRatingStatus;
  final String? otherUserRatingStatus;
  final String? pickupConfirmationStatus;

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
    this.actualWeight,
    this.customCategory,
    this.preferenceTransport,
    this.isUrgent,
    this.createdAt,
    this.otp,
    this.myRatingStatus,
    this.otherUserRatingStatus,
    this.pickupConfirmationStatus,
  });

  OrderDisplay copyWith({
    String? userName,
    String? senderInitial,
    String? status,
    String? requestStatus,
    String? matchedTravellerId,
    String? otp,
    String? myRatingStatus,
    String? otherUserRatingStatus,
    String? pickupConfirmationStatus,
  }) {
    return OrderDisplay(
      id: id,
      userId: userId,
      userName: userName ?? this.userName,
      senderInitial: senderInitial ?? this.senderInitial,
      origin: origin,
      destination: destination,
      date: date,
      deliveryTime: deliveryTime,
      itemDescription: itemDescription,
      weight: weight,
      status: status ?? this.status,
      profileImageUrl: profileImageUrl,
      matchedTravellerId: matchedTravellerId ?? this.matchedTravellerId,
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
      actualWeight: actualWeight,
      customCategory: customCategory,
      preferenceTransport: preferenceTransport,
      isUrgent: isUrgent,
      createdAt: createdAt,
      otp: otp ?? this.otp,
      myRatingStatus: myRatingStatus ?? this.myRatingStatus,
      otherUserRatingStatus: otherUserRatingStatus ?? this.otherUserRatingStatus,
      pickupConfirmationStatus: pickupConfirmationStatus ?? this.pickupConfirmationStatus,
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
  final String? focusOrderId;

  const YourOrdersPage({
    super.key,
    this.initialTabIndex = 0,
    this.focusOrderId,
  });

  @override
  State<YourOrdersPage> createState() => _YourOrdersPageState();
}

class _YourOrdersPageState extends State<YourOrdersPage> with WidgetsBindingObserver {
  final OrderService _orderService = OrderService();
  final TripRequestService _tripRequestService = TripRequestService();
  final OrderTrackingService _trackingService = OrderTrackingService();
  String? currentUserId;
  Timer? _refreshTimer;

  int _selectedTab = 0;

  List<OrderDisplay> myOrders = [];
  List<OrderDisplay> myRequestedOrders = [];
  Map<String, List<TripRequestDisplay>> tripRequestsByOrder = {};
  bool isLoadingMyOrders = false;
  bool isLoadingMyRequests = false;
  String? _backendErrorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedTab = widget.initialTabIndex.clamp(0, 1).toInt();
    _initializeUser();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
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
      if (userId == null) return;
      setState(() => currentUserId = userId);
      await _loadAllData();
    } catch (e) {
      debugPrint('Error: $e');
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
      
      // Clear backend error if successful
      if (mounted) setState(() => _backendErrorMessage = null);
      
      final List<OrderDisplay> displayOrders = orders.map((order) => OrderDisplay(
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
        otp: order.deliveryOtp,
      )).toList();

      final acceptedRequestsByOrder = orders.isNotEmpty
          ? (await _loadTripRequestsForOrders(orders.map((o) => o.id).toList())) ?? {}
          : {};

      final namedOrders = displayOrders.map((order) {
        final acceptedRequest = acceptedRequestsByOrder[order.id];
        final travellerName = acceptedRequest?.counterpartName?.trim() ?? acceptedRequest?.travelerName?.trim();
        return acceptedRequest == null
            ? order
            : order.copyWith(
          userName: travellerName?.isNotEmpty == true ? travellerName : acceptedRequest.travelerId,
          senderInitial: travellerName?.isNotEmpty == true ? travellerName![0].toUpperCase() : 'T',
          matchedTravellerId: acceptedRequest.travelerId,
        );
      }).toList();

      final trackedOrders = _prioritizeFocusedOrder(await _applyTrackingStatus(namedOrders));

      if (mounted) {
        setState(() {
          myOrders = trackedOrders;
          isLoadingMyOrders = false;
        });
      }
    } on Exception catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('BACKEND_DOWN')) {
        if (mounted) {
          setState(() {
            _backendErrorMessage = 'App will resume shortly';
            isLoadingMyOrders = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoadingMyOrders = false);
      }
    }
  }

  Future<Map<String, TripRequest>?> _loadTripRequestsForOrders(List<String> orderIds) async {
    if (currentUserId == null) return null;
    try {
      final allRequests = await _tripRequestService.getTripRequestsForMyOrders(currentUserId!);
      Map<String, List<TripRequestDisplay>> requestsByOrder = {};
      Map<String, TripRequest> acceptedRequestsByOrder = {};

      final acceptedLikeStatuses = {
        'accepted',
        'matched',
        'delivered',
        'completed',
        'in_transit',
        'in-transit',
        'picked_up',
        'picked up',
        'arrived',
      };

      for (var request in allRequests) {
        final status = request.status.toLowerCase();
        if (acceptedLikeStatuses.contains(status) && orderIds.contains(request.orderId)) {
          acceptedRequestsByOrder[request.orderId] = request;
        }

        if (status == 'pending' && orderIds.contains(request.orderId)) {
          final displayRequest = TripRequestDisplay(
            id: request.id,
            orderId: request.orderId,
            travellerId: request.travelerId,
            travellerName: request.counterpartName?.trim() ?? request.travelerName?.trim() ?? 'Traveller',
            vehicleInfo: request.vehicleInfo,
            departureDatetime: request.departureDatetime,
            travelDate: request.travelDate,
            status: request.status,
          );
          requestsByOrder.putIfAbsent(request.orderId, () => []).add(displayRequest);
        }
      }

      if (mounted) setState(() => tripRequestsByOrder = requestsByOrder);
      return acceptedRequestsByOrder;
    } on Exception catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('BACKEND_DOWN')) {
        if (mounted) {
          setState(() => _backendErrorMessage = 'App will resume shortly');
        }
      }
      return null;
    }
  }

  Future<void> _loadMyRequestedOrders({bool silent = false}) async {
    if (currentUserId == null) return;
    if (!silent) setState(() => isLoadingMyRequests = true);

    try {
      final tripRequests = await _tripRequestService.getMyTripRequests(currentUserId!);
      
      // Clear backend error if successful
      if (mounted) setState(() => _backendErrorMessage = null);
      
      final List<OrderDisplay> displayOrders = [];
      final Set<String> processedOrderIds = {};

      for (var request in tripRequests) {
        if (processedOrderIds.contains(request.orderId)) continue;
        processedOrderIds.add(request.orderId);
        final orderCreatorName = request.orderCreatorName?.trim() ?? request.counterpartName?.trim() ?? 'Order Creator';

        displayOrders.add(OrderDisplay(
          id: request.orderId,
          userId: currentUserId!,
          userName: orderCreatorName,
          senderInitial: orderCreatorName.isNotEmpty ? orderCreatorName[0].toUpperCase() : 'O',
          origin: request.source,
          destination: request.destination,
          date: request.travelDate,
          itemDescription: 'Package delivery',
          weight: '0kg',
          status: request.status,
          orderType: 'receive',
          requestStatus: request.status,
          tripRequestId: request.id,
        ));
      }

      final trackedOrders = _prioritizeFocusedOrder(await _applyTrackingStatus(displayOrders));

      if (mounted) {
        setState(() {
          myRequestedOrders = trackedOrders;
          isLoadingMyRequests = false;
        });
      }
    } on Exception catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('BACKEND_DOWN')) {
        if (mounted) {
          setState(() {
            _backendErrorMessage = 'App will resume shortly';
            isLoadingMyRequests = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoadingMyRequests = false);
      }
    }
  }

  Future<List<OrderDisplay>> _applyTrackingStatus(List<OrderDisplay> orders) async {
    return Future.wait(orders.map((order) async {
      final status = order.status.toLowerCase();
      if (status == 'cancelled' || status == 'rejected') return order;

      // Fetch both order details and OTP in parallel.
      final results = await Future.wait([
        _trackingService.getOrderDetails(order.id),
        _trackingService.getOrderOtp(order.id).catchError((_) => null),
      ]);

      final details = results[0] as Map<String, dynamic>?;
      final otpData = results[1] as Map<String, dynamic>?;

      if (details == null) return order;

      final apiOrder = details['order'] as Map<String, dynamic>?;
      final currentStage = OrderTrackingService.currentStageFromHistory(details);
      final apiStatus = currentStage == null
          ? (apiOrder?['status']?.toString())
          : OrderTrackingService.statusFromStage(currentStage);

      // Prefer the dedicated OTP endpoint, fall back to order fields.
      final String? resolvedOtp = _cleanOtp(otpData?['otp'])
          ?? _cleanOtp(apiOrder?['delivery_otp'])
          ?? _cleanOtp(apiOrder?['otp'])
          ?? order.otp;

      return order.copyWith(
        status: apiStatus ?? order.status,
        otp: resolvedOtp,
        myRatingStatus: apiOrder?['my_rating_status']?.toString()
            ?? details['my_rating_status']?.toString(),
        pickupConfirmationStatus:
        apiOrder?['pickup_confirmation_status']?.toString()
            ?? details['pickup_confirmation_status']?.toString(),
      );
    }));
  }

  String? _cleanOtp(dynamic raw) {
    final v = raw?.toString().trim();
    return (v == null || v.isEmpty || v == 'null') ? null : v;
  }

  /// Opens the detail card for an order — always shows the full tracking UI
  /// (OTP, confirm pickup, timeline, status buttons) appropriate to the user's role.
  void _openCard(OrderDisplay order) {
    if (_selectedTab == 1) {
      // Traveller view
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TravellerOrderDetailScreen(
            order: order,
            onUpdateStatus: _updateTravellerStatus,
            onCompleteOrderWithOtp: _completeTravellerOrderWithOtp,
            onWithdrawRequest: _withdrawTripRequest,
            onConfirmPickup: _confirmPickup,
          ),
        ),
      ).then((_) => _loadAllData(silent: true));
    } else {
      // Sender view
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(
            order: order,
            tripRequests: tripRequestsByOrder[order.id],
            onAcceptRequest: _acceptTripRequest,
            onDeclineRequest: _declineTripRequest,
            onTrackOrder: () => _openTrackingMap(order),
            onMarkReceived: () => _markOrderReceived(order),
            onCompleteOrder: () => _completeOrder(order),
            onUpdateOrder: _updateOrder,
            onDeleteOrder: _deleteOrder,
            onCompleteOrderWithOtp: _completeTravellerOrderWithOtp,
            onConfirmPickup: _confirmPickup,
          ),
        ),
      ).then((_) => _loadAllData(silent: true));
    }
  }

  /// Opens the detail card for the order using the modern card UI.
  void _openTrackingMap(OrderDisplay order) => _openCard(order);

  /// Legacy alias kept so existing tap handlers in cards still compile.
  void _viewRoute(OrderDisplay order) => _openCard(order);

  Future<void> _acceptTripRequest(TripRequestDisplay request, String orderId) async {
    if (currentUserId == null) return;
    try {
      final response = await _tripRequestService.acceptTripRequest(TripRequestAcceptRequest(
        orderCreatorId: currentUserId!,
        tripRequestId: request.id,
        negotiatedPrice: 0,
      ));
      if (response != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.message), backgroundColor: Colors.green));
        _loadAllData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _declineTripRequest(TripRequestDisplay request, String orderId) async {
    if (currentUserId == null) return;
    try {
      final response = await _tripRequestService.declineTripRequest(TripRequestDeclineRequest(
        orderCreatorHashedId: currentUserId!,
        tripRequestId: request.id,
      ));
      if (response != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.message), backgroundColor: Colors.orange));
        _loadAllData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _withdrawTripRequest(String tripRequestId) async {
    if (currentUserId == null) return;
    try {
      final response = await _tripRequestService.withdrawTripRequest(TripRequestWithdrawRequest(
        travelerHashedId: currentUserId!,
        tripRequestHashedId: tripRequestId,
      ));
      if (response != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.message), backgroundColor: Colors.orange));
        _loadAllData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteTripRequest(String tripRequestId) async {
    try {
      final success = await _tripRequestService.deleteTripRequest(tripRequestId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip request deleted'), backgroundColor: Colors.blue));
        _loadAllData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _updateOrder(OrderDisplay updatedOrder) async {
    if (currentUserId == null) return;
    try {
      final response = await _orderService.updateOrder(updatedOrder.id, OrderModels.OrderUpdateRequest(
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
      ));
      if (response != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order updated successfully'), backgroundColor: Colors.green));
        _loadAllData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteOrder(String orderId) async {
    if (currentUserId == null) return;
    try {
      final success = await _orderService.deleteOrder(orderId, currentUserId!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order deleted'), backgroundColor: Colors.blue));
        _loadAllData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _markOrderReceived(OrderDisplay order) async {
    if (currentUserId == null) return;
    try {
      final success = await _orderService.completeOrder(order.id, currentUserId!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order marked as received'), backgroundColor: Colors.green));
        _loadAllData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _completeOrder(OrderDisplay order) async {
    if (currentUserId == null) return;
    try {
      final success = await _orderService.completeOrder(order.id, currentUserId!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order completed successfully'), backgroundColor: Colors.green));
        _loadAllData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _updateTravellerStatus(String orderId, int stage) async {
    try {
      print('YourOrders: updating tracking stage $stage for $orderId');
      await _trackingService.updateTrackingStage(orderId, stage);
      print('YourOrders: updateTrackingStage completed for $orderId (stage $stage)');
      _loadAllData(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _completeTravellerOrderWithOtp(String orderId, String otp) async {
    try {
      await _trackingService.verifyOtpAndComplete(orderId, otp);
      _loadAllData(silent: true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _confirmPickup(String orderId, bool confirmed) async {
    await _trackingService.confirmPickup(
      orderHashedId: orderId,
      confirmed: confirmed,
      userHashedId: currentUserId,
    );
    _loadAllData(silent: true);
  }

  List<OrderDisplay> _prioritizeFocusedOrder(List<OrderDisplay> orders) {
    final focusOrderId = widget.focusOrderId?.trim().toLowerCase();
    if (focusOrderId == null || focusOrderId.isEmpty) return orders;
    final sorted = List<OrderDisplay>.from(orders);
    sorted.sort((a, b) {
      final aMatches = a.id.trim().toLowerCase() == focusOrderId;
      final bMatches = b.id.trim().toLowerCase() == focusOrderId;
      if (aMatches == bMatches) return 0;
      return aMatches ? -1 : 1;
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: const Text('Your Orders', style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w800)),
        actions: [
          NotificationBellIcon(onNotificationHandled: () => _loadAllData()),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadAllData()),
          IconButton(icon: const Icon(Icons.inbox_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen()))),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
          // Backend down banner
          if (_backendErrorMessage != null)
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BackendDownScreen(),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.orange.shade100,
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _backendErrorMessage!,
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildTab(0, 'Packages sent'),
                  _buildTab(1, 'Trips posted'),
                ],
              ),
            ),
          ),
          Expanded(child: _selectedTab == 0 ? _buildMyOrdersTab() : _buildMyRequestedOrdersTab()),
        ],
      ),
      ));
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(26)),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _buildMyOrdersTab() {
    if (isLoadingMyOrders && myOrders.isEmpty) return const Center(child: CircularProgressIndicator());
    if (myOrders.isEmpty) return _buildEmptyState(icon: Icons.inventory_2_outlined, title: 'No Packages Sent Yet', subtitle: 'Create your first order to get started', onAction: () => _loadMyOrders());

    return RefreshIndicator(
      onRefresh: () => _loadMyOrders(),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
        itemCount: myOrders.length,
        itemBuilder: (context, index) {
          final order = myOrders[index];
          return ModernSenderOrderCard(
            order: order,
            tripRequests: tripRequestsByOrder[order.id] ?? [],
            onAcceptRequest: _acceptTripRequest,
            onDeclineRequest: _declineTripRequest,
            onTrackOrder: () => _openCard(order),
            onMarkReceived: () => _markOrderReceived(order),
            onCompleteOrder: () => _completeOrder(order),
            onUpdateOrder: _updateOrder,
            onDeleteOrder: _deleteOrder,
            onCompleteOrderWithOtp: _completeTravellerOrderWithOtp,
            onConfirmPickup: _confirmPickup,
          );
        },
      ),
    );
  }

  Widget _buildMyRequestedOrdersTab() {
    if (isLoadingMyRequests && myRequestedOrders.isEmpty) return const Center(child: CircularProgressIndicator());
    if (myRequestedOrders.isEmpty) return _buildEmptyState(icon: Icons.delivery_dining_outlined, title: 'No Trips Posted Yet', subtitle: 'Your trip requests will appear here', onAction: () => _loadMyRequestedOrders());

    return RefreshIndicator(
      onRefresh: () => _loadMyRequestedOrders(),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
        itemCount: myRequestedOrders.length,
        itemBuilder: (context, index) {
          final order = myRequestedOrders[index];
          return ModernTravellerOrderCard(
            order: order,
            onTrackOrder: () => _openCard(order),
            onWithdrawRequest: _withdrawTripRequest,
            onDeleteRequest: _deleteTripRequest,
            onUpdateStatus: _updateTravellerStatus,
            onCompleteOrderWithOtp: _completeTravellerOrderWithOtp,
            onConfirmPickup: _confirmPickup,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle, required VoidCallback onAction}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]), child: Icon(icon, size: 40, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3))),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)), textAlign: TextAlign.center),
            const SizedBox(height: 28),
            ElevatedButton.icon(onPressed: onAction, icon: const Icon(Icons.refresh, size: 18), label: const Text('Refresh'), style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0)),
          ],
        ),
      ),
    );
  }
}
