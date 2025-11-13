import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../Controllers/AuthService.dart';
import '../../Controllers/ChatService.dart';
import '../../Controllers/SocketService.dart';
import '../../Controllers/TripRequestService.dart';
import '../../Models/TripRequestModel.dart';
import 'ChatScreen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({Key? key}) : super(key: key);

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentUserId;
  final SocketService _socketService = SocketService();
  final TripRequestService _tripRequestService = TripRequestService();
  late TabController _tabController; // ✅ NEW: Tab controller

  // Track typing status for each chat
  Map<String, bool> _typingStatus = {};
  Map<String, Timer?> _typingTimers = {};

  // Trip requests state
  List<TripRequest> _sentRequests = [];
  List<TripRequest> _receivedRequests = [];
  bool _isLoadingRequests = true;
  String? _requestsErrorMessage;

  // Section expansion state
  bool _isReceivedExpanded = true;
  bool _isSentExpanded = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // ✅ NEW: 2 tabs - Chats and Requests
    _initializeAndLoadInbox();
    _initializeWebSocket();
  }

  @override
  void dispose() {
    _tabController.dispose(); // ✅ NEW: Dispose tab controller
    // Cancel all typing timers
    _typingTimers.values.forEach((timer) => timer?.cancel());
    super.dispose();
  }

  Future<void> _initializeAndLoadInbox() async {
    _currentUserId = await AuthService.getUserId();
    await _loadInbox();
    await _loadTripRequests();
  }

  // ✅ UPDATED: Load only real inbox data, no dummy data
  Future<void> _loadInbox() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ✅ Call the API to get real inbox data
      final result = await ChatService.getInbox();

      if (!mounted) return;

      if (result['success'] == true) {
        final apiInbox = result['inbox'] as List<dynamic>;

        // ✅ Only use API data - no dummy data
        final conversations = apiInbox.map((item) => item as Map<String, dynamic>).toList();

        setState(() {
          _conversations = conversations;
          _isLoading = false;
          _errorMessage = null;
        });

        print('✅ Loaded ${conversations.length} conversations from API');
      } else {
        // ✅ If API fails, show empty list with error message
        setState(() {
          _conversations = [];
          _isLoading = false;
          _errorMessage = result['error'] as String?;
        });

        print('⚠️ API failed: ${result['error']}');
      }
    } catch (e) {
      // ✅ On exception, show empty list with error
      if (!mounted) return;

      setState(() {
        _conversations = [];
        _isLoading = false;
        _errorMessage = 'Network error: $e';
      });

      print('❌ Exception loading inbox: $e');
    }
  }

  // Load trip requests (sent by user and received for user's orders)
  Future<void> _loadTripRequests() async {
    if (!mounted || _currentUserId == null) return;

    setState(() {
      _isLoadingRequests = true;
      _requestsErrorMessage = null;
    });

    try {
      // Fetch all trip requests related to the current user
      final allRequests = await _tripRequestService.getMyTripRequests(_currentUserId!);

      if (!mounted) return;

      // Separate sent requests (where user is the traveler) and received requests (where user created the order)
      final sent = <TripRequest>[];
      final received = <TripRequest>[];

      for (var request in allRequests) {
        if (request.travelerId == _currentUserId) {
          // User sent this request
          sent.add(request);
        } else {
          // User received this request on their order
          received.add(request);
        }
      }

      setState(() {
        _sentRequests = sent;
        _receivedRequests = received;
        _isLoadingRequests = false;
        _requestsErrorMessage = null;
      });

      print('✅ Loaded ${sent.length} sent requests and ${received.length} received requests');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _sentRequests = [];
        _receivedRequests = [];
        _isLoadingRequests = false;
        _requestsErrorMessage = 'Failed to load requests: $e';
      });

      print('❌ Exception loading trip requests: $e');
    }
  }

  // Initialize WebSocket for real-time typing indicators
  Future<void> _initializeWebSocket() async {
    try {
      await _socketService.connect();

      if (_socketService.isConnected) {
        // Listen for typing indicators
        _socketService.onUserTyping((data) {
          final typingUserId = data['userId'] as String?;
          final roomId = data['roomId'] as String?;

          print('🔍 InboxScreen - Typing event: userId=$typingUserId, roomId=$roomId, currentUserId=$_currentUserId');

          if (typingUserId != null && roomId != null && typingUserId != _currentUserId) {
            if (mounted) {
              setState(() {
                _typingStatus[roomId] = true;
              });

              // Auto-hide typing indicator after 3 seconds
              _typingTimers[roomId]?.cancel();
              _typingTimers[roomId] = Timer(const Duration(seconds: 3), () {
                if (mounted) {
                  setState(() {
                    _typingStatus[roomId] = false;
                  });
                }
              });

              print('⌨️  User $typingUserId is typing in room $roomId');
            }
          } else {
            if (roomId == null) {
              print('⚠️ InboxScreen - roomId is null, cannot show typing indicator');
            }
            if (typingUserId == null) {
              print('⚠️ InboxScreen - typingUserId is null');
            }
            if (typingUserId == _currentUserId) {
              print('⚠️ InboxScreen - Ignoring own typing event');
            }
          }
        });

        // Listen for new messages to refresh inbox
        _socketService.onReceiveMessage((data) {
          print('📬 New message received, refreshing inbox');
          _loadInbox();
        });

        print('✅ Inbox WebSocket initialized');
      }
    } catch (e) {
      print('❌ Error initializing inbox WebSocket: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Inbox',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadInbox,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(icon: Icon(Icons.chat), text: 'Chats'),
            Tab(icon: Icon(Icons.request_page), text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBody(), // Chats tab - existing functionality
          _buildRequestsTab(), // ✅ NEW: Requests tab
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_currentUserId == null) {
      return _buildNotLoggedInState();
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // ✅ Show empty state when conversations list is empty
    if (_conversations.isEmpty) {
      // Show error state if there's an error, otherwise show empty state
      if (_errorMessage != null) {
        return _buildErrorState();
      }
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadInbox,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          final chatId = conversation['chat_id']?.toString() ?? '';
          final isTyping = _typingStatus[chatId] ?? false;

          return ModernChatCard(
            conversation: conversation,
            currentUserId: _currentUserId!,
            isOtherUserTyping: isTyping,
            onTap: () => _openChat(conversation),
          );
        },
      ),
    );
  }

  Widget _buildNotLoggedInState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.login,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Please log in to view messages',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ UPDATED: Better empty state design
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 60,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Chats Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Start chatting by accepting trip requests or sending messages',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          // ✅ ADD: Refresh button in empty state
          ElevatedButton.icon(
            onPressed: _loadInbox,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Messages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadInbox,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(Map<String, dynamic> conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: conversation['chat_id'].toString(),
          orderId: conversation['order_id'].toString(),
          otherUserName: conversation['other_user_name'],
        ),
      ),
    ).then((_) {
      // Refresh inbox when returning from chat
      _loadInbox();
    });
  }

  // Requests Tab - Shows trip requests (sent and received)
  Widget _buildRequestsTab() {
    if (_currentUserId == null) {
      return _buildNotLoggedInState();
    }

    if (_isLoadingRequests) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_requestsErrorMessage != null) {
      return _buildRequestsErrorState();
    }

    if (_sentRequests.isEmpty && _receivedRequests.isEmpty) {
      return _buildEmptyRequestsState();
    }

    return RefreshIndicator(
      onRefresh: _loadTripRequests,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Received Requests Section (Requests for YOUR orders)
            if (_receivedRequests.isNotEmpty) ...[
              InkWell(
                onTap: () {
                  setState(() {
                    _isReceivedExpanded = !_isReceivedExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.inbox, size: 20, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Received Requests',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_receivedRequests.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isReceivedExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 24,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
              if (_isReceivedExpanded) ...[
                ..._receivedRequests.map((request) => TripRequestCard(
                  request: request,
                  currentUserId: _currentUserId!,
                  isReceived: true,
                  onAccept: () => _acceptRequest(request),
                  onDecline: () => _declineRequest(request),
                  onWithdraw: null,
                )),
              ],
              const SizedBox(height: 24),
            ],

            // Sent Requests Section (Requests YOU sent)
            if (_sentRequests.isNotEmpty) ...[
              InkWell(
                onTap: () {
                  setState(() {
                    _isSentExpanded = !_isSentExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.send, size: 20, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sent Requests',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_sentRequests.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isSentExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 24,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
              if (_isSentExpanded) ...[
                ..._sentRequests.map((request) => TripRequestCard(
                  request: request,
                  currentUserId: _currentUserId!,
                  isReceived: false,
                  onAccept: null,
                  onDecline: null,
                  onWithdraw: () => _withdrawRequest(request),
                )),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRequestsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.request_page_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Trip Requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'You haven\'t sent or received any trip requests yet',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadTripRequests,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _requestsErrorMessage ?? 'Unknown error occurred',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadTripRequests,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Accept a trip request (for received requests)
  Future<void> _acceptRequest(TripRequest request) async {
    // Show dialog to get negotiated price
    final TextEditingController priceController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Trip Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Accept request from ${request.source} to ${request.destination}?'),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Negotiated Price',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
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
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed == true && priceController.text.isNotEmpty) {
      try {
        final acceptRequest = TripRequestAcceptRequest(
          orderCreatorId: _currentUserId!,
          tripRequestId: request.id,
          negotiatedPrice: int.parse(priceController.text),
        );

        final response = await _tripRequestService.acceptTripRequest(acceptRequest);

        if (response != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.green,
            ),
          );
          await _loadTripRequests();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to accept request: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Decline a trip request (for received requests)
  Future<void> _declineRequest(TripRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Trip Request'),
        content: Text('Are you sure you want to decline this request from ${request.source} to ${request.destination}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final declineRequest = TripRequestDeclineRequest(
          orderCreatorHashedId: _currentUserId!,
          tripRequestId: request.id,
        );

        final response = await _tripRequestService.declineTripRequest(declineRequest);

        if (response != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.orange,
            ),
          );
          await _loadTripRequests();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to decline request: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Withdraw a trip request (for sent requests)
  Future<void> _withdrawRequest(TripRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Trip Request'),
        content: Text('Are you sure you want to withdraw your request for ${request.source} to ${request.destination}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final withdrawRequest = TripRequestWithdrawRequest(
          travelerHashedId: _currentUserId!,
          tripRequestHashedId: request.id,
        );

        final response = await _tripRequestService.withdrawTripRequest(withdrawRequest);

        if (response != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.orange,
            ),
          );
          await _loadTripRequests();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to withdraw request: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

// ModernChatCard widget remains the same
class ModernChatCard extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final String currentUserId;
  final bool isOtherUserTyping;
  final VoidCallback onTap;

  const ModernChatCard({
    Key? key,
    required this.conversation,
    required this.currentUserId,
    this.isOtherUserTyping = false,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final otherUserName = conversation['other_user_name'] ?? 'Unknown User';
    final otherUserPhoto = conversation['other_user_photo'];
    final origin = conversation['origin'] ?? 'Unknown';
    final destination = conversation['destination'] ?? 'Unknown';
    final lastMessage = conversation['lastMessage'] ?? 'No messages yet';
    final lastMessageTime = conversation['lastMessageTime'];
    final acceptedBy = conversation['accepted_by'];
    final orderId = conversation['order_id'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Profile Avatar
                _buildAvatar(otherUserPhoto, otherUserName),
                const SizedBox(width: 16),
                // Chat Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and Time Row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              otherUserName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatTime(lastMessageTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Order Info Chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_shipping,
                              size: 12,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              flex: 2,
                              child: Text(
                                '$origin → $destination',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              flex: 1,
                              child: Text(
                                '#$orderId',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Last Message or Typing Indicator
                      isOtherUserTyping
                          ? Row(
                              children: [
                                Text(
                                  'typing',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.green.shade600,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 20,
                                  height: 10,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildTypingDot(0),
                                      _buildTypingDot(200),
                                      _buildTypingDot(400),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              lastMessage,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      // Status indicator if accepted
                      if (acceptedBy != null) ...[
                        const SizedBox(height: 8),
                        _buildStatusChip(
                          acceptedBy == currentUserId
                              ? 'Accepted by you'
                              : 'Accepted',
                          acceptedBy == currentUserId,
                        ),
                      ],
                    ],
                  ),
                ),
                // Arrow indicator
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, String name) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
      ),
      child: photoUrl != null && photoUrl.isNotEmpty
          ? ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Image.network(
          photoUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildAvatarFallback(name),
        ),
      )
          : _buildAvatarFallback(name),
    );
  }

  Widget _buildAvatarFallback(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String text, bool isCurrentUser) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.green.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCurrentUser ? Colors.green.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCurrentUser ? Icons.check_circle : Icons.handshake,
            size: 12,
            color: isCurrentUser ? Colors.green.shade700 : Colors.blue.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color:
              isCurrentUser ? Colors.green.shade700 : Colors.blue.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Build animated typing dots
  static Widget _buildTypingDot(int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return FutureBuilder(
          future: Future.delayed(Duration(milliseconds: delay)),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.green.shade300,
                  shape: BoxShape.circle,
                ),
              );
            }
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: value > 0.5 ? Colors.green.shade600 : Colors.green.shade300,
                shape: BoxShape.circle,
              ),
            );
          },
        );
      },
      onEnd: () {
        // Animation will naturally loop via TweenAnimationBuilder
      },
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      final time = DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final difference = now.difference(time);

      if (difference.inDays == 0) {
        return DateFormat('HH:mm').format(time);
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return DateFormat('EEE').format(time);
      } else {
        return DateFormat('MMM dd').format(time);
      }
    } catch (e) {
      return '';
    }
  }
}

// Trip Request Card Widget
class TripRequestCard extends StatelessWidget {
  final TripRequest request;
  final String currentUserId;
  final bool isReceived;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onWithdraw;

  const TripRequestCard({
    Key? key,
    required this.request,
    required this.currentUserId,
    required this.isReceived,
    this.onAccept,
    this.onDecline,
    this.onWithdraw,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isReceived ? Colors.orange.shade200 : Colors.blue.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
            // Header with status badge
            Row(
              children: [
                Icon(
                  isReceived ? Icons.call_received : Icons.call_made,
                  size: 18,
                  color: isReceived ? Colors.orange.shade700 : Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isReceived ? 'Request Received' : 'Request Sent',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isReceived ? Colors.orange.shade700 : Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(request.status),
              ],
            ),
            const SizedBox(height: 12),

            // Route Information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.green.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          request.source,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const SizedBox(width: 22),
                        Icon(Icons.arrow_downward, size: 14, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.red.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          request.destination,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Trip Details - Responsive Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 300;

                if (isNarrow) {
                  // Stack vertically for very narrow screens
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailItem(
                        Icons.calendar_today,
                        'Date',
                        _formatDate(request.travelDate),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailItem(
                        Icons.directions_car,
                        'Vehicle',
                        request.vehicleInfo,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailItem(
                        Icons.access_time,
                        'Pickup',
                        request.pickupTime,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailItem(
                        Icons.access_time_filled,
                        'Dropoff',
                        request.dropoffTime,
                      ),
                    ],
                  );
                } else {
                  // 2-column grid for normal screens
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              Icons.calendar_today,
                              'Date',
                              _formatDate(request.travelDate),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDetailItem(
                              Icons.access_time,
                              'Pickup',
                              request.pickupTime,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              Icons.directions_car,
                              'Vehicle',
                              request.vehicleInfo,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDetailItem(
                              Icons.access_time_filled,
                              'Dropoff',
                              request.dropoffTime,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),

            // Action Buttons (only for received requests with pending status)
            if (isReceived && request.status.toLowerCase() == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDecline,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Decline'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Withdraw button (only for sent requests with pending status)
            if (!isReceived && request.status.toLowerCase() == 'pending') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onWithdraw,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Withdraw Request'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                    side: BorderSide(color: Colors.orange.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'pending':
        backgroundColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        icon = Icons.pending;
        break;
      case 'accepted':
        backgroundColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        icon = Icons.check_circle;
        break;
      case 'declined':
        backgroundColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        icon = Icons.cancel;
        break;
      case 'withdrawn':
        backgroundColor = Colors.grey.shade50;
        textColor = Colors.grey.shade700;
        icon = Icons.undo;
        break;
      default:
        backgroundColor = Colors.grey.shade50;
        textColor = Colors.grey.shade700;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}
