import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import '../Constants/ApiConstants.dart';
import 'AuthService.dart';

class SocketService {
  static SocketService? _instance;
  IO.Socket? _socket;
  String? _currentUserId;
  String? _currentChatId;

  // Singleton pattern
  factory SocketService() {
    _instance ??= SocketService._internal();
    return _instance!;
  }

  SocketService._internal();

  // Get socket instance
  IO.Socket? get socket => _socket;

  // Check if connected
  bool get isConnected => _socket?.connected ?? false;

  // Initialize and connect to WebSocket server
  Future<void> connect() async {
    if (_socket != null && _socket!.connected) {
      debugPrint('✅ Socket already connected');
      return;
    }

    try {
      // Get current user ID
      _currentUserId = await AuthService.getUserId();

      if (_currentUserId == null) {
        debugPrint('❌ Cannot connect socket: User not authenticated');
        return;
      }

      // Extract base URL from API (remove /api path)
      final baseUrl = ApiConstants.baseUrl.replaceAll('/api', '');

      debugPrint('🔌 Connecting to WebSocket at: $baseUrl');

      _socket = IO.io(
        baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket']) // Use WebSocket transport
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(2000)
            .setExtraHeaders({'userId': _currentUserId!}) // Optional: send userId in header
            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('✅ WebSocket connected successfully');
        debugPrint('   Socket ID: ${_socket!.id}');
      });

      _socket!.onConnectError((error) {
        debugPrint('❌ WebSocket connection error: $error');
      });

      _socket!.onDisconnect((_) {
        debugPrint('🔌 WebSocket disconnected');
      });

      _socket!.onError((error) {
        debugPrint('❌ WebSocket error: $error');
      });

      _socket!.connect();
    } catch (e) {
      debugPrint('❌ Error initializing WebSocket: $e');
    }
  }

  // Join a chat room
  void joinRoom(String chatId) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('❌ Cannot join room: Socket not connected');
      return;
    }

    _currentChatId = chatId;
    _socket!.emit('joinRoom', chatId);
    debugPrint('📥 Joined chat room: $chatId');
  }

  // Leave current room
  void leaveRoom() {
    if (_currentChatId != null && _socket != null && _socket!.connected) {
      _socket!.emit('leaveRoom', _currentChatId);
      debugPrint('📤 Left chat room: $_currentChatId');
      _currentChatId = null;
    }
  }

  // Send a message through WebSocket
  void sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String message,
  }) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('❌ Cannot send message: Socket not connected');
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
    debugPrint('📨 Message sent via WebSocket to room $chatId');
  }

  // Listen for incoming messages
  void onReceiveMessage(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      debugPrint('❌ Cannot listen for messages: Socket not initialized');
      return;
    }

    _socket!.on('receiveMessage', (data) {
      debugPrint('📬 Message received via WebSocket: $data');
      if (data is Map<String, dynamic>) {
        callback(data);
      }
    });
  }

  // Send typing indicator
  void sendTypingIndicator(String chatId) {
    if (_socket == null || !_socket!.connected) {
      return;
    }

    _socket!.emit('typing', chatId);
    debugPrint('⌨️  Typing indicator sent for room: $chatId');
  }

  // Listen for typing indicators
  void onUserTyping(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      debugPrint('❌ Cannot listen for typing: Socket not initialized');
      return;
    }

    _socket!.on('userTyping', (data) {
      debugPrint('⌨️  User typing received: $data');
      if (data is Map<String, dynamic>) {
        callback(data);
      }
    });
  }

  // Remove specific event listener
  void off(String event) {
    _socket?.off(event);
  }

  // Disconnect from WebSocket
  void disconnect() {
    if (_socket != null) {
      leaveRoom();
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      debugPrint('🔌 WebSocket disconnected and disposed');
    }
  }

  // Dispose (for cleanup)
  void dispose() {
    disconnect();
    _instance = null;
  }
}
