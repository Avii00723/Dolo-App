import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../widgets/ReportScreen.dart';
import '../../widgets/tutorial_helper.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../UserProfileScreen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String orderId;
  final String? otherUserName;
  final String? otherUserId;
  final bool isOrderAccepted;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.orderId,
    this.otherUserName,
    this.otherUserId,
    this.isOrderAccepted = false,
  });

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
  final Set<String> _unseenMessageIds = {};

  // WebSocket typing indicator states
  bool _isOtherUserTyping = false;
  Timer? _typingTimer;
  Timer? _typingIndicatorTimer;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _typingSubscription;

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
      debugPrint('📱 App resumed - refreshing messages...');
      _loadMessages(silent: true);
      if (_autoRefreshTimer?.isActive != true) {
        _startAutoRefresh();
      }
      _markVisibleMessagesAsSeen();
    } else if (state == AppLifecycleState.paused) {
      debugPrint('📱 App paused - stopping auto-refresh...');
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
        debugPrint('🔄 Auto-refreshing messages at ${DateTime.now()}');
        _loadMessages(silent: true);
      }
    });
    debugPrint('✅ Auto-refresh timer started (every 5 seconds)');
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

    debugPrint('🔐 Current User ID: $_currentUserId');
    await _loadMessages();
  }

  Future<void> _initializeWebSocket() async {
    try {
      await _socketService.connect();
      _socketService.joinChat(widget.chatId);

      if (_socketService.socket != null) {
        _messageSubscription = _socketService.onReceiveMessage((data) {
          debugPrint('📬 Received message via WebSocket: $data');
          _loadMessages(silent: true);
        });

        _typingSubscription = _socketService.onUserTyping((data) {
          final typingUserId = data['userId'] as String?;
          debugPrint(
              '🔍 ChatScreen - Typing event received: userId=$typingUserId, currentUserId=$_currentUserId, mounted=$mounted');

          if (typingUserId != null && typingUserId != _currentUserId) {
            if (mounted) {
              debugPrint(
                  '✅ ChatScreen - Showing typing indicator for user: $typingUserId');
              setState(() {
                _isOtherUserTyping = true;
              });

              _typingIndicatorTimer?.cancel();
              _typingIndicatorTimer = Timer(const Duration(seconds: 3), () {
                if (mounted) {
                  debugPrint(
                      '⏰ ChatScreen - Hiding typing indicator (timeout)');
                  setState(() {
                    _isOtherUserTyping = false;
                  });
                }
              });
            }
          }
        });

        debugPrint('✅ WebSocket initialized and listening');
      }
    } catch (e) {
      debugPrint('❌ Error initializing WebSocket: $e');
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
        description:
        'Type your message here to communicate with the other user.',
        order: 1,
        align: ContentAlign.top,
      ),
      TutorialHelper.createTarget(
        key: _imagePickerKey,
        title: 'Send Images',
        description:
        'Tap this button to attach images from your gallery or camera.',
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
          // Message ID is a string (e.g. "NJXBIBTI24URKMZCUES1DMMA"), keep as-is
          final messageId = msg['id']?.toString() ?? '';

          final senderId = msg['user_id'] ?? msg['sender_id'];
          final senderName = msg['sender_name'] ?? 'Unknown';
          // message may be null when only images are sent
          final messageText = msg['message'] ?? '';

          // API returns an "images" array: ["/chat_images/xxx.jpg", ...]
          final rawImages = msg['images'];
          List<String> mediaUrls = [];
          if (rawImages is List) {
            mediaUrls = rawImages
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
          } else if (rawImages is String && rawImages.trim().isNotEmpty) {
            // fallback: single string
            mediaUrls = [rawImages.trim()];
          }
          debugPrint('📸 msg id=${msg['id']} images=$rawImages -> mediaUrls=$mediaUrls');

          final mediaUrl = mediaUrls.isNotEmpty ? mediaUrls.first : null;
          final replyToId = msg['reply_to'];
          final replyMessage = msg['reply_message'];
          final replySenderName = msg['reply_sender_name'];

          final seenValue = msg['seen'];
          final seen = (seenValue == 1 || seenValue == true);
          final seenAt = msg['seen_at'];

          final hasMedia = mediaUrls.isNotEmpty;

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

          final createdAt = _parseMessageDateTime(msg['created_at']);

          return {
            'messageId': messageId,
            'message': messageText,
            'senderId': senderId,
            'senderName': senderName,
            'timestamp': createdAt,
            'type': hasMedia ? (messageText.isNotEmpty ? 'image_with_caption' : 'image') : 'text',
            'mediaUrl': hasMedia ? mediaUrl : null,
            'mediaUrls': mediaUrls,
            'replyToId': replyToId,
            'replyData': replyData,
            'seen': seen,
            'seenAt': _parseMessageDateTime(seenAt),
          };
        }).toList();

        final scrollOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
        final wasAtBottom = scrollOffset < 50;

        setState(() {
          messages = convertedMessages;
          String? bestOtherUserId = widget.otherUserId;
          String? bestOtherUserName = widget.otherUserName;

          if (convertedMessages.isNotEmpty) {
            final firstOtherMessage = convertedMessages.firstWhere(
                  (msg) => msg['senderId'] != _currentUserId,
              orElse: () => {},
            );

            if (firstOtherMessage.isNotEmpty) {
              bestOtherUserId = firstOtherMessage['senderId'].toString();
              bestOtherUserName =
                  firstOtherMessage['senderName'] ?? bestOtherUserName;
            }
          }

          otherUserData = {
            'id': bestOtherUserId,
            'name': bestOtherUserName ?? 'Unknown User',
            'profileUrl': '',
          };

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
          debugPrint('✅ Loaded ${messages.length} messages from API');
          debugPrint('📊 Unseen messages: ${_unseenMessageIds.length}');
        }
      } else {
        if (!silent) {
          final errText = result['error']?.toString() ?? '';
          final errLower = errText.toLowerCase();
          final isBackendDown =
              errLower.contains('BACKEND_DOWN'.toLowerCase()) ||
                  errLower.contains('socketexception'.toLowerCase()) ||
                  errLower.contains('network is unreachable'.toLowerCase()) ||
                  errLower.contains('connection failed'.toLowerCase()) ||
                  errLower.contains('timed out'.toLowerCase());

          setState(() {
            isLoading = false;
            _errorMessage =
            isBackendDown ? 'BACKEND_DOWN' : (result['error'] as String?);
            otherUserData = {
              'id': widget.otherUserId,
              'name': widget.otherUserName ?? 'Unknown User',
              'profileUrl': '',
            };
          });
        }
        debugPrint('⚠️ Failed to load messages: ${result['error']}');
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
            'id': widget.otherUserId,
            'name': widget.otherUserName ?? 'Unknown User',
            'profileUrl': '',
          };
        });
      }
      debugPrint('❌ Exception loading messages: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  DateTime? _parseMessageDateTime(dynamic value) {
    if (value == null) return null;

    try {
      final rawValue = value.toString().trim();
      if (rawValue.isEmpty) return null;

      final normalizedValue =
      rawValue.contains('T') ? rawValue : rawValue.replaceFirst(' ', 'T');

      // Let Dart's DateTime.tryParse handle timezone semantics:
      // - If the string contains a 'Z' or an explicit offset, it will be
      //   parsed as UTC and converted to local via `toLocal()` below.
      // - If the string has no timezone, DateTime.tryParse treats it as local,
      //   which avoids incorrectly assuming UTC for timezone-less server values.
      final parsedValue = DateTime.tryParse(normalizedValue);

      return parsedValue?.toLocal();
    } catch (_) {
      return null;
    }
  }

  void _markVisibleMessagesAsSeen() {
    if (_unseenMessageIds.isEmpty || !_scrollController.hasClients) return;

    final visibleMessageIds = <String>[];

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

  Future<void> _markMessagesAsSeen(List<String> messageIds) async {
    try {
      final chatIdInt = int.tryParse(widget.chatId);
      if (chatIdInt == null || _currentUserId == null) return;
    } catch (e) {
      debugPrint('❌ Error marking messages as seen: $e');
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
      debugPrint('❌ Error picking images: $e');
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
      debugPrint('❌ Error taking photo: $e');
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
                color: Theme.of(context).colorScheme.surface,
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
                      backgroundColor: Theme.of(context).colorScheme.primary,
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
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
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

  // NEW METHOD: Navigate to user profile
  void _navigateToUserProfile() {
    debugPrint(
        '🧭 ChatScreen _navigateToUserProfile() called - chatId=${widget.chatId} orderId=${widget.orderId} otherUserName=${otherUserData['name']} otherUserDataIdRaw=${otherUserData['id']}');
    String? otherUserId = otherUserData['id']?.toString() ?? widget.otherUserId;

    if (otherUserId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(
            userId: otherUserId,
            userName:
            otherUserData['name'] ?? widget.otherUserName ?? 'Unknown User',
            profileUrl: otherUserData['profileUrl'],
            orderId: widget.orderId,
            isOrderAccepted:
            true, // Chat is only accessible after order is accepted
          ),
        ),
      );
    } else {
      _showSnackBar('Unable to load user profile', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null && messages.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _buildAppBar(),
        body: _buildErrorState(),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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

  // UPDATED: Make the app bar title tappable

  PreferredSizeWidget _buildAppBar() {
    final bool canReport =
        widget.isOrderAccepted && otherUserData['id'] != null;

    return AppBar(
      elevation: 0.5,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon: Icon(Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: () {
          debugPrint(
              '👤 ChatScreen AppBar title tapped - chatId=${widget.chatId} orderId=${widget.orderId} otherUser=${otherUserData['name']} otherUserId=${otherUserData['id']}');
          _navigateToUserProfile();
        },
        child: Row(
          children: [
            _buildProfileAvatar(
                otherUserData['name'] ?? widget.otherUserName ?? 'U',
                false,
                40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    otherUserData['name'] ??
                        widget.otherUserName ??
                        'Unknown User',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Profile',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.primary,
                        size: 12,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon:
          Icon(Icons.phone, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () async {
            _navigateToUserProfile();
          },
        ),
        PopupMenuButton(
          icon: Icon(Icons.more_vert,
              color: Theme.of(context).colorScheme.onSurface),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 20),
                  SizedBox(width: 12),
                  Text('View Profile'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 20),
                  SizedBox(width: 12),
                  Text('Refresh'),
                ],
              ),
            ),
            // Report option — only shown when order is accepted
            if (canReport)
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text(
                      'Report',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
          ],
          onSelected: (value) {
            if (value == 'refresh') {
              _loadMessages(silent: false);
            } else if (value == 'profile') {
              debugPrint(
                  '👤 ChatScreen PopupMenu profile selected - chatId=${widget.chatId} orderId=${widget.orderId} otherUser=${otherUserData['name']} otherUserId=${otherUserData['id']}');
              _navigateToUserProfile();
            } else if (value == 'report') {
              debugPrint(
                  '🚩 ChatScreen PopupMenu report selected - orderId=${widget.orderId} reportedUserId=${otherUserData['id']}');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportScreen(
                    reportedUserId: otherUserData['id'].toString(),
                    orderId: widget.orderId,
                  ),
                ),
              );
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
          final isMe = message['senderId']?.toString() == _currentUserId;
          final showDateSeparator = _shouldShowDateSeparator(messageIndex);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDateSeparator) _buildDateSeparator(message['timestamp']),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: EnhancedMessageBubble(
                  message: message,
                  isMe: isMe,
                  currentUserId: _currentUserId,
                  onReply: (messageData) => _setReplyMessage(
                      message['messageId'].toString(), messageData),
                  onCopy: _copyMessage,
                  onLaunchUrl: _launchUrl,
                  onDownloadImage: _downloadImage,
                  onAvatarTap: isMe ? null : _navigateToUserProfile,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _shouldShowDateSeparator(int reversedMessageIndex) {
    final currentMessageIndex = messages.length - 1 - reversedMessageIndex;
    final currentTimestamp =
    messages[currentMessageIndex]['timestamp'] as DateTime?;
    if (currentTimestamp == null) return false;

    if (currentMessageIndex == 0) return true;

    final previousTimestamp =
    messages[currentMessageIndex - 1]['timestamp'] as DateTime?;
    return previousTimestamp == null ||
        !_isSameDay(currentTimestamp, previousTimestamp);
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  Widget _buildDateSeparator(DateTime? timestamp) {
    if (timestamp == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            _formatDateSeparator(timestamp),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateSeparator(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final difference = today.difference(messageDay).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return DateFormat('d MMM yyyy').format(timestamp);
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
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start the conversation',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.65),
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
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.65),
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
    if (previewText.isEmpty && (replyingToMessage!['type'] == 'image' || replyingToMessage!['type'] == 'image_with_caption')) {
      previewText = '📷 Image';
    }

    final isReplyToMe = replyingToMessage!['senderId'] == _currentUserId;
    final senderName =
    isReplyToMe ? 'You' : (replyingToMessage!['senderName'] ?? 'Unknown');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply,
              color: Theme.of(context).colorScheme.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to $senderName',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  previewText,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.65),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
                size: 18),
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.45),
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
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Theme.of(context).dividerColor),
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
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4),
                              fontSize: 15),
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
                      icon: Icon(Icons.attach_file,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                          size: 22),
                      onPressed: _showImagePickerOptions,
                      padding: EdgeInsets.zero,
                      constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
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
                      : [const Color(0xFF2B6390), const Color(0xFF3E83AE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B4FE8).withValues(alpha: 0.3),
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
                        : const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
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
          _buildProfileAvatar(
              otherUserData['name'] ?? widget.otherUserName ?? 'U', false, 32),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
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
                  color: value > 0.5
                      ? Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5)
                      : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              );
            }
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: value > 0.5
                    ? Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5)
                    : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
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
              ? [const Color(0xFF2B6390), const Color(0xFF3E83AE)]
              : [
            Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.2),
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
          ],
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
    final replyToId =
    replyingToMessageId != null ? int.tryParse(replyingToMessageId!) : null;

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
        debugPrint('✅ Message sent successfully');
        await _loadMessages(silent: true);
      } else {
        _showSnackBar(
          result['error'] ?? 'Failed to send message',
          Colors.red,
        );
        debugPrint('❌ Failed to send message: ${result['error']}');
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
      debugPrint('❌ Exception sending message: $e');
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
        _showSnackBar(
            'Storage permission denied. Please enable it in settings.',
            Colors.red);
        return;
      }

      String fullUrl = imageUrl;
      if (!imageUrl.startsWith('http')) {
        fullUrl = '${ApiConstants.imagebaseUrl}$imageUrl';
        print('⚠️ Image URL did not start with http, prepended base URL: $fullUrl');
      }

      debugPrint('📥 Downloading from: $fullUrl');

      final response = await http.get(Uri.parse(fullUrl));

      if (response.statusCode != 200) {
        _showSnackBar(
            'Failed to download image (${response.statusCode})', Colors.red);
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
            final fileName =
                'dolo_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final filePath = '${picturesDir.path}/$fileName';
            final file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);
            savedPath = filePath;
          }
        } else {
          final directory = Directory('/storage/emulated/0/Download');
          if (await directory.exists()) {
            final fileName =
                'dolo_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
        debugPrint('✅ Image saved to: $savedPath');
      } else {
        _showSnackBar('Failed to save image', Colors.red);
      }
    } catch (e) {
      debugPrint('❌ Error downloading image: $e');
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
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _socketService.leaveChat();
    _socketService.releaseConnection();
    super.dispose();
  }
}

class EnhancedMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final String? currentUserId;
  final Function(Map<String, dynamic>) onReply;
  final Function(String) onCopy;
  final Function(String) onLaunchUrl;
  final Function(String) onDownloadImage;
  final VoidCallback? onAvatarTap;

  const EnhancedMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUserId,
    required this.onReply,
    required this.onCopy,
    required this.onLaunchUrl,
    required this.onDownloadImage,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final messageText = message['message'] ?? '';
    final timestamp = message['timestamp'] as DateTime?;
    final messageType = message['type'] ?? 'text';
    final mediaUrl = message['mediaUrl'];
    final hasReply = message['replyData'] != null;
    final seen = message['seen'] == true;
    // Sent messages (isMe): dark bubble on the RIGHT
    const myBubbleColor = Color(0xFF1A3A5C);
    // Received messages (!isMe): light bubble on the LEFT
    final otherBubbleColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2C3E50)
        : const Color(0xFFEDF2F7);
    final bubbleColor = isMe ? myBubbleColor : otherBubbleColor;
    final primaryTextColor =
    isMe ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final secondaryTextColor = isMe
        ? Colors.white.withValues(alpha: 0.72)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.48);

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            _buildAvatar(context),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: isMe
                    ? null
                    : Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isMe
                        ? Colors.black.withValues(alpha: 0.30)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: isMe ? 10 : 6,
                    offset: Offset(isMe ? 2 : 0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasReply) _buildReplySection(context),
                  // Show images for both 'image' and 'image_with_caption' types
                  if ((messageType == 'image' || messageType == 'image_with_caption') &&
                      mediaUrl != null)
                    _buildImageMessage(context, mediaUrl),
                  // Caption or plain text — shown below images when both exist
                  if (messageText.isNotEmpty) ...[
                    if (messageType == 'image_with_caption')
                      const SizedBox(height: 6),
                    SelectableText(
                      messageText,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                  if (timestamp != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isMe) ...[
                          Icon(
                            seen ? Icons.done_all : Icons.done,
                            size: 14,
                            color: seen
                                ? (isMe
                                ? Colors.white
                                : Theme.of(context).colorScheme.primary)
                                : secondaryTextColor,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          DateFormat('hh:mm a').format(timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: secondaryTextColor,
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
            _buildAvatar(context),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final name = message['senderName'] ?? 'U';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    Widget avatarWidget = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isMe
              ? [const Color(0xFF2B6390), const Color(0xFF3E83AE)]
              : [
            Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.2),
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
          ],
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

    if (!isMe && onAvatarTap != null) {
      return GestureDetector(
        onTap: onAvatarTap,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }

  Widget _buildReplySection(BuildContext context) {
    final replyData = message['replyData'];
    if (replyData == null) return const SizedBox.shrink();

    final replyText = replyData['message'] ?? '';
    final replySenderName = replyData['sender_name'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color:
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
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
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            replyText.isNotEmpty ? replyText : '📷 Photo',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage(BuildContext context, String mediaUrl) {
    // Collect all URLs for this message (single or multiple)
    final rawUrls = message['mediaUrls'];
    final List<String> allUrls;
    if (rawUrls is List && (rawUrls as List).isNotEmpty) {
      allUrls = (rawUrls as List).map((e) => e.toString()).toList();
    } else {
      allUrls = [mediaUrl];
    }

    Widget singleImage(String url) {
      String fullUrl = url.trim();
      if (!fullUrl.startsWith('http')) {
        fullUrl = '${ApiConstants.imagebaseUrl}$fullUrl';
      }
      return GestureDetector(
        onTap: () => onLaunchUrl(fullUrl),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          constraints: const BoxConstraints(
            maxWidth: 220,
            maxHeight: 260,
            minWidth: 120,
            minHeight: 80,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              fullUrl,
              fit: BoxFit.cover,
              width: 220,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 160,
                  width: 220,
                  color: Theme.of(context).colorScheme.surface,
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
                debugPrint('❌ Image failed to load: $fullUrl — $error');
                return Container(
                  height: 160,
                  width: 220,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image,
                          size: 40,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4)),
                      const SizedBox(height: 6),
                      Text(
                        'Image unavailable',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    if (allUrls.length == 1) {
      return singleImage(allUrls.first);
    }

    // Multiple images — show in a wrap grid
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: allUrls.map((url) => singleImage(url)).toList(),
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
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.reply,
                  color: Theme.of(context).colorScheme.primary),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReply(message);
              },
            ),
            if (messageText.isNotEmpty)
              ListTile(
                leading: Icon(Icons.copy,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5)),
                title: const Text('Copy Text'),
                onTap: () {
                  Navigator.pop(context);
                  onCopy(messageText);
                },
              ),
            if ((messageType == 'image' || messageType == 'image_with_caption') && mediaUrl != null)
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