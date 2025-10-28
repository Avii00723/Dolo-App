# WebSocket Integration Guide

## Overview
This guide explains how the WebSocket functionality has been integrated into the Dolo Flutter app for real-time chat features, particularly the typing indicator.

## Architecture

### Backend (Node.js + Socket.IO)
Your backend server at `Dolo-server/src/socket/chatSocket.js` handles:
- WebSocket connections
- Room management (joinRoom)
- Message broadcasting (sendMessage → receiveMessage)
- Typing indicators (typing → userTyping)

### Frontend (Flutter + socket_io_client)
The Flutter app now includes:
- **SocketService** ([lib/Controllers/SocketService.dart](lib/Controllers/SocketService.dart)) - Singleton service managing WebSocket connections
- **Updated ChatScreen** ([lib/screens/Inbox Section/ChatScreen.dart](lib/screens/Inbox Section/ChatScreen.dart)) - Integrated typing indicators

## How It Works

### 1. Connection Flow

```
App Launch → SocketService.connect() → WebSocket handshake → Connected
                                                            ↓
                                     User opens ChatScreen → joinRoom(chatId)
```

### 2. Typing Indicator Flow

**User A types:**
```
User A types → _onTextChanged() → debounce (500ms) → emit('typing', chatId)
                                                              ↓
                                     Backend receives → broadcast to room
                                                              ↓
                           User B receives 'userTyping' event → Show "User A is typing"
                                                              ↓
                                          Auto-hide after 3 seconds
```

### 3. Message Flow (WebSocket + HTTP)

**Current Implementation:**
- Messages are sent via HTTP API (`ChatService.sendMessage`)
- Messages are received via polling (every 5 seconds)
- WebSocket listens for `receiveMessage` events to trigger immediate refresh

**Why hybrid?**
- HTTP ensures message persistence and reliability
- WebSocket provides instant notifications
- Best of both worlds: reliability + speed

## Code Structure

### SocketService.dart
```dart
class SocketService {
  // Singleton pattern for single WebSocket connection
  static SocketService? _instance;

  // Main methods:
  - connect()                    // Initialize connection
  - joinRoom(chatId)             // Join chat room
  - leaveRoom()                  // Leave current room
  - sendTypingIndicator(chatId)  // Send typing event
  - onUserTyping(callback)       // Listen for typing
  - onReceiveMessage(callback)   // Listen for messages
  - disconnect()                 // Cleanup
}
```

### ChatScreen.dart Changes

**Added:**
- `SocketService _socketService` - WebSocket service instance
- `bool _isOtherUserTyping` - Typing indicator state
- `Timer? _typingTimer` - Debounce timer for sending typing events
- `Timer? _typingIndicatorTimer` - Auto-hide timer for received typing indicators

**New Methods:**
- `_initializeWebSocket()` - Connect and setup listeners
- `_onTextChanged()` - Send typing indicator with debounce
- `_buildTypingIndicator()` - UI for "User is typing..."
- `_buildDot(delay)` - Animated dots for typing indicator

## Configuration

### Backend URL
The WebSocket connects to the same base URL as your HTTP API, defined in [lib/config/api_constants.dart](lib/config/api_constants.dart):

```dart
// Example:
static const String baseUrl = 'http://your-server-url:3000/api';
// SocketService automatically removes '/api' to connect to root
// WebSocket URL: ws://your-server-url:3000
```

### Update Your Server URL
Before testing, update `ApiConstants.baseUrl` in [lib/config/api_constants.dart](lib/config/api_constants.dart):

```dart
class ApiConstants {
  static const String baseUrl = 'http://YOUR_SERVER_IP:3000/api';
  // For local testing:
  // - Android emulator: http://10.0.2.2:3000/api
  // - iOS simulator: http://localhost:3000/api
  // - Real device: http://YOUR_COMPUTER_IP:3000/api
}
```

## Features Implemented

### ✅ Real-time Typing Indicators
- Debounced sending (only sends every 500ms while typing)
- Auto-hide after 3 seconds of inactivity
- Smooth animated dots
- Shows other user's name

### ✅ Real-time Message Notifications
- WebSocket listener triggers immediate message refresh
- No need to wait for 5-second polling

### ✅ Connection Management
- Automatic reconnection on disconnect
- Proper cleanup when leaving chat
- Single persistent connection across app

## Testing

### 1. Start Your Backend
```bash
cd Dolo-server
npm install
npm start
# Server should start on http://localhost:3000
```

### 2. Update Flutter App Configuration
Update `ApiConstants.baseUrl` in your Flutter app to point to your server.

### 3. Test Typing Indicators

**Setup:**
- Open two devices/emulators with the same chat
- Or use one device + browser with a Socket.IO test client

**Test:**
1. Device A: Start typing in message field
2. Device B: Should see "User is typing..." within 500ms
3. Device A: Stop typing
4. Device B: Typing indicator disappears after 3 seconds

