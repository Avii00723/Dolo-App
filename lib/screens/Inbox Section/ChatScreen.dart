import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async'; // ✅ ADD: Import for Timer
import '../../Controllers/AuthService.dart';
import '../../Controllers/ChatService.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String orderId;
  final String? otherUserName;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.orderId,
    this.otherUserName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// ✅ ADD: WidgetsBindingObserver for lifecycle monitoring
class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int? _currentUserId;
  Map<String, dynamic> otherUserData = {};
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  String? _errorMessage;
  String? replyingToMessageId;
  Map<String, dynamic>? replyingToMessage;

  // ✅ NEW: Timer for auto-refresh
  Timer? _autoRefreshTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // ✅ ADD: Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
    // ✅ START: Auto-refresh every 5 seconds
    _startAutoRefresh();
  }

  // ✅ NEW: Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // App came to foreground - refresh and restart timer
      print('📱 App resumed - refreshing messages...');
      _loadMessages(silent: true);
      if (_autoRefreshTimer?.isActive != true) {
        _startAutoRefresh();
      }
    } else if (state == AppLifecycleState.paused) {
      // App went to background - pause timer to save battery
      print('📱 App paused - stopping auto-refresh...');
      _autoRefreshTimer?.cancel();
    }
  }

  // ✅ NEW: Start auto-refresh timer
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel(); // Cancel existing timer if any
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && !_isRefreshing) {
        print('🔄 Auto-refreshing messages at ${DateTime.now()}');
        _loadMessages(silent: true);
      }
    });
    print('✅ Auto-refresh timer started (every 5 seconds)');
  }

  Future<void> _initializeChat() async {
    _currentUserId = await AuthService.getUserId();

    if (_currentUserId == null) {
      setState(() {
        isLoading = false;
        _errorMessage = 'User not authenticated';
      });
      return;
    }

    print('🔑 Current User ID: $_currentUserId');
    await _loadMessages();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!mounted || _isRefreshing) return;

    if (!silent) {
      setState(() {
        isLoading = true;
        _errorMessage = null;
      });
    } else {
      _isRefreshing = true;
    }

    try {
      final chatIdInt = int.tryParse(widget.chatId);

      if (chatIdInt == null) {
        if (!silent) {
          setState(() {
            isLoading = false;
            _errorMessage = 'Invalid chat ID';
          });
        }
        _isRefreshing = false;
        return;
      }

      final result = await ChatService.getChatMessages(chatId: chatIdInt);

      if (!mounted) {
        _isRefreshing = false;
        return;
      }

      if (result['success'] == true) {
        final apiMessages = result['messages'] as List<dynamic>;

        final convertedMessages = apiMessages.map((msg) {
          final senderId = msg['sender_id'];
          final senderName = msg['sender_name'] ?? 'Unknown';

          return {
            'messageId': msg['id'].toString(),
            'message': msg['message'] ?? '',
            'senderId': senderId,
            'senderName': senderName,
            'timestamp': DateTime.parse(msg['created_at']),
            'type': 'text',
          };
        }).toList();

        // ✅ Check if user is at bottom before updating
        final scrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
        final wasAtBottom = scrollOffset < 50;

        setState(() {
          messages = convertedMessages;

          if (convertedMessages.isNotEmpty) {
            final firstOtherMessage = convertedMessages.firstWhere(
                  (msg) => msg['senderId'] != _currentUserId,
              orElse: () => {},
            );

            if (firstOtherMessage.isNotEmpty) {
              otherUserData = {
                'name': firstOtherMessage['senderName'] ?? widget.otherUserName ?? 'Unknown User',
                'profileUrl': '',
              };
            } else {
              otherUserData = {
                'name': widget.otherUserName ?? 'Unknown User',
                'profileUrl': '',
              };
            }
          } else {
            otherUserData = {
              'name': widget.otherUserName ?? 'Unknown User',
              'profileUrl': '',
            };
          }

          isLoading = false;
          _errorMessage = null;
        });

        // ✅ Only auto-scroll if user was at bottom (to not interrupt reading)
        if (silent && wasAtBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
        } else if (!silent) {
          // Always scroll on manual refresh
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
        }

        if (!silent) {
          print('✅ Loaded ${messages.length} messages from API');
        }
      } else {
        if (!silent) {
          setState(() {
            isLoading = false;
            _errorMessage = result['error'] as String?;
            otherUserData = {
              'name': widget.otherUserName ?? 'Unknown User',
              'profileUrl': '',
            };
          });
        }

        print('⚠️ Failed to load messages: ${result['error']}');
      }
    } catch (e) {
      if (!mounted) {
        _isRefreshing = false;
        return;
      }

      if (!silent) {
        setState(() {
          isLoading = false;
          _errorMessage = 'Failed to load messages: $e';
          otherUserData = {
            'name': widget.otherUserName ?? 'Unknown User',
            'profileUrl': '',
          };
        });
      }

      print('❌ Exception loading messages: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null && messages.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: _buildModernAppBar(),
        body: _buildErrorState(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildModernAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessagesList()),
          if (replyingToMessage != null) _buildReplyPreview(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
              ),
            ),
            child: _buildAvatarFallback(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  otherUserData['name'] ?? 'Unknown User',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      'Order #${widget.orderId}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // ✅ NEW: Show live indicator
                    const SizedBox(width: 8),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Live',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // ✅ Show loading indicator when refreshing
        if (_isRefreshing)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.grey.shade600),
              ),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: () => _loadMessages(silent: false),
            tooltip: 'Refresh',
          ),
      ],
    );
  }

  Widget _buildAvatarFallback() {
    final name = otherUserData['name'] ?? 'U';
    return Center(
      child: Text(
        name[0].toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    if (messages.isEmpty) {
      return _buildEmptyMessages();
    }

    return RefreshIndicator(
      onRefresh: () => _loadMessages(silent: false),
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[messages.length - 1 - index];
          final isMe = message['senderId'] == _currentUserId;

          return ModernMessageBubble(
            message: message,
            messageId: message['messageId'],
            isMe: isMe,
            onReply: (messageData) => _setReplyMessage(message['messageId'], messageData),
            onCopy: _copyMessage,
            onLaunchUrl: _launchUrl,
          );
        },
      ),
    );
  }

  Widget _buildEmptyMessages() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start the conversation',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Send a message to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
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
              'Failed to load messages',
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
              onPressed: () => _loadMessages(silent: false),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    if (replyingToMessage == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: Colors.blue.shade600, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, color: Colors.blue.shade600, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyingToMessage!['message'] ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.grey.shade600, size: 18),
            onPressed: _clearReply,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: replyingToMessage != null
                        ? 'Reply to message...'
                        : 'Type a message...',
                    hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final chatIdInt = int.tryParse(widget.chatId);
    if (chatIdInt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid chat ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _messageController.clear();
    _clearReply();

    final tempMessage = {
      'messageId': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'message': message,
      'senderId': _currentUserId,
      'senderName': 'You',
      'timestamp': DateTime.now(),
      'type': 'text',
      'sending': true,
    };

    setState(() {
      messages.add(tempMessage);
    });

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    try {
      final result = await ChatService.sendMessage(
        chatId: chatIdInt,
        message: message,
      );

      if (result['success'] == true) {
        print('✅ Message sent successfully');
        await _loadMessages(silent: true);
      } else {
        setState(() {
          messages.removeWhere((msg) => msg['messageId'] == tempMessage['messageId']);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Failed to send message'),
              backgroundColor: Colors.red,
            ),
          );
        }

        print('❌ Failed to send message: ${result['error']}');
      }
    } catch (e) {
      setState(() {
        messages.removeWhere((msg) => msg['messageId'] == tempMessage['messageId']);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      print('❌ Exception sending message: $e');
    }
  }

  void _setReplyMessage(String messageId, Map<String, dynamic> messageData) {
    setState(() {
      replyingToMessageId = messageId;
      replyingToMessage = messageData;
    });
  }

  void _clearReply() {
    setState(() {
      replyingToMessageId = null;
      replyingToMessage = null;
    });
  }

  void _copyMessage(String message) {
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open link'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    // ✅ IMPORTANT: Clean up timer and observer
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// ModernMessageBubble class remains exactly the same as in your file
class ModernMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final String messageId;
  final bool isMe;
  final Function(Map<String, dynamic>) onReply;
  final Function(String) onCopy;
  final Function(String) onLaunchUrl;

  const ModernMessageBubble({
    Key? key,
    required this.message,
    required this.messageId,
    required this.isMe,
    required this.onReply,
    required this.onCopy,
    required this.onLaunchUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isSystem = message['senderId'] == 'system';
    final isSending = message['sending'] == true;

    if (isSystem) {
      return _buildSystemMessage();
    }

    return GestureDetector(
      onLongPress: isSending ? null : () => _showMessageOptions(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.person, color: Colors.white, size: 16),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (message['replyMessage'] != null) _buildReplyPreview(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.white : Colors.blue.shade600,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isMe ? 4 : 20),
                          bottomRight: Radius.circular(isMe ? 20 : 4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: _buildMessageContent()),
                          if (isSending) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isMe ? Colors.grey : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(message['timestamp']),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade400,
                ),
                child: const Center(
                  child: Icon(Icons.person, color: Colors.white, size: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message['message'] ?? '',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe ? Colors.grey.shade100 : Colors.blue.shade700,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: isMe ? Colors.blue.shade600 : Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message['replyMessage'] ?? '',
              style: TextStyle(
                fontSize: 12,
                color: isMe ? Colors.grey.shade600 : Colors.white70,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent() {
    final messageText = message['message'] ?? '';
    final urlRegex = RegExp(
      r'https?://(?:[-\w.])+(?::[0-9]+)?(?:/(?:[\w/_.])*(?:\?[-\w&=%.]*)?)?#?(?:[\w]*)?',
      caseSensitive: false,
    );

    if (urlRegex.hasMatch(messageText)) {
      return _buildTextWithLinks(messageText, urlRegex);
    }

    return Text(
      messageText,
      style: TextStyle(
        fontSize: 15,
        color: isMe ? Colors.black87 : Colors.white,
        height: 1.3,
      ),
    );
  }

  Widget _buildTextWithLinks(String text, RegExp urlRegex) {
    final spans = <TextSpan>[];
    final matches = urlRegex.allMatches(text);
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: TextStyle(
            fontSize: 15,
            color: isMe ? Colors.black87 : Colors.white,
          ),
        ));
      }

      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          fontSize: 15,
          color: isMe ? Colors.blue.shade600 : Colors.white,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w500,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => onLaunchUrl(url),
      ));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: TextStyle(
          fontSize: 15,
          color: isMe ? Colors.black87 : Colors.white,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.reply, color: Colors.blue.shade600),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReply(message);
              },
            ),
            ListTile(
              leading: Icon(Icons.copy, color: Colors.grey.shade600),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                onCopy(message['message'] ?? '');
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime time;
    if (timestamp is DateTime) {
      time = timestamp;
    } else {
      time = DateTime.parse(timestamp.toString());
    }

    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(time);
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(time)}';
    } else {
      return DateFormat('MMM dd, HH:mm').format(time);
    }
  }
}
