import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../Constants/ApiConstants.dart';
import 'AuthService.dart';

class SocketService {
  static SocketService? _instance;
  IO.Socket? _socket;
  String? _currentUserId;
  String? _currentChatId;
  int _connectionRefCount = 0;
  Future<void>? _connectingFuture;
  final StreamController<Map<String, dynamic>> _messageStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _typingStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  bool _isReceiveMessageBound = false;
  bool _isUserTypingBound = false;

  factory SocketService() {
    _instance ??= SocketService._internal();
    return _instance!;
  }

  SocketService._internal();

  IO.Socket? get socket => _socket;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    _connectionRefCount++;
    debugPrint('Socket connection requested (ref count: $_connectionRefCount)');

    if (isConnected) {
      debugPrint('Socket already connected');
      return;
    }

    if (_connectingFuture != null) {
      await _connectingFuture;
      return;
    }

    _connectingFuture = _connectSocket();
    try {
      await _connectingFuture;
    } finally {
      _connectingFuture = null;
    }
  }

  Future<void> _connectSocket() async {
    if (_socket != null) {
      debugPrint('Socket exists but is not connected, reconnecting...');
      _socket!.connect();
      await _waitUntilConnected();
      return;
    }

    try {
      _currentUserId = await AuthService.getUserId();

      if (_currentUserId == null) {
        debugPrint('Cannot connect socket: user not authenticated');
        _connectionRefCount--;
        return;
      }

      final baseUrl = ApiConstants.baseUrl.replaceAll('/api', '');
      debugPrint('Connecting to WebSocket at: $baseUrl');

      _socket = IO.io(
        baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(2000)
            .setExtraHeaders({'userId': _currentUserId!})
            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('WebSocket connected successfully');
        debugPrint('Socket ID: ${_socket!.id}');
        final chatId = _currentChatId;
        if (chatId != null) {
          _emitJoinChat(chatId);
        }
      });

      _socket!.onConnectError((error) {
        debugPrint('WebSocket connection error: $error');
      });

      _socket!.onDisconnect((_) {
        debugPrint('WebSocket disconnected');
      });

      _socket!.onError((error) {
        debugPrint('WebSocket error: $error');
      });

      _socket!.connect();
      await _waitUntilConnected();
    } catch (e) {
      debugPrint('Error initializing WebSocket: $e');
      _connectionRefCount--;
    }
  }

  Future<void> _waitUntilConnected({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!isConnected && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void joinChat(String chatId) {
    if (_currentChatId != null && _currentChatId != chatId) {
      leaveChat(_currentChatId);
    }

    _currentChatId = chatId;

    if (!isConnected) {
      debugPrint('Chat join pending until socket connects - chatId: $chatId');
      return;
    }

    _emitJoinChat(chatId);
  }

  void _emitJoinChat(String chatId) {
    final data = {
      'chatId': chatId,
      'userId': _currentUserId,
    };
    _socket!.emit('joinChat', data);
    debugPrint(
        'Emitted joinChat event - chatId: $chatId, userId: $_currentUserId');
  }

  void leaveChat([String? chatId]) {
    final chatIdToLeave = chatId ?? _currentChatId;

    if (chatIdToLeave != null && isConnected) {
      final data = {
        'chatId': chatIdToLeave,
        'userId': _currentUserId,
      };
      _socket!.emit('leaveChat', data);
      debugPrint(
        'Emitted leaveChat event - chatId: $chatIdToLeave, userId: $_currentUserId',
      );
    }

    if (chatIdToLeave == _currentChatId) {
      _currentChatId = null;
    }
  }

  void joinRoom(String chatId) {
    debugPrint('joinRoom is deprecated, use joinChat instead');
    joinChat(chatId);
  }

  void leaveRoom() {
    debugPrint('leaveRoom is deprecated, use leaveChat instead');
    leaveChat();
  }

  void sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String message,
  }) {
    if (!isConnected) {
      debugPrint('Cannot send message: socket not connected');
      return;
    }

    final data = {
      'roomId': chatId,
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
    };

    _socket!.emit('sendMessage', data);
    debugPrint('Message sent via WebSocket to room $chatId');
  }

  StreamSubscription<Map<String, dynamic>> onReceiveMessage(
    void Function(Map<String, dynamic>) callback,
  ) {
    if (_socket == null) {
      debugPrint('Cannot listen for messages: socket not initialized');
      return const Stream<Map<String, dynamic>>.empty().listen(callback);
    }

    if (!_isReceiveMessageBound) {
      _socket!.on('receiveMessage', (data) {
        debugPrint('Message received via WebSocket: $data');
        if (data is Map<String, dynamic>) {
          _messageStreamController.add(data);
        } else if (data is Map) {
          _messageStreamController.add(Map<String, dynamic>.from(data));
        }
      });
      _isReceiveMessageBound = true;
    }

    return _messageStreamController.stream.listen(callback);
  }

  StreamSubscription<Map<String, dynamic>> onUserTyping(
    void Function(Map<String, dynamic>) callback,
  ) {
    if (_socket == null) {
      debugPrint('Cannot listen for typing: socket not initialized');
      return const Stream<Map<String, dynamic>>.empty().listen(callback);
    }

    if (!_isUserTypingBound) {
      _socket!.on('userTyping', (data) {
        debugPrint('User typing received: $data');
        if (data is Map<String, dynamic>) {
          _typingStreamController.add(data);
        } else if (data is Map) {
          _typingStreamController.add(Map<String, dynamic>.from(data));
        }
      });
      _isUserTypingBound = true;
    }

    return _typingStreamController.stream.listen(callback);
  }

  void _clearSocketListenerBinding(String event) {
    if (event == 'receiveMessage') {
      _isReceiveMessageBound = false;
    } else if (event == 'userTyping') {
      _isUserTypingBound = false;
    }
  }

  void off(String event) {
    _socket?.off(event);
    _clearSocketListenerBinding(event);
  }

  void sendTypingIndicator(String chatId) {
    if (!isConnected) {
      return;
    }

    final data = {
      'roomId': chatId,
      'userId': _currentUserId,
    };

    _socket!.emit('typing', data);
    debugPrint(
        'Typing indicator sent for room: $chatId, userId: $_currentUserId');
  }

  void releaseConnection() {
    if (_connectionRefCount > 0) {
      _connectionRefCount--;
    }

    debugPrint('Socket connection released (ref count: $_connectionRefCount)');

    if (_connectionRefCount == 0) {
      disconnect();
    }
  }

  void disconnect() {
    if (_socket != null) {
      leaveChat();
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _connectingFuture = null;
      _isReceiveMessageBound = false;
      _isUserTypingBound = false;
      _connectionRefCount = 0;
      debugPrint('WebSocket disconnected and disposed');
    }
  }

  void dispose() {
    disconnect();
    _messageStreamController.close();
    _typingStreamController.close();
    _instance = null;
  }
}