### 4. Check Logs

**Flutter Console:**
```
🔌 Connecting to WebSocket at: http://your-server:3000
✅ WebSocket connected successfully
   Socket ID: abc123...
📥 Joined chat room: chatId123
⌨️  Typing indicator sent for room: chatId123
⌨️  User typing received: {userId: xyz789}
```

**Backend Console:**
```
User connected: abc123
User abc123 joined room chatId123
```

## Troubleshooting

### WebSocket Not Connecting

**Check 1: Server is running**
```bash
curl http://YOUR_SERVER_IP:3000
# Should return: "Dolo server is running"
```

**Check 2: Firewall/Network**
- Make sure port 3000 is accessible
- For real devices, computer and phone must be on same WiFi
- Check firewall settings

**Check 3: CORS Configuration**
Your backend has CORS enabled for all origins (`origin: '*'`), which should work.

### Typing Indicator Not Showing

**Check 1: Are both users in the same room?**
- Check Flutter logs for "Joined chat room: ..."
- Both users must have the same `chatId`

**Check 2: Is the userId different?**
```dart
// In SocketService.onUserTyping, we filter out own typing:
if (typingUserId != null && typingUserId != _currentUserId) {
  // Show typing indicator
}
```

**Check 3: Backend implementation**
Verify your backend `chatSocket.js` is emitting to the room:
```javascript
socket.to(roomId).emit('userTyping', { userId: socket.id });
// NOT socket.emit() - that only sends to sender
```

### Connection Drops

**Reason:** Socket.IO handles reconnection automatically with these settings:
```dart
.enableReconnection()
.setReconnectionAttempts(5)
.setReconnectionDelay(2000)
```

If connection drops frequently:
- Check network stability
- Increase reconnection attempts
- Add reconnection listeners in SocketService

## Future Enhancements

### 1. Optimize Message Sending
Instead of HTTP + WebSocket polling, send messages directly via WebSocket:

```dart
// In _sendMessage():
_socketService.sendMessage(
  chatId: widget.chatId,
  senderId: _currentUserId!,
  receiverId: otherUserId,
  message: message,
);
```

### 2. Online Status
Add user presence tracking:
```dart
// In SocketService:
socket.on('userOnline', (data) {
  // Update UI to show user is online
});

socket.on('userOffline', (data) {
  // Update UI to show user is offline
});
```

### 3. Message Seen Status
Use WebSocket for instant seen receipts instead of polling.

### 4. File Upload Progress
Use WebSocket to show real-time upload progress for images.

## Backend Requirements

Your Node.js backend must emit events in this format:

### Typing Event
```javascript
// ✅ UPDATED: When receiving 'typing' with roomId and userId
socket.on('typing', (data) => {
  const { roomId, userId } = data;

  // Broadcast to room (excluding sender)
  socket.to(roomId).emit('userTyping', {
    userId: userId,  // The actual user ID who is typing
    roomId: roomId
  });

  console.log(`User ${userId} is typing in room ${roomId}`);
});
```

**OLD FORMAT (Don't use):**
```javascript
// ❌ OLD - This won't work properly
socket.on('typing', (roomId) => {
  socket.to(roomId).emit('userTyping', {
    userId: socket.id  // Socket ID is not the same as user ID
  });
});
```

### Message Event
```javascript
// When receiving 'sendMessage'
socket.on('sendMessage', async (data) => {
  const { senderId, receiverId, message, roomId } = data;

  // Save to database...

  // Emit to room
  io.to(roomId).emit('receiveMessage', {
    id: result.insertId,
    senderId,
    receiverId,
    message,
    createdAt: new Date(),
  });
});
```

## Security Considerations

### 1. Authentication
Currently, the socket connects without authentication. Consider adding:

```dart
// In SocketService.connect():
_socket = IO.io(
  baseUrl,
  IO.OptionBuilder()
    .setExtraHeaders({
      'userId': _currentUserId!,
      'Authorization': 'Bearer $token',  // Add JWT token
    })
    .build(),
);
```

### 2. Room Validation
Backend should verify users can only join rooms they have access to:

```javascript
socket.on('joinRoom', async (roomId) => {
  // Verify user has access to this chat
  const hasAccess = await checkUserAccess(socket.userId, roomId);
  if (hasAccess) {
    socket.join(roomId);
  } else {
    socket.emit('error', { message: 'Unauthorized' });
  }
});
```

## Summary

Your Flutter app now has:
- ✅ Real-time typing indicators
- ✅ Instant message notifications
- ✅ Persistent WebSocket connection
- ✅ Automatic reconnection
- ✅ Proper cleanup on disconnect

The typing indicator enhances user experience by showing when the other person is actively responding, making the chat feel more interactive and responsive!
