# Chat Notification Testing Guide

## Overview
This guide provides comprehensive testing procedures for the chat notification scenarios where "Message notification no need in the notification screen".

The requirement is: **When a user is actively viewing a chat, they should receive the message in-app via WebSocket (receiveMessage: YES) but NO push notification should be sent.**

---

## Test Scenarios

### Scenario 1: Same Chat Open
**Description:** User A and User B both have the same chat open. A sends a message.

**Expected Behavior:**
- receiveMessage via WebSocket: **YES** ✅
- Push notification: **NO** ❌

**Testing Steps:**
1. Open the app on Device A (User A logged in)
2. Open the app on Device B (User B logged in)
3. Open Chat X on both devices
4. From Device A, send a message
5. **Verify on Device B:**
   - Message appears in real-time in the chat window
   - NO push notification appears
   - Auto-refresh triggers (every 5 seconds) and loads the message

**How to Verify:**
- Check Device B's notification center - should be empty
- Check the console logs for: "📬 Received message via WebSocket"
- Check that message appears immediately in the chat list

**Console Output to Look For:**
```
📥 Joined chat room: {chatId}
📬 Received message via WebSocket: {...}
🔄 Auto-refreshing messages at {time}
```

---

### Scenario 2: Different Screen
**Description:** User B leaves Chat X and goes to the Home screen. A sends a message in Chat X.

**Expected Behavior:**
- receiveMessage via WebSocket: **NO** ❌ (User B is not listening on that room)
- Push notification: **YES** ✅

**Testing Steps:**
1. Open the app on Device B (User B logged in) and open Chat X
2. Note the chat ID and verify WebSocket connection: "📥 Joined chat room"
3. Navigate away from ChatScreen to Home screen (this triggers leaveChat)
4. Verify in console: "📤 Emitted leaveChat event - chatId: {chatId}"
5. From Device A, send a message in Chat X
6. **Verify on Device B:**
   - Push notification should appear in the notification center
   - When notification is tapped, it should navigate to Chat X
   - Message should appear in the chat list

**Console Output to Look For:**
```
📤 Left chat room: {chatId}
📩 Foreground message received: {title}
```

---

### Scenario 3: Different Chat
**Description:** User B is viewing Chat Y. A sends a message in Chat X.

**Expected Behavior:**
- Push notification: **YES** ✅ (User B is not in the chat_X room)

**Testing Steps:**
1. Open the app on Device B and open Chat Y
2. Verify WebSocket connection to Chat Y: "📥 Joined chat room: {chatY_id}"
3. From Device A, send a message in Chat X
4. **Verify on Device B:**
   - Push notification should appear
   - Should NOT receive in-app message on the Chat Y screen
   - When notification is tapped, should navigate to Chat X

**Console Output to Look For:**
```
📥 Joined chat room: {chatY_id}
📩 Foreground message received: {title} (from Chat X)
```

---

### Scenario 4: App Closed / Background
**Description:** User B closes or backgrounds the app. A sends a message.

**Expected Behavior:**
- Push notification: **YES** ✅

**Testing Steps:**

**Sub-test 4a: App Backgrounded**
1. Open Chat X on Device B
2. Press home button (app goes to background)
3. Verify in console: "📱 App paused - stopping auto-refresh"
4. From Device A, send a message
5. **Verify on Device B:**
   - Push notification appears in the notification center
   - Can be tapped to open the app and navigate to Chat X

**Sub-test 4b: App Closed**
1. Open Chat X on Device B
2. Close the app completely (swipe away from recent apps or force close)
3. From Device A, send a message
4. **Verify on Device B:**
   - Push notification appears in the notification center
   - When tapped, opens the app and navigates to Chat X

**Console Output to Look For:**
```
📱 App paused - stopping auto-refresh
(app closes - no more console output)
🖱️ Notification clicked from background: {...}
```

---

### Scenario 5: Only Receiver in Chat
**Description:** User B is viewing Chat X. User A is NOT in Chat X (hasn't opened it). A sends a message.

**Expected Behavior:**
- receiveMessage via WebSocket: **YES** ✅ (WebSocket delivers it if in room)
- Push notification: **NO** ❌ (User B is already viewing the chat)

**Testing Steps:**
1. Open the app on Device A (User A logged in) but DON'T open Chat X
2. Open Chat X on Device B and verify: "📥 Joined chat room: {chatId}"
3. From Device A, send a message (using API directly or backend console)
4. **Verify on Device B:**
   - Message appears in real-time in Chat X
   - NO push notification appears
   - Message is received via WebSocket

**Console Output to Look For:**
```
📥 Joined chat room: {chatId}
📬 Received message via WebSocket: {...}
(no push notification)
```

---

## Key Code References

### Frontend (Flutter)

**SocketService - Chat Management:**
- `joinChat(String chatId)` - Emits 'joinChat' event when entering chat
- `leaveChat()` - Emits 'leaveChat' event when leaving chat
- `onReceiveMessage()` - Listens for WebSocket messages

**ChatScreen - Lifecycle:**
```dart
// When ChatScreen is opened:
_initializeWebSocket() → _socketService.joinChat(widget.chatId)

// When ChatScreen is closed or navigated away:
// (dispose is called) → _socketService.leaveChat()

// When app is paused:
didChangeAppLifecycleState(AppLifecycleState.paused)
→ _autoRefreshTimer?.cancel()

// When app resumes:
didChangeAppLifecycleState(AppLifecycleState.resumed)
→ _loadMessages(silent: true)
→ _startAutoRefresh()
```

**DeviceTokenService - FCM:**
- Handles push notifications via Firebase Cloud Messaging
- Listens on `FirebaseMessaging.onMessage` for foreground notifications
- Listens on `FirebaseMessaging.onMessageOpenedApp` for notification clicks

---

## Backend Expectations

The backend should implement the following logic:

### When a message is sent:
1. **Check if recipient is in the chat room** (via Socket.IO rooms)
   - If YES: Emit WebSocket event `receiveMessage` to that room
   - If NO: Send push notification via FCM
2. **Check if recipient has the app open**
   - If NO (app backgrounded/closed): Send push notification
   - If YES (app in foreground): Decision depends on which room they're in

### Implementation Pattern:
```javascript
// Pseudocode for backend
if (recipient.isInChatRoom(chatId)) {
    // User is viewing this specific chat
    // Send WebSocket message only
    io.to(chatId).emit('receiveMessage', messageData);
} else {
    // User is not in this chat room
    // Send push notification via FCM
    sendPushNotification(recipient.fcmToken, messageData);
}
```

---

## Testing Checklist

### Before Testing:
- [ ] Both test devices have the app installed
- [ ] Test users are created and login credentials are ready
- [ ] Firebase Cloud Messaging is configured
- [ ] Backend notification service is running
- [ ] Device tokens are being saved to the database
- [ ] WebSocket connection is enabled

### Scenario 1 Testing:
- [ ] Message received in real-time on both devices
- [ ] No push notification on Device B
- [ ] Console shows "receiveMessage via WebSocket"
- [ ] Auto-refresh timer is active

### Scenario 2 Testing:
- [ ] After navigating away, console shows "Left chat room"
- [ ] Push notification appears in Device B's notification center
- [ ] Notification can be tapped to return to the chat

### Scenario 3 Testing:
- [ ] Push notification appears for Chat X while viewing Chat Y
- [ ] Notification can be tapped to navigate to Chat X
- [ ] Message appears in Chat X after notification is tapped

### Scenario 4a Testing:
- [ ] App backgrounded (app paused logged)
- [ ] Push notification appears in notification center
- [ ] Notification can be tapped to bring app to foreground

### Scenario 4b Testing:
- [ ] App force-closed
- [ ] Push notification appears
- [ ] Tapping notification opens the app

### Scenario 5 Testing:
- [ ] Message received in real-time in Chat X
- [ ] No push notification appears
- [ ] Sender was not in the chat room before sending

---

## Debugging Tips

### Check WebSocket Connection:
```
Look for: "✅ WebSocket connected successfully"
or: "🔌 WebSocket disconnected"
```

### Check Room Join/Leave:
```
Look for: "📥 Joined chat room: {chatId}"
Look for: "📤 Left chat room: {chatId}"
```

### Check Message Reception:
```
Foreground: "📬 Received message via WebSocket: {data}"
Background: "📩 Foreground message received: {title}"
Clicked: "🖱️ Notification clicked from background: {data}"
```

### Common Issues:

**Issue: Push notification appears when both users have chat open**
- Check: Is `leaveChat()` being called when ChatScreen closes?
- Check: Is the backend properly checking room membership?
- Check: Are device tokens up-to-date?

**Issue: No message received when chat is open**
- Check: Is `joinChat()` being called in `_initializeWebSocket()`?
- Check: Is WebSocket connected? Look for "✅ WebSocket connected"
- Check: Is the message actually being sent?

**Issue: Push notification not appearing when app is backgrounded**
- Check: Is device token being saved to the server?
- Check: Is FCM properly configured in Firebase Console?
- Check: Check Firebase Cloud Messaging logs

---

## Success Criteria

✅ All 5 scenarios pass their expected behavior
✅ No unintended push notifications are sent
✅ Messages are received in real-time when user is viewing the chat
✅ App lifecycle changes are properly tracked
✅ Device tokens are current and valid
✅ WebSocket connections are properly managed

---

## Related Files

- **ChatScreen:** `lib/screens/Inbox Section/ChatScreen.dart`
- **SocketService:** `lib/Controllers/SocketService.dart`
- **DeviceTokenService:** `lib/Controllers/DeviceTokenService.dart`
- **NotificationService:** `lib/Controllers/NotificationService.dart`
- **ChatService:** `lib/Controllers/ChatService.dart`

