import 'package:dolo/Constants/ApiConstants.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../Controllers/OrderService.dart';
import '../../Controllers/TripRequestService.dart';
import '../../Controllers/AuthService.dart';
import '../Inbox Section/indoxscreen.dart';
import '../../Models/OrderModel.dart' as OrderModels;
import '../../Models/TripRequestModel.dart';
import '../../screens/orderSection/OrderCard.dart';
import 'TravellerCard.dart';

// Local models for UI display
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
  final int? tripRequestId; // ✅ ADD THIS LINE

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
    this.tripRequestId, // ✅ ADD THIS LINE
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
  final int initialTabIndex; // ✅ Parameter to set initial tab

  const YourOrdersPage({Key? key, this.initialTabIndex = 0}) : super(key: key);

  @override
  State<YourOrdersPage> createState() => _YourOrdersPageState();
}

class _YourOrdersPageState extends State<YourOrdersPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Services
  final OrderService _orderService = OrderService();
  final TripRequestService _tripRequestService = TripRequestService();
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

    // ✅ ADD: Lifecycle observer to detect app state changes
    WidgetsBinding.instance.addObserver(this);

    // ✅ UPDATED: Initialize with provided tab index
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );

    // ✅ Listen to tab changes and refresh data
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 1 && currentUserId != null) {
          print('📍 Switched to My Requests tab - refreshing...');
          _loadMyRequestedOrders();
        } else if (_tabController.index == 0 && currentUserId != null) {
          print('📍 Switched to My Orders tab - refreshing...');
          _loadMyOrders();
        }
      }
    });

    _initializeUser();

    // ✅ UPDATED: More frequent auto-refresh (every 15 seconds instead of 30)
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (currentUserId != null && mounted) {
        print('⏰ Auto-refresh triggered at ${DateTime.now()}');
        _loadAllData(silent: true); // ✅ Silent refresh to avoid UI flicker
      }
    });
  }

  // ✅ NEW: Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && currentUserId != null) {
      print('📱 App resumed - refreshing all data...');
      _loadAllData();
    }
  }

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
    WidgetsBinding.instance.removeObserver(this); // ✅ Remove observer
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // ✅ UPDATED: Support silent refresh to avoid UI flicker
  Future<void> _loadAllData({bool silent = false}) async {
    if (currentUserId == null) {
      print('⚠️ Cannot load data - no user ID');
      return;
    }

    print('🔄 Loading all data... (silent: $silent)');
    await Future.wait([
      _loadMyOrders(silent: silent),
      _loadMyRequestedOrders(silent: silent),
    ]);
    print('✅ All data loaded successfully');
  }

  // ✅ UPDATED: Add silent parameter
  Future<void> _loadMyOrders({bool silent = false}) async {
    if (currentUserId == null) return;

    if (!silent) {
      setState(() {
        isLoadingMyOrders = true;
      });
    }

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
          imageUrl: "${ApiConstants.imagebaseUrl}${order.imageUrl}",
        ));
      }

      if (orders.isNotEmpty) {
        await _loadTripRequestsForOrders(orders.map((o) => o.id).toList());
      }

      if (mounted) {
        setState(() {
          myOrders = displayOrders;
          isLoadingMyOrders = false;
        });
      }
      print('✅ Loaded ${displayOrders.length} orders successfully');
    } catch (e) {
      print('❌ Error loading my orders: $e');
      if (mounted) {
        setState(() {
          isLoadingMyOrders = false;
          myOrders = [];
        });
      }
    }
  }

  Future<void> _loadTripRequestsForOrders(List<int> orderIds) async {
    if (currentUserId == null) return;

    try {
      print('🔍 Loading trip requests for orders: $orderIds');
      final allRequests = await _tripRequestService.getMyTripRequests(currentUserId!);
      print('📦 Got ${allRequests.length} total trip requests');

      Map<int, List<TripRequestDisplay>> requestsByOrder = {};

      for (var request in allRequests) {
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
        }
      }

      print('📊 Total pending requests by order: ${requestsByOrder.length}');
      if (mounted) {
        setState(() {
          tripRequestsByOrder = requestsByOrder;
        });
      }
    } catch (e) {
      print('❌ Error loading trip requests: $e');
    }
  }

  // ✅ UPDATED: Add silent parameter
  Future<void> _loadMyRequestedOrders({bool silent = false}) async {
    if (currentUserId == null) return;

    if (!silent) {
      setState(() {
        isLoadingMyRequests = true;
      });
    }

    try {
      print('🔍 Loading trip requests sent by user: $currentUserId');
      final tripRequests = await _tripRequestService.getMyTripRequests(currentUserId!);
      print('📦 Found ${tripRequests.length} trip requests');

      final List<OrderDisplay> displayOrders = [];
      final Set<int> processedOrderIds = {};

      for (var request in tripRequests) {
        if (request.travelerId != currentUserId) {
          continue;
        }

        if (processedOrderIds.contains(request.orderId)) {
          continue;
        }

        processedOrderIds.add(request.orderId);
        displayOrders.add(OrderDisplay(
          id: request.orderId,
          userId: request.orderId,
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
          notes: '${request.vehicleInfo} • Pickup: ${request.pickupTime} • Dropoff: ${request.dropoffTime}',
          tripRequestId: request.id, // ✅ ADD THIS LINE - Store the trip request ID
        ));

        print('✅ Added order ${request.orderId} with Trip Request ID: ${request.id}');
      }

      if (mounted) {
        setState(() {
          myRequestedOrders = displayOrders;
          isLoadingMyRequests = false;
        });
      }
      print('✅ Loaded ${displayOrders.length} requested orders');
    } catch (e) {
      print('❌ Error loading requested orders: $e');
      if (mounted) {
        setState(() {
          isLoadingMyRequests = false;
          myRequestedOrders = [];
        });
      }
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

  Future<void> _completeOrder(OrderDisplay order) async {
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('User ID not found. Please log in again.'),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final ratingData = await _showRatingDialog(order);

      if (ratingData == null) {
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Completing order...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final success = await _orderService.completeOrder(order.id, currentUserId!);

      if (success && mounted) {
        print('📝 Rating: ${ratingData['rating']} stars');
        print('💬 Feedback: ${ratingData['feedback']}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Order completed successfully!'),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 3),
          ),
        );

        // ✅ Immediate refresh
        await _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to complete order';

        if (e.toString().contains('KYC_NOT_APPROVED')) {
          errorMessage = 'KYC not approved. Please complete KYC verification.';
        } else if (e.toString().contains('ORDER_NOT_FOUND')) {
          errorMessage = 'Order not found or you don\'t have permission.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showRatingDialog(OrderDisplay order) async {
    double rating = 5.0;
    final feedbackController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24), // ✅ Add padding for keyboard
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.8, // ✅ Limit max height
            ),
            // ✅ WRAP IN SINGLECHILDSCROLLVIEW for keyboard responsiveness
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[600]!, Colors.blue[400]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(0),
                        topRight: Radius.circular(0),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Rate Your Experience',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Order #${order.id}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content Section
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order Info
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.route, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${order.origin} → ${order.destination}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.inventory_2_outlined,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      order.itemDescription,
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Rating Section
                        const Text(
                          'How was the delivery?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    rating = index + 1.0;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    index < rating
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: Colors.amber[600],
                                    size: 40,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            _getRatingText(rating),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Feedback Section
                        const Text(
                          'Additional Feedback (Optional)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: feedbackController,
                          maxLines: 3,
                          maxLength: 200,
                          textInputAction: TextInputAction.done, // ✅ Add done button
                          decoration: InputDecoration(
                            hintText: 'Share your experience with the traveler...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400],
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 8), // ✅ Reduced spacing
                      ],
                    ),
                  ),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              feedbackController.dispose();
                              Navigator.pop(context, null);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              final result = {
                                'rating': rating,
                                'feedback': feedbackController.text.trim(),
                              };
                              feedbackController.dispose();
                              Navigator.pop(context, result);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Submit & Complete',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
        ),
      ),
    );
  }

  String _getRatingText(double rating) {
    if (rating <= 1) return 'Poor';
    if (rating <= 2) return 'Fair';
    if (rating <= 3) return 'Good';
    if (rating <= 4) return 'Very Good';
    return 'Excellent';
  }

  Future<void> _updateOrder(OrderDisplay updatedOrder) async {
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Updating order...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final updateRequest = OrderModels.OrderUpdateRequest(
        userId: currentUserId!,
        origin: updatedOrder.origin,
        originLatitude: updatedOrder.originLatitude!,
        originLongitude: updatedOrder.originLongitude!,
        destination: updatedOrder.destination,
        destinationLatitude: updatedOrder.destinationLatitude!,
        destinationLongitude: updatedOrder.destinationLongitude!,
        deliveryDate: _formatDateForApi(updatedOrder.date),
        weight: updatedOrder.weight,
        imageUrl: "${ApiConstants.imagebaseUrl}${updatedOrder.imageUrl}",
        specialInstructions: updatedOrder.notes,
      );

      final response = await _orderService.updateOrder(
        updatedOrder.id,
        updateRequest,
      );

      if (response != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Order updated successfully!'),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 3),
          ),
        );

        // ✅ Immediate refresh
        await _loadAllData();
      } else {
        throw Exception('Failed to update order');
      }
    } catch (e) {
      print('Error updating order: $e');
      if (mounted) {
        String errorMessage = 'Update failed: $e';

        if (e.toString().contains('KYC_NOT_APPROVED')) {
          errorMessage = 'KYC not approved. Cannot update order.';
        } else if (e.toString().contains('ORDER_NOT_FOUND')) {
          errorMessage = 'Order not found or not owned by you.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _formatDateForApi(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      final parts = dateString.split('/');
      if (parts.length == 3) {
        return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
      }
      return dateString;
    }
  }
  Future<void> _deleteTripRequest(int orderId) async {
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Canceling request...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // ✅ Find the trip request ID for this order
      final tripRequests = await _tripRequestService.getMyTripRequests(currentUserId!);
      final tripRequest = tripRequests.firstWhere(
            (tr) => tr.orderId == orderId && tr.travelerId == currentUserId,
        orElse: () => throw Exception('Trip request not found'),
      );

      final success = await _tripRequestService.deleteTripRequest(tripRequest.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Request canceled successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // ✅ Immediate refresh
        await _loadAllData();
      }
    } catch (e) {
      print('Error deleting trip request: $e');
      if (mounted) {
        String errorMessage = 'Failed to cancel request';

        if (e.toString().contains('Cannot delete an accepted')) {
          errorMessage = 'Cannot cancel an accepted or completed trip request';
        } else if (e.toString().contains('Trip request not found')) {
          errorMessage = 'Trip request not found';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _deleteOrder(int orderId) async {
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Deleting order...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final success = await _orderService.deleteOrder(orderId, currentUserId!);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Order deleted successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // ✅ Immediate refresh
        await _loadAllData();
      }
    } catch (e) {
      print('Error deleting order: $e');
      if (mounted) {
        String errorMessage = 'Delete failed: $e';

        if (e.toString().contains('KYC_NOT_APPROVED')) {
          errorMessage = 'KYC not approved. Cannot delete order.';
        } else if (e.toString().contains('ORDER_NOT_FOUND')) {
          errorMessage = 'Order not found or not owned by you.';
        } else if (e.toString().contains('USER_ID_REQUIRED')) {
          errorMessage = 'User ID is required.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
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
    if (currentUserId == null) return;

    final confirmed = await _showAcceptConfirmationDialog(request);
    if (confirmed != true) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Accepting trip request...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final acceptRequest = TripRequestAcceptRequest(
        orderCreatorId: currentUserId!,
        tripRequestId: request.id,
        negotiatedPrice: 0,
      );

      // ✅ Call the accept API
      final response = await _tripRequestService.acceptTripRequest(acceptRequest);

      // ✅ CHECK: Only show accepted if response is not null AND status code is 200
      if (response != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Trip request accepted! Transaction ID: #${response.transactionId}'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // ✅ Immediate refresh to show accepted status
        await _loadAllData();
      } else {
        // ✅ Show error if response is null or status code is not 200
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to accept trip request - Invalid response'),
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


  Future<bool?> _showAcceptConfirmationDialog(TripRequestDisplay request) async {
    return showDialog<bool>(
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
            const Text(
              'Are you sure you want to accept this trip request?',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 16),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
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
          // ✅ ADD: Manual refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadAllData(),
            tooltip: 'Refresh',
          ),
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
        onAction: () => _loadMyOrders(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadMyOrders(),
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
            onCompleteOrder: () => _completeOrder(order),
            onUpdateOrder: _updateOrder,
            onDeleteOrder: _deleteOrder,
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
        subtitle: 'Search for available orders and send trip requests to see them here',
        actionText: 'Refresh',
        onAction: () => _loadMyRequestedOrders(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadMyRequestedOrders(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: myRequestedOrders.length,
        itemBuilder: (context, index) {
          return ModernTravellerOrderCard(
            order: myRequestedOrders[index],
            onTrackOrder: () => _openOrderTracking(myRequestedOrders[index]),
            onDeleteRequest: _deleteTripRequest, // ✅ ADD THIS
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
