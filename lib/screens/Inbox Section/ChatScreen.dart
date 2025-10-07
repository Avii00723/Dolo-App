import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String orderId;

  const ChatScreen({
    Key? key,
    required this.otherUserId,
    required this.orderId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final String currentUserId = '1';
  late Map<String, dynamic> otherUserData;
  List<Map<String, dynamic>> messages = [];

  bool isLoading = true;
  String? replyingToMessageId;
  Map<String, dynamic>? replyingToMessage;

  @override
  void initState() {
    super.initState();
    _initializeDummyData();
  }

  void _initializeDummyData() {
    setState(() {
      otherUserData = {
        'name': 'Rajesh Kumar',
        'profileUrl': '',
      };

      messages = [
        {
          'messageId': '1',
          'message': 'Hi! I saw your delivery request from Mumbai to Pune. I am traveling on the same route tomorrow.',
          'senderId': widget.otherUserId,
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 10)),
          'type': 'text',
        },
        {
          'messageId': '2',
          'message': 'Great! What time are you planning to travel?',
          'senderId': currentUserId,
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 9, minutes: 45)),
          'type': 'text',
        },
        {
          'messageId': '3',
          'message': 'I will be leaving Mumbai at 10 AM tomorrow and should reach Pune by 1 PM.',
          'senderId': widget.otherUserId,
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 9, minutes: 30)),
          'type': 'text',
        },
        {
          'messageId': '4',
          'message': 'Perfect timing! Can you handle a 5.5kg electronics package?',
          'senderId': currentUserId,
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 9, minutes: 20)),
          'type': 'text',
        },
        {
          'messageId': '5',
          'message': 'Yes, definitely! I have enough space in my car and I\'ll handle it carefully.',
          'senderId': widget.otherUserId,
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 9, minutes: 10)),
          'type': 'text',
        },
        {
          'messageId': '6',
          'message': 'Where exactly will you pick it up from?',
          'senderId': widget.otherUserId,
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 9, minutes: 5)),
          'type': 'text',
        },
        {
          'messageId': '7',
          'message': 'I\'m near Mumbai Central station. Can you come there around 9:30 AM?',
          'senderId': currentUserId,
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 9)),
          'type': 'text',
        },
        {
          'messageId': '8',
          'message': 'Sure, I can reach there by 9:30 AM. Please share the exact pickup address.',
          'senderId': widget.otherUserId,
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 8, minutes: 50)),
          'type': 'text',
        },
        {
          'messageId': '9',
          'message': '📨 Trip request sent',
          'senderId': 'system',
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 8, minutes: 45)),
          'type': 'system',
        },
        {
          'messageId': '10',
          'message': 'I\'ve sent you a trip request. Please check!',
          'senderId': widget.otherUserId,
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 8, minutes: 40)),
          'type': 'text',
        },
        {
          'messageId': '11',
          'message': '✅ Trip request accepted',
          'senderId': 'system',
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 8, minutes: 30)),
          'type': 'system',
        },
        {
          'messageId': '12',
          'message': 'Great! I\'ve accepted your request. Looking forward to helping you!',
          'senderId': currentUserId,
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 8, minutes: 25)),
          'type': 'text',
        },
        {
          'messageId': '13',
          'message': 'Thank you so much! Here\'s the pickup address: Shop No. 5, Platform 1, Mumbai Central Station',
          'senderId': currentUserId,
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 8, minutes: 20)),
          'type': 'text',
        },
        {
          'messageId': '14',
          'message': 'Perfect! I\'ve noted it down. And where should I deliver it in Pune?',
          'senderId': widget.otherUserId,
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 8, minutes: 15)),
          'type': 'text',
        },
        {
          'messageId': '15',
          'message': 'Delivery address: B-204, Seasons Mall, Magarpatta, Pune. My colleague will receive it.',
          'senderId': currentUserId,
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 8, minutes: 10)),
          'type': 'text',
        },
        {
          'messageId': '16',
          'message': 'Got it! Please share the receiver\'s contact number.',
          'senderId': widget.otherUserId,
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 8, minutes: 5)),
          'type': 'text',
        },
        {
          'messageId': '17',
          'message': 'Receiver contact: +91 98765 43210 (Priya)',
          'senderId': currentUserId,
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 8)),
          'type': 'text',
        },
        {
          'messageId': '18',
          'message': 'Noted! One more thing - the package is fragile, right? I saw electronics mentioned.',
          'senderId': widget.otherUserId,
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 7, minutes: 50)),
          'type': 'text',
        },
        {
          'messageId': '19',
          'message': 'Yes, it\'s a laptop. Please handle with care and avoid placing anything heavy on it.',
          'senderId': currentUserId,
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 7, minutes: 45)),
          'type': 'text',
        },
        {
          'messageId': '20',
          'message': 'Don\'t worry! I\'ll keep it safely in the front seat. See you tomorrow at 9:30 AM! 👍',
          'senderId': widget.otherUserId,
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 7, minutes: 40)),
          'type': 'text',
        },
        {
          'messageId': '21',
          'message': 'Thank you! See you tomorrow. Have a safe journey! 🙏',
          'senderId': currentUserId,
          'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 7, minutes: 35)),
          'type': 'text',
        },
        {
          'messageId': '22',
          'message': 'Good morning! I\'m on my way to the pickup location. Will reach in 15 minutes.',
          'senderId': widget.otherUserId,
          'timestamp': DateTime.now().subtract(const Duration(hours: 8)),
          'type': 'text',
        },
        {
          'messageId': '23',
          'message': 'Perfect! I\'m already here at Platform 1. Waiting near Shop No. 5.',
          'senderId': currentUserId,
          'timestamp': DateTime.now().subtract(const Duration(hours: 7, minutes: 50)),
          'type': 'text',
        },
        {
          'messageId': '24',
          'message': 'Package picked up! Starting my journey to Pune now. Will update you when I reach.',
          'senderId': widget.otherUserId,
          'timestamp': DateTime.now().subtract(const Duration(hours: 7, minutes: 30)),
          'type': 'text',
        },
        {
          'messageId': '25',
          'message': 'Great! Thank you so much. Have a safe drive! 🚗',
          'senderId': currentUserId,
          'timestamp': DateTime.now().subtract(const Duration(hours: 7, minutes: 25)),
          'type': 'text',
        },
        {
          'messageId': '26',
          'message': 'Hi! I\'ve reached Pune. On my way to Magarpatta now. Should reach in 20 minutes.',
          'senderId': widget.otherUserId,
          'timestamp': DateTime.now().subtract(const Duration(hours: 4, minutes: 20)),
          'type': 'text',
        },
        {
          'messageId': '27',
          'message': 'Excellent! I\'ve informed Priya. She\'s ready to receive it.',
          'senderId': currentUserId,
          'timestamp': DateTime.now().subtract(const Duration(hours: 4, minutes: 15)),
          'type': 'text',
        },
        {
          'messageId': '28',
          'message': 'Package delivered successfully to Priya at Seasons Mall! She confirmed receipt. 📦✅',
          'senderId': widget.otherUserId,
          'timestamp': DateTime.now().subtract(const Duration(hours: 4)),
          'type': 'text',
        },
        {
          'messageId': '29',
          'message': 'Awesome! Thank you so much for the safe delivery! You were very professional. 🙏',
          'senderId': currentUserId,
          'timestamp': DateTime.now().subtract(const Duration(hours: 3, minutes: 55)),
          'type': 'text',
        },
        {
          'messageId': '30',
          'message': 'My pleasure! Glad I could help. Feel free to contact me for any future deliveries on this route! 😊',
          'senderId': widget.otherUserId,
          'timestamp': DateTime.now().subtract(const Duration(hours: 3, minutes: 50)),
          'type': 'text',
        },
      ];

      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
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
                Text(
                  'Order #${widget.orderId}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        final isMe = message['senderId'] == currentUserId;
        return ModernMessageBubble(
          message: message,
          messageId: message['messageId'],
          isMe: isMe,
          onReply: (messageData) => _setReplyMessage(message['messageId'], messageData),
          onCopy: _copyMessage,
          onLaunchUrl: _launchUrl,
        );
      },
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

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      messages.add({
        'messageId': DateTime.now().millisecondsSinceEpoch.toString(),
        'message': message,
        'senderId': currentUserId,
        'timestamp': DateTime.now(),
        'type': 'text',
        if (replyingToMessageId != null) 'replyTo': replyingToMessageId,
        if (replyingToMessage != null) 'replyMessage': replyingToMessage!['message'],
      });
    });

    _messageController.clear();
    _clearReply();

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
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
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

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
    if (isSystem) {
      return _buildSystemMessage();
    }

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context),
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
                        color: isMe ? Colors.blue.shade600 : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isMe ? 20 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _buildMessageContent(),
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
                  color: Colors.blue.shade600,
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
        color: isMe ? Colors.blue.shade700 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: isMe ? Colors.white : Colors.blue.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message['replyMessage'] ?? '',
              style: TextStyle(
                fontSize: 12,
                color: isMe ? Colors.white70 : Colors.grey.shade600,
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
        color: isMe ? Colors.white : Colors.black87,
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
            color: isMe ? Colors.white : Colors.black87,
          ),
        ));
      }

      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          fontSize: 15,
          color: isMe ? Colors.white : Colors.blue.shade600,
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
          color: isMe ? Colors.white : Colors.black87,
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
