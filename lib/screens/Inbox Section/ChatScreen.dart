import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../Constants/ApiConstants.dart';
import '../../Controllers/AuthService.dart';
import '../../Controllers/ChatService.dart';
import 'package:device_info_plus/device_info_plus.dart';

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

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  int? _currentUserId;
  Map<String, dynamic> otherUserData = {};
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  String? _errorMessage;
  String? replyingToMessageId;
  Map<String, dynamic>? replyingToMessage;
  Timer? _autoRefreshTimer;
  bool _isRefreshing = false;
  List<File> _selectedImages = [];
  bool _isUploadingImages = false;
  Set<int> _unseenMessageIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
    _startAutoRefresh();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      print('📱 App resumed - refreshing messages...');
      _loadMessages(silent: true);
      if (_autoRefreshTimer?.isActive != true) {
        _startAutoRefresh();
      }
      _markVisibleMessagesAsSeen();
    } else if (state == AppLifecycleState.paused) {
      print('📱 App paused - stopping auto-refresh...');
      _autoRefreshTimer?.cancel();
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      _markVisibleMessagesAsSeen();
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
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

    print('🔐 Current User ID: $_currentUserId');
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
        final apiMessages = result['messages'] as List;
        final convertedMessages = apiMessages.map((msg) {
          final messageId = msg['id'];
          final senderId = msg['user_id'] ?? msg['sender_id'];
          final senderName = msg['sender_name'] ?? 'Unknown';
          final messageText = msg['message'] ?? '';
          final mediaUrl = msg['media_url'] as String?;
          final replyToId = msg['reply_to'];
          final replyMessage = msg['reply_message'];
          final replySenderName = msg['reply_sender_name'];

          // ✅ CORRECTED: Handle seen status - 1 = read, 0 = not read
          final seenValue = msg['seen'];
          final seen = (seenValue == 1 || seenValue == true);
          final seenAt = msg['seen_at'];

          final hasMedia = mediaUrl != null && mediaUrl.isNotEmpty;

          // Track unseen messages from other users (seen = 0 means not read)
          if (!seen && senderId != _currentUserId) {
            _unseenMessageIds.add(messageId);
          } else if (seen && _unseenMessageIds.contains(messageId)) {
            // Remove from unseen if it was marked as seen
            _unseenMessageIds.remove(messageId);
          }

          Map<String, dynamic>? replyData;
          if (replyToId != null && replyMessage != null) {
            replyData = {
              'message': replyMessage,
              'sender_name': replySenderName ?? 'Unknown',
              'reply_to_id': replyToId,
            };
          }

          return {
            'messageId': messageId,
            'message': messageText,
            'senderId': senderId,
            'senderName': senderName,
            'timestamp': DateTime.parse(msg['created_at']),
            'type': hasMedia ? 'image' : 'text',
            'mediaUrl': hasMedia ? mediaUrl : null,
            'replyToId': replyToId,
            'replyData': replyData,
            'seen': seen, // true if seen = 1, false if seen = 0
            'seenAt': seenAt != null ? DateTime.parse(seenAt) : null,
          };
        }).toList();

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

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _markVisibleMessagesAsSeen();
        });

        if (!silent) {
          print('✅ Loaded ${messages.length} messages from API');
          print('📊 Unseen messages: ${_unseenMessageIds.length}');
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

  void _markVisibleMessagesAsSeen() {
    if (_unseenMessageIds.isEmpty || !_scrollController.hasClients) return;

    final visibleMessageIds = <int>[];

    for (int i = 0; i < messages.length; i++) {
      final message = messages[messages.length - 1 - i];
      final messageId = message['messageId'];
      final senderId = message['senderId'];

      if (senderId != _currentUserId && _unseenMessageIds.contains(messageId)) {
        visibleMessageIds.add(messageId);
      }
    }

    if (visibleMessageIds.isNotEmpty) {
      _markMessagesAsSeen(visibleMessageIds);
    }
  }

  Future<void> _markMessagesAsSeen(List<int> messageIds) async {
    try {
      final chatIdInt = int.tryParse(widget.chatId);
      if (chatIdInt == null || _currentUserId == null) return;

      // Uncomment when backend API is ready
      // final result = await ChatService.markMessagesAsSeen(
      //   chatId: chatIdInt,
      //   messageIds: messageIds,
      // );
      //
      // if (result['success'] == true) {
      //   setState(() {
      //     _unseenMessageIds.removeAll(messageIds);
      //     // Update seen status in local messages
      //     for (var msg in messages) {
      //       if (messageIds.contains(msg['messageId'])) {
      //         msg['seen'] = true; // Mark as read (1)
      //         msg['seenAt'] = DateTime.now();
      //       }
      //     }
      //   });
      //   print('✅ Marked ${messageIds.length} messages as seen');
      // }
    } catch (e) {
      print('❌ Error marking messages as seen: $e');
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages = images.map((xFile) => File(xFile.path)).toList();
        });
      }
    } catch (e) {
      print('❌ Error picking images: $e');
      _showSnackBar('Failed to pick images: $e', Colors.red);
    }
  }

  Future<void> _pickCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImages.add(File(image.path));
        });
      }
    } catch (e) {
      print('❌ Error taking photo: $e');
      _showSnackBar('Failed to take photo: $e', Colors.red);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add Images',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickCamera();
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickImages();
                    },
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
          if (_selectedImages.isNotEmpty) _buildImagePreview(),
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

          return Dismissible(
            key: Key('${message['messageId']}_$index'),
            direction: DismissDirection.horizontal,
            confirmDismiss: (direction) async {
              _setReplyMessage(message['messageId'].toString(), message);
              return false;
            },
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              child: Icon(
                Icons.reply,
                color: Colors.blue.shade600,
                size: 28,
              ),
            ),
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: Icon(
                Icons.reply,
                color: Colors.blue.shade600,
                size: 28,
              ),
            ),
            child: ModernMessageBubble(
              message: message,
              messageId: message['messageId'].toString(),
              isMe: isMe,
              currentUserId: _currentUserId,
              onReply: (messageData) => _setReplyMessage(message['messageId'].toString(), messageData),
              onCopy: _copyMessage,
              onLaunchUrl: _launchUrl,
              onDownloadImage: _downloadImage,
            ),
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

    String previewText = replyingToMessage!['message'] ?? '';
    if (previewText.isEmpty && replyingToMessage!['type'] == 'image') {
      previewText = '📷 Image';
    }

    final isReplyToMe = replyingToMessage!['senderId'] == _currentUserId;
    final senderName = isReplyToMe ? 'You' : (replyingToMessage!['senderName'] ?? 'Unknown');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isReplyToMe ? Colors.teal.shade400 : Colors.blue.shade600,
            width: 3,
          ),
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
                  'Replying to $senderName',
                  style: TextStyle(
                    fontSize: 12,
                    color: isReplyToMe ? Colors.teal.shade700 : Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  previewText,
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

  Widget _buildImagePreview() {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImages[index],
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _removeImage(index),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
            IconButton(
              icon: Icon(Icons.image, color: Colors.blue.shade600),
              onPressed: _showImagePickerOptions,
              tooltip: 'Add Images',
            ),
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
                color: _isUploadingImages
                    ? Colors.grey
                    : Colors.blue.shade600,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isUploadingImages
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _isUploadingImages ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty && _selectedImages.isEmpty) return;

    final chatIdInt = int.tryParse(widget.chatId);
    if (chatIdInt == null) {
      _showSnackBar('Invalid chat ID', Colors.red);
      return;
    }

    _messageController.clear();
    final imagesToSend = List<File>.from(_selectedImages);
    final replyToId = replyingToMessageId != null ? int.tryParse(replyingToMessageId!) : null;

    setState(() {
      _selectedImages.clear();
    });

    _clearReply();

    setState(() {
      _isUploadingImages = true;
    });

    try {
      final result = await ChatService.sendMessage(
        chatId: chatIdInt,
        message: message.isNotEmpty ? message : null,
        images: imagesToSend.isNotEmpty ? imagesToSend : null,
        replyTo: replyToId,
      );

      if (result['success'] == true) {
        print('✅ Message sent successfully');
        await _loadMessages(silent: true);
      } else {
        _showSnackBar(
          result['error'] ?? 'Failed to send message',
          Colors.red,
        );
        print('❌ Failed to send message: ${result['error']}');
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
      print('❌ Exception sending message: $e');
    } finally {
      setState(() {
        _isUploadingImages = false;
      });
    }
  }

  void _setReplyMessage(String messageId, Map<String, dynamic> messageData) {
    setState(() {
      replyingToMessageId = messageId;
      replyingToMessage = messageData;
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _clearReply() {
    setState(() {
      replyingToMessageId = null;
      replyingToMessage = null;
    });
  }

  void _copyMessage(String message) {
    Clipboard.setData(ClipboardData(text: message));
    _showSnackBar('Message copied to clipboard', Colors.green);
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _showSnackBar('Could not open link', Colors.red);
    }
  }

  Future<void> _downloadImage(String imageUrl) async {
    try {
      _showSnackBar('Downloading image...', Colors.blue);

      bool hasPermission = false;

      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          final status = await Permission.photos.request();
          hasPermission = status.isGranted;
        } else if (androidInfo.version.sdkInt >= 30) {
          final status = await Permission.manageExternalStorage.request();
          hasPermission = status.isGranted;
          if (!hasPermission) {
            final storageStatus = await Permission.storage.request();
            hasPermission = storageStatus.isGranted;
          }
        } else {
          final status = await Permission.storage.request();
          hasPermission = status.isGranted;
        }
      } else {
        final status = await Permission.photos.request();
        hasPermission = status.isGranted;
      }

      if (!hasPermission) {
        _showSnackBar('Storage permission denied. Please enable it in settings.', Colors.red);
        return;
      }

      String fullUrl = imageUrl;
      if (!imageUrl.startsWith('http')) {
        fullUrl = '${ApiConstants.imagebaseUrl}$imageUrl';
      }

      print('📥 Downloading from: $fullUrl');

      final response = await http.get(Uri.parse(fullUrl));

      if (response.statusCode != 200) {
        _showSnackBar('Failed to download image (${response.statusCode})', Colors.red);
        return;
      }

      String? savedPath;

      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 29) {
          final directory = await getExternalStorageDirectory();
          if (directory != null) {
            final picturesDir = Directory('${directory.path}/Pictures');
            if (!await picturesDir.exists()) {
              await picturesDir.create(recursive: true);
            }
            final fileName = 'dolo_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final filePath = '${picturesDir.path}/$fileName';
            final file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);
            savedPath = filePath;
          }
        } else {
          final directory = Directory('/storage/emulated/0/Download');
          if (await directory.exists()) {
            final fileName = 'dolo_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final filePath = '${directory.path}/$fileName';
            final file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);
            savedPath = filePath;
          }
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'dolo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        savedPath = filePath;
      }

      if (savedPath != null) {
        _showSnackBar('Image saved successfully', Colors.green);
        print('✅ Image saved to: $savedPath');
      } else {
        _showSnackBar('Failed to save image', Colors.red);
      }
    } catch (e) {
      print('❌ Error downloading image: $e');
      _showSnackBar('Error downloading image: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// ✅ ENHANCED: Modern Message Bubble Widget with Proper Seen Status (1 = read, 0 = not read)
class ModernMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final String messageId;
  final bool isMe;
  final int? currentUserId;
  final Function(Map<String, dynamic>) onReply;
  final Function(String) onCopy;
  final Function(String) onLaunchUrl;
  final Function(String) onDownloadImage;

  const ModernMessageBubble({
    Key? key,
    required this.message,
    required this.messageId,
    required this.isMe,
    required this.currentUserId,
    required this.onReply,
    required this.onCopy,
    required this.onLaunchUrl,
    required this.onDownloadImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final messageText = message['message'] ?? '';
    final timestamp = message['timestamp'] as DateTime?;
    final timeString = timestamp != null
        ? DateFormat('hh:mm a').format(timestamp)
        : '';
    final messageType = message['type'] ?? 'text';
    final mediaUrl = message['mediaUrl'];
    final hasReply = message['replyData'] != null;

    // ✅ Get seen status: true if seen = 1, false if seen = 0
    final seen = message['seen'] == true;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) _buildAvatar(),
            if (!isMe) const SizedBox(width: 8),
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(
                    colors: [Colors.blueGrey.shade600, Colors.blueGrey.shade500],
                  )
                      : null,
                  color: isMe ? null : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message['senderName'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    if (hasReply) _buildWhatsAppStyleReplySection(),
                    if (messageType == 'image' && mediaUrl != null)
                      _buildImageMessage(mediaUrl),
                    if (messageText.isNotEmpty) _buildTextMessage(messageText),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          timeString,
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe ? Colors.white70 : Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // ✅ Show seen indicator only for messages sent by current user
                        // Single checkmark = sent (seen = 0), Double checkmark = read (seen = 1)
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            seen ? Icons.done_all : Icons.done,
                            size: 16,
                            color: seen ? Colors.lightBlueAccent : Colors.white70,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isMe) const SizedBox(width: 8),
            if (isMe) _buildAvatar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final name = message['senderName'] ?? 'U';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isMe
              ? [Colors.blue.shade400, Colors.blue.shade600]
              : [Colors.grey.shade400, Colors.grey.shade600],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildWhatsAppStyleReplySection() {
    final replyData = message['replyData'];
    if (replyData == null) return const SizedBox.shrink();

    final replyText = replyData['message'] ?? '';
    final replySenderName = replyData['sender_name'] ?? 'Unknown';

    final currentUserName = message['senderName'];
    final isReplyFromMe = replySenderName == currentUserName;
    final displayName = isReplyFromMe ? 'You' : replySenderName;

    return GestureDetector(
      onTap: () {
        print('📌 Tapped on reply - scroll to original message');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.black.withOpacity(0.15)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isMe
                  ? Colors.white.withOpacity(0.8)
                  : (isReplyFromMe
                  ? Colors.teal.shade400
                  : Colors.grey.shade400),
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isMe
                    ? Colors.white.withOpacity(0.95)
                    : (isReplyFromMe
                    ? Colors.teal.shade600
                    : Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              replyText.isNotEmpty ? replyText : '📷 Photo',
              style: TextStyle(
                fontSize: 13,
                color: isMe
                    ? Colors.white.withOpacity(0.8)
                    : Colors.grey.shade800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageMessage(String mediaUrl) {
    String fullUrl = mediaUrl;
    if (!mediaUrl.startsWith('http')) {
      fullUrl = '${ApiConstants.imagebaseUrl}$mediaUrl';
    }

    return GestureDetector(
      onTap: () => onLaunchUrl(fullUrl),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            fullUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 200,
                width: 200,
                color: Colors.grey[300],
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 200,
                width: 200,
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextMessage(String messageText) {
    return SelectableText(
      messageText,
      style: TextStyle(
        fontSize: 15,
        height: 1.4,
        color: isMe ? Colors.white : Colors.black87,
      ),
    );
  }

  void _showMessageOptions(BuildContext context) {
    final messageText = message['message'] ?? '';
    final messageType = message['type'] ?? 'text';
    final mediaUrl = message['mediaUrl'];

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
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.blue),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReply(message);
              },
            ),
            if (messageText.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.grey),
                title: const Text('Copy Text'),
                onTap: () {
                  Navigator.pop(context);
                  onCopy(messageText);
                },
              ),
            if (messageType == 'image' && mediaUrl != null)
              ListTile(
                leading: const Icon(Icons.download, color: Colors.green),
                title: const Text('Download Image'),
                onTap: () {
                  Navigator.pop(context);
                  onDownloadImage(mediaUrl);
                },
              ),
            if (messageType == 'image' && mediaUrl != null)
              ListTile(
                leading: const Icon(Icons.open_in_new, color: Colors.orange),
                title: const Text('Open Image'),
                onTap: () {
                  Navigator.pop(context);
                  String fullUrl = mediaUrl;
                  if (!mediaUrl.startsWith('http')) {
                    fullUrl = '${ApiConstants.imagebaseUrl}$mediaUrl';
                  }
                  onLaunchUrl(fullUrl);
                },
              ),
          ],
        ),
      ),
    );
  }
}