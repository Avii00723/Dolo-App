import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../Controllers/AuthService.dart';
import '../../Controllers/ChatService.dart';
import '../../Controllers/SocketService.dart';
import '../../Controllers/TripRequestService.dart';
import '../../Controllers/OrderTrackingService.dart';
import '../../Models/TripRequestModel.dart';
import '../../widgets/NotificationBellIcon.dart';
import '../../Constants/ApiConstants.dart';
import 'ChatScreen.dart';

class InboxScreen extends StatefulWidget {
  final int initialTab;

  const InboxScreen({Key? key, this.initialTab = 0}) : super(key: key);

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
  final OrderTrackingService _trackingService = OrderTrackingService();
  late TabController _tabController;

  Map<String, bool> _typingStatus = {};
  Map<String, Timer?> _typingTimers = {};

  List<TripRequest> _sentRequests = [];
  List<TripRequest> _receivedRequests = [];
  bool _isLoadingRequests = true;
  String? _requestsErrorMessage;

  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Request Sent', 'Request Received'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _initializeAndLoadInbox();
    _initializeWebSocket();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _typingTimers.values.forEach((timer) => timer?.cancel());
    super.dispose();
  }

  Future<void> _initializeAndLoadInbox() async {
    _currentUserId = await AuthService.getUserId();
    await _loadInbox();
    await _loadTripRequests();
  }

  Future<void> _loadInbox() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ChatService.getInbox();

      if (!mounted) return;

      if (result['success'] == true) {
        final apiInbox = result['inbox'] as List<dynamic>;
        final conversations = apiInbox.map((item) => item as Map<String, dynamic>).toList();

        setState(() {
          _conversations = conversations;
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _conversations = [];
          _isLoading = false;
          _errorMessage = result['error'] as String?;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _conversations = [];
        _isLoading = false;
        _errorMessage = 'Network error: $e';
      });
    }
  }

  Future<void> _loadTripRequests() async {
    if (!mounted || _currentUserId == null) return;

    setState(() {
      _isLoadingRequests = true;
      _requestsErrorMessage = null;
    });

    try {
      final allRequests = await _tripRequestService.getMyTripRequests(_currentUserId!);

      if (!mounted) return;

      final sent = <TripRequest>[];
      final received = <TripRequest>[];

      for (var request in allRequests) {
        if (request.travelerId == _currentUserId) {
          sent.add(request);
        } else {
          received.add(request);
        }
      }

      setState(() {
        _sentRequests = sent;
        _receivedRequests = received;
        _isLoadingRequests = false;
        _requestsErrorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _sentRequests = [];
        _receivedRequests = [];
        _isLoadingRequests = false;
        _requestsErrorMessage = 'Failed to load requests: $e';
      });
    }
  }

  Future<void> _initializeWebSocket() async {
    try {
      await _socketService.connect();

      if (_socketService.isConnected) {
        _socketService.onUserTyping((data) {
          final typingUserId = data['userId'] as String?;
          final roomId = data['roomId'] as String?;

          if (typingUserId != null && roomId != null && typingUserId != _currentUserId) {
            if (mounted) {
              setState(() {
                _typingStatus[roomId] = true;
              });

              _typingTimers[roomId]?.cancel();
              _typingTimers[roomId] = Timer(const Duration(seconds: 3), () {
                if (mounted) {
                  setState(() {
                    _typingStatus[roomId] = false;
                  });
                }
              });
            }
          }
        });

        _socketService.onReceiveMessage((data) {
          _loadInbox();
        });
      }
    } catch (e) {
      print('❌ Error initializing inbox WebSocket: $e');
    }
  }

  List<TripRequest> get _filteredRequests {
    if (_selectedFilter == 'All') {
      return [..._receivedRequests, ..._sentRequests];
    } else if (_selectedFilter == 'Request Sent') {
      return _sentRequests;
    } else {
      return _receivedRequests;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
      ),
      body: Column(
        children: [
          // Tab Bar with rounded design
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTab(
                    'Chats',
                    _tabController.index == 0,
                    _conversations.length,
                        () {
                      _tabController.animateTo(0);
                      setState(() {});
                    },
                  ),
                ),
                Expanded(
                  child: _buildTab(
                    'Requests',
                    _tabController.index == 1,
                    _sentRequests.length + _receivedRequests.length,
                        () {
                      _tabController.animateTo(1);
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),

          // Filter chips for Requests tab
          if (_tabController.index == 1) ...[
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _filters.map((filter) {
                  final count = filter == 'All'
                      ? _sentRequests.length + _receivedRequests.length
                      : filter == 'Request Sent'
                      ? _sentRequests.length
                      : _receivedRequests.length;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(filter, count),
                  );
                }).toList(),
              ),
            ),
          ],

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChatsTab(),
                _buildRequestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, bool isSelected, int count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.black87 : Colors.grey,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.grey.shade200
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.black87 : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey.shade200 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.black87 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black87 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatsTab() {
    if (_currentUserId == null) {
      return _buildNotLoggedInState();
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_conversations.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        return ModernChatCard(
          conversation: conversation,
          currentUserId: _currentUserId!,
          onTap: () => _openChat(conversation),
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    if (_currentUserId == null) {
      return _buildNotLoggedInState();
    }

    if (_isLoadingRequests) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredRequests.isEmpty) {
      return _buildEmptyRequestsState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredRequests.length,
      itemBuilder: (context, index) {
        final request = _filteredRequests[index];
        final isReceived = request.travelerId != _currentUserId;

        return ModernRequestCard(
          request: request,
          currentUserId: _currentUserId!,
          isReceived: isReceived,
          onAccept: isReceived ? () => _acceptRequest(request) : null,
          onDecline: isReceived ? () => _declineRequest(request) : null,
          onWithdraw: !isReceived ? () => _withdrawRequest(request) : null,
          onRefresh: _loadTripRequests,
          trackingService: _trackingService,
        );
      },
    );
  }

  Widget _buildNotLoggedInState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.login, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Please log in to continue',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No Chats Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start chatting by accepting trip requests',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRequestsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.request_page_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No Trip Requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No requests to display',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
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
    ).then((_) => _loadInbox());
  }

  Future<void> _acceptRequest(TripRequest request) async {
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

  Future<void> _declineRequest(TripRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Trip Request'),
        content: Text('Decline this request from ${request.source} to ${request.destination}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

  Future<void> _withdrawRequest(TripRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Trip Request'),
        content: Text('Withdraw your request for ${request.source} to ${request.destination}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
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

// Modern Chat Card
class ModernChatCard extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final String currentUserId;
  final VoidCallback onTap;

  const ModernChatCard({
    Key? key,
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final otherUserName = conversation['other_user_name'] ?? 'Unknown User';
    final lastMessage = conversation['lastMessage'] ?? 'No messages yet';
    final lastMessageTime = conversation['lastMessageTime'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.grey.shade300,
                  child: Icon(Icons.person, color: Colors.grey.shade600, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastMessage,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      final time = DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final difference = now.difference(time);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return DateFormat('EEEE').format(time);
      } else {
        return DateFormat('MMM dd').format(time);
      }
    } catch (e) {
      return '';
    }
  }
}

// Modern Request Card
class ModernRequestCard extends StatelessWidget {
  final TripRequest request;
  final String currentUserId;
  final bool isReceived;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onWithdraw;
  final VoidCallback? onRefresh;
  final OrderTrackingService trackingService;

  const ModernRequestCard({
    Key? key,
    required this.request,
    required this.currentUserId,
    required this.isReceived,
    this.onAccept,
    this.onDecline,
    this.onWithdraw,
    this.onRefresh,
    required this.trackingService,
  }) : super(key: key);

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM, yyyy ; ha').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = request.status.toLowerCase() == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReceived ? const Color(0xFFD4F4DD) : const Color(0xFFE0F2FE),
          width: 3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with avatar and menu
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade300,
                child: Icon(Icons.person, color: Colors.grey.shade600, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isReceived ? request.travelerId : request.orderId,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      isReceived ? '↙ Sent you an request' : '↗ You sent an request',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Route information
          Row(
            children: [
              const Icon(Icons.circle, size: 8, color: Colors.black87),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${request.source} → ${request.destination}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Departure info
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              const Text(
                'Departure',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(request.travelDate),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),

          // Action buttons for pending requests
          if (isPending) ...[
            const SizedBox(height: 16),
            if (isReceived)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDecline,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Decline'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        backgroundColor: const Color(0xFFFEE2E2),
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
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onWithdraw,
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Withdraw'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    backgroundColor: const Color(0xFFFFF7ED),
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
    );
  }
}