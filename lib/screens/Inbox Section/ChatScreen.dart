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
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../Constants/ApiConstants.dart';
import '../../Controllers/AuthService.dart';
import '../../Controllers/ChatService.dart';
import '../../Controllers/SocketService.dart';
import '../../Controllers/tutorial_service.dart';
import '../../widgets/tutorial_helper.dart';
import '../../widgets/NotificationBellIcon.dart';
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
  final SocketService _socketService = SocketService();

  String? _currentUserId;
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

  // WebSocket typing indicator states
  bool _isOtherUserTyping = false;
  Timer? _typingTimer;
  Timer? _typingIndicatorTimer;

  // Tutorial keys
  TutorialCoachMark? _tutorialCoachMark;
  final GlobalKey _messageInputKey = GlobalKey();
  final GlobalKey _imagePickerKey = GlobalKey();
  final GlobalKey _sendButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
    _initializeWebSocket();
    _startAutoRefresh();
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onTextChanged);
    _checkAndShowTutorial();
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

  Future<void> _initializeWebSocket() async {
    try {
      await _socketService.connect();

      if (_socketService.isConnected) {
        _socketService.joinRoom(widget.chatId);

        _socketService.onReceiveMessage((data) {
          print('📬 Received message via WebSocket: $data');
          _loadMessages(silent: true);
        });

        _socketService.onUserTyping((data) {
          final typingUserId = data['userId'] as String?;
          print('🔍 ChatScreen - Typing event received: userId=$typingUserId, currentUserId=$_currentUserId, mounted=$mounted');

          if (typingUserId != null && typingUserId != _currentUserId) {
            if (mounted) {
              print('✅ ChatScreen - Showing typing indicator for user: $typingUserId');
              setState(() {
                _isOtherUserTyping = true;
              });

              _typingIndicatorTimer?.cancel();
              _typingIndicatorTimer = Timer(const Duration(seconds: 3), () {
                if (mounted) {
                  print('⏰ ChatScreen - Hiding typing indicator (timeout)');
                  setState(() {
                    _isOtherUserTyping = false;
                  });
                }
              });
            }
          }
        });

        print('✅ WebSocket initialized and listening');
      }
    } catch (e) {
      print('❌ Error initializing WebSocket: $e');
    }
  }

  void _onTextChanged() {
    if (_messageController.text.isEmpty) {
      _typingTimer?.cancel();
      return;
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 500), () {
      if (_socketService.isConnected) {
        _socketService.sendTypingIndicator(widget.chatId);
      }
    });
  }

  Future<void> _checkAndShowTutorial() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final isCompleted = await TutorialService.isChatTutorialCompleted();
    if (!isCompleted) {
      _showTutorial();
    }
  }

  void _showTutorial() {
    final targets = [
      TutorialHelper.createTarget(
        key: _messageInputKey,
        title: 'Type Your Message',
        description: 'Type your message here to communicate with the other user.',
        order: 1,
        align: ContentAlign.top,
      ),
      TutorialHelper.createTarget(
        key: _imagePickerKey,
        title: 'Send Images',
        description: 'Tap this button to attach images from your gallery or camera.',
        order: 2,
        align: ContentAlign.top,
      ),
      TutorialHelper.createFinalTarget(
        key: _sendButtonKey,
        title: 'Send Message',
        description: 'Tap this button to send your message.',
        order: 3,
        align: ContentAlign.top,
        onFinish: () async {
          await TutorialService.markChatTutorialCompleted();
        },
      ),
    ];

    _tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: const Color(0xFF001127),
      paddingFocus: 10,
      opacityShadow: 0.8,
      hideSkip: false,
      onSkip: () {
        TutorialService.markChatTutorialCompleted();
        return true;
      },
      onFinish: () {
        TutorialService.markChatTutorialCompleted();
      },
    );

    _tutorialCoachMark?.show(context: context);
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
      final result = await ChatService.getChatMessages(chatId: widget.chatId);

      if (!mounted) {
        _isRefreshing = false;
        return;
      }

      if (result['success'] == true) {
        final apiMessages = result['messages'] as List;
        final convertedMessages = apiMessages.map((msg) {
          final messageIdRaw = msg['id'];
          final messageId = messageIdRaw is int ? messageIdRaw : int.tryParse(messageIdRaw.toString()) ?? 0;

          final senderId = msg['user_id'] ?? msg['sender_id'];
          final senderName = msg['sender_name'] ?? 'Unknown';
          final messageText = msg['message'] ?? '';
          final mediaUrl = msg['media_url'] as String?;
          final replyToId = msg['reply_to'];
          final replyMessage = msg['reply_message'];
          final replySenderName = msg['reply_sender_name'];

          final seenValue = msg['seen'];
          final seen = (seenValue == 1 || seenValue == true);
          final seenAt = msg['seen_at'];

          final hasMedia = mediaUrl != null && mediaUrl.isNotEmpty;

          if (!seen && senderId != _currentUserId) {
            _unseenMessageIds.add(messageId);
          } else if (seen && _unseenMessageIds.contains(messageId)) {
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
            'seen': seen,
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
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: _buildAppBar(),
        body: _buildErrorState(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0.5,
      backgroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          _buildProfileAvatar(otherUserData['name'] ?? 'U', false, 40),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              otherUserData['name'] ?? 'Unknown User',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.phone, color: Colors.black87),
          onPressed: () {},
        ),
        PopupMenuButton(
          icon: const Icon(Icons.more_vert, color: Colors.black87),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: Text('Refresh'),
            ),
          ],
          onSelected: (value) {
            if (value == 'refresh') {
              _loadMessages(silent: false);
            }
          },
        ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: messages.length + (_isOtherUserTyping ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0 && _isOtherUserTyping) {
            return _buildTypingIndicator();
          }

          final messageIndex = _isOtherUserTyping ? index - 1 : index;
          final message = messages[messages.length - 1 - messageIndex];
          final isMe = message['senderId'] == _currentUserId;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: EnhancedMessageBubble(
              message: message,
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
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadMessages(silent: false),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
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
            color: Colors.blue.shade600,
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
                    color: Colors.blue.shade700,
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
                      decoration: const BoxDecoration(
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                key: _messageInputKey,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'I.....',
                          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                        ),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    IconButton(
                      key: _imagePickerKey,
                      icon: Icon(Icons.attach_file, color: Colors.grey.shade600, size: 22),
                      onPressed: _showImagePickerOptions,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              key: _sendButtonKey,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isUploadingImages
                      ? [Colors.grey, Colors.grey]
                      : [const Color(0xFF6B4FE8), const Color(0xFF8B6FFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B4FE8).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isUploadingImages ? null : _sendMessage,
                  borderRadius: BorderRadius.circular(24),
                  child: Center(
                    child: _isUploadingImages
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                        : const Text(
                      'S',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          _buildProfileAvatar(otherUserData['name'] ?? 'U', false, 32),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Typing',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  height: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDot(0),
                      _buildDot(150),
                      _buildDot(300),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return FutureBuilder(
          future: Future.delayed(Duration(milliseconds: delay)),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  shape: BoxShape.circle,
                ),
              );
            }
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: value > 0.5 ? Colors.grey.shade600 : Colors.grey.shade400,
                shape: BoxShape.circle,
              ),
            );
          },
        );
      },
      onEnd: () {
        if (mounted && _isOtherUserTyping) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildProfileAvatar(String name, bool isMe, double size) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isMe
              ? [const Color(0xFF6B4FE8), const Color(0xFF8B6FFF)]
              : [Colors.grey.shade400, Colors.grey.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty && _selectedImages.isEmpty) return;

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
        chatId: widget.chatId,
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
    _typingTimer?.cancel();
    _typingIndicatorTimer?.cancel();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _socketService.leaveRoom();
    super.dispose();
  }
}

// Enhanced Message Bubble matching the design
class EnhancedMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final String? currentUserId;
  final Function(Map<String, dynamic>) onReply;
  final Function(String) onCopy;
  final Function(String) onLaunchUrl;
  final Function(String) onDownloadImage;

  const EnhancedMessageBubble({
    Key? key,
    required this.message,
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
    final messageType = message['type'] ?? 'text';
    final mediaUrl = message['mediaUrl'];
    final hasReply = message['replyData'] != null;
    final seen = message['seen'] == true;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            _buildAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? Colors.white : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasReply) _buildReplySection(),
                  if (messageType == 'image' && mediaUrl != null)
                    _buildImageMessage(mediaUrl),
                  if (messageText.isNotEmpty)
                    SelectableText(
                      messageText,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  if (timestamp != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isMe) ...[
                          Icon(
                            seen ? Icons.done_all : Icons.done,
                            size: 14,
                            color: seen ? Colors.blue : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          DateFormat('hh:mm a').format(timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            _buildAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final name = message['senderName'] ?? 'U';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isMe
              ? [const Color(0xFF6B4FE8), const Color(0xFF8B6FFF)]
              : [Colors.grey.shade400, Colors.grey.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildReplySection() {
    final replyData = message['replyData'];
    if (replyData == null) return const SizedBox.shrink();

    final replyText = replyData['message'] ?? '';
    final replySenderName = replyData['sender_name'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: Colors.grey.shade400,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replySenderName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            replyText.isNotEmpty ? replyText : '📷 Photo',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade800,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
                child: const Center(child: CircularProgressIndicator()),
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
          ],
        ),
      ),
    );
  }
}