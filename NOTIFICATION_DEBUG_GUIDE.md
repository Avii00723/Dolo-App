# Chat Notification Debugging & Monitoring Guide

## Quick Reference: Expected vs Unexpected Behavior

### ✅ EXPECTED BEHAVIORS

#### When Message is Received in Active Chat:
```
✅ Console shows: "📬 Received message via WebSocket: {...}"
✅ Message appears instantly in chat
✅ Message list auto-updates
✅ NO push notification in notification center
```

#### When Message is Received Away from Chat:
```
✅ Console shows: "📤 Left chat room: {chatId}"
✅ Push notification appears in notification center
✅ Notification title: "New message from [User]"
✅ Tapping notification navigates to chat
```

#### When App is Backgrounded:
```
✅ Console shows: "📱 App paused - stopping auto-refresh"
✅ Push notification appears
✅ Auto-refresh timer is cancelled
✅ Notification remains in center (persistent)
```

---

## Console Log Analysis

### Chart 1: WebSocket Connection Flow

```
📱 App Started
  ↓
✅ WebSocket connected successfully
  ↓
📥 Joined chat room: chat_123
  ↓
(App is now listening for messages)
```

### Chart 2: Message Received While in Chat

```
Device A sends message
  ↓
Backend saves to database
  ↓
Backend checks: Is User B in room chat_123?
  ├─ YES → Emit "receiveMessage" via WebSocket
  │         📬 Message received on Device B
  │         ✅ Appears instantly in UI
  │         ❌ NO push notification
  │
  └─ NO → Send push notification via FCM
          📩 Notification appears in center
          🖱️ User taps it to navigate to chat
```

### Chart 3: Message Received While Away from Chat

```
Device B navigates away from chat
  ↓
📤 Emitted leaveChat event - chatId: chat_123
  ↓
Device A sends message
  ↓
Backend checks: Is User B in room chat_123?
  ├─ NO → Send push notification via FCM
         📩 Notification in center
         🖱️ User taps to navigate and read message
```

---

## Log Output Reference

### Initialization Logs (App Start)

**GOOD:**
```
✅ FCM listeners initialized
📱 Current FCM Token: AIzaSyD...xK9xE_K
📤 Attempting to save device token for userId: user_123
✅ Device token saved successfully for user user_123
🔌 Connecting to WebSocket at: http://api.example.com
✅ WebSocket connected successfully
   Socket ID: yfZQJ...dGAB
```

**BAD:**
```
❌ Notification permissions denied
⚠️ Cannot save device token: No userId found
❌ Error initializing FCM: ...
🔌 WebSocket disconnected
```

### Chat Screen Lifecycle Logs

**Opening Chat (GOOD):**
```
🔐 Current User ID: user_456
📥 Emitted joinChat event - chatId: chat_789, userId: user_456
✅ WebSocket initialized and listening
🔄 Auto-refresh timer started (every 5 seconds)
✅ Loaded 12 messages from API
📊 Unseen messages: 2
```

**Leaving Chat (GOOD):**
```
📤 Emitted leaveChat event - chatId: chat_789
📱 App paused - stopping auto-refresh
```

**Message Reception (GOOD):**
```
📬 Received message via WebSocket: {
  "id": 1,
  "chat_id": 789,
  "sender_id": "user_123",
  "message": "Hello there!",
  "created_at": "2025-06-09T10:30:00Z"
}
🔄 Auto-refreshing messages at 2025-06-09 10:30:05
```

### Notification Logs

**Push Notification Received (Foreground):**
```
📩 Foreground message received: {
  "notification": {
    "title": "New message from John",
    "body": "Hello, how are you?"
  },
  "data": {
    "chat_id": "789",
    "order_id": "456",
    "sender_name": "John"
  }
}
🔔 NotificationsScreen: FCM message received, refreshing...
```

**Notification Tapped (Background):**
```
🖱️ Notification clicked from background: {
  "data": {
    "chat_id": "789",
    "order_id": "456"
  }
}
(App launches and navigates to chat)
```

---

## Monitoring Checklist During Testing

### Before Test Execution:

- [ ] **Console cleared:** Browser DevTools > Console > Clear
- [ ] **Network tab open:** Browser DevTools > Network
- [ ] **Device logs accessible:** Connect to computer via USB
- [ ] **Firebase Console open:** In another browser tab
- [ ] **Backend logs visible:** SSH into server or dashboard

### During Test Execution:

**Watch For:**
- [ ] WebSocket connection status (should show "connected")
- [ ] Room join/leave events (📥 / 📤)
- [ ] Message send/receive events (📤 / 📬)
- [ ] FCM token validity
- [ ] Network requests completing successfully (200 status)

**Check Every Message:**
- [ ] Is sender ID different from receiver ID?
- [ ] Is timestamp recent (within last minute)?
- [ ] Are images/attachments loading?
- [ ] Is the message order correct (newest first)?

### After Each Scenario:

- [ ] Note any error messages
- [ ] Screenshot notification center state
- [ ] Copy relevant console logs
- [ ] Document unexpected behavior

---

## Common Issues & Solutions

### Issue: Message Not Received in Real-Time

**Symptoms:**
- Message doesn't appear in chat window
- Have to manually refresh to see message
- Console shows no "receiveMessage" event

**Diagnostics:**
```
Check 1: Is WebSocket connected?
  Look for: "✅ WebSocket connected successfully"
  If missing: WebSocket connection failed

Check 2: Is user in the correct room?
  Look for: "📥 Joined chat room: {correct_chat_id}"
  If missing: User not joined to room

Check 3: Did the message send?
  Look for: "✅ Message sent successfully"
  If missing: Message didn't send from sender

Check 4: Is auto-refresh active?
  Look for: "🔄 Auto-refresh timer started"
  If missing: Auto-refresh not running
```

**Solutions:**
1. Verify WebSocket server is running
2. Restart the app to rejoin room
3. Check that chat ID is correct
4. Verify message was sent from Device A

---

### Issue: Push Notification Appearing When Not Expected

**Symptoms:**
- Notification appears even though user is viewing chat
- Notification appears for a different chat than expected
- Multiple duplicate notifications

**Diagnostics:**
```
Check 1: Did user actually leave the room?
  Look for: "📤 Left chat room: {chat_id}"
  If missing: User still in room, why is notification being sent?

Check 2: Is device token correct?
  In Firebase Console: Check if user has valid token
  If expired: Token needs to be refreshed

Check 3: Is backend checking room membership?
  Backend logs: Should show "User in room, not sending FCM"
  If not: Backend not checking properly
```

**Solutions:**
1. Clear app cache and restart
2. Re-register for push notifications
3. Check backend logic for room membership checks
4. Verify Firebase token is valid

---

### Issue: No Push Notification When App Closed

**Symptoms:**
- App is closed, message sent, but no notification appears
- Notification only appears when app is open

**Diagnostics:**
```
Check 1: Is app actually closed?
  On iOS: Check Settings > General > Background App Refresh
  On Android: Check if app is in recent apps
  
Check 2: Is device token saved?
  Backend database: Verify userId has a valid FCM token
  If not: Device token wasn't registered

Check 3: Is Firebase configured?
  Android: Check google-services.json is correct
  iOS: Check GoogleService-Info.plist is correct
  
Check 4: Is notification permission granted?
  Settings > Apps > Dolo > Notifications > ON
```

**Solutions:**
1. Ensure app is fully closed (not just backgrounded)
2. Check device token is saved in database
3. Manually resave device token:
   - Go to Settings and toggle notifications off/on
   - Or restart the app
4. Verify Firebase Console shows the device

---

### Issue: App Crashes When Receiving Notification

**Symptoms:**
- App crashes when background notification arrives
- Stack trace appears in console
- App force closes

**Diagnostics:**
```
Check 1: What's the stack trace?
  Look at console error output
  Search for: NullPointerException, IndexOutOfBoundsException
  
Check 2: Is the notification data malformed?
  Check Firebase Console notification payload
  Verify all required fields are present
  
Check 3: Is there a race condition?
  Check if multiple notifications arrive at once
  Check if app state is unstable
```

**Solutions:**
1. Add null-safety checks in notification handler
2. Validate notification data structure
3. Add error handling for malformed data
4. Use try-catch blocks around notification processing

---

## Performance Monitoring

### Key Metrics to Track:

| Metric | Target | How to Measure |
|--------|--------|---|
| Message Latency | < 1 second | Time from send to appear in chat |
| Notification Delivery | < 5 seconds | Time from message to notification appears |
| WebSocket Reconnection | < 10 seconds | Time to reconnect after disconnect |
| App Resume Time | < 3 seconds | Time from notification tap to chat open |
| Device Token Refresh | < 2 minutes | Time from logout to new token saved |

### How to Measure Message Latency:

1. Open Chat on both devices
2. Note exact time: HH:MM:SS
3. Send message from Device A
4. Measure time when message appears on Device B
5. Calculate: Appearance Time - Send Time = Latency

**Example:**
```
Sent: 10:30:45
Appeared: 10:30:46
Latency: 1 second ✅
```

---

## Firebase Console Monitoring

### What to Check:

1. **Device Tokens:**
   - Analytics > Users
   - Should show both test user IDs
   - Check "Last Activity" is recent

2. **Push Notifications:**
   - Messaging > All messages
   - Should show notification history
   - Check "Delivery Status" for each user

3. **Cloud Messaging:**
   - Click on recent notification
   - Check "Sent to" count
   - Verify targeting is correct

4. **Errors:**
   - Alerts > Error Reporting
   - Should be minimal during testing
   - Investigate any new errors

---

## Logcat Command Examples (Android)

### View FCM Messages:
```bash
adb logcat | grep -i "fcm\|firebase\|messaging"
```

### View All App Logs:
```bash
adb logcat | grep "dolo"
```

### View WebSocket Events:
```bash
adb logcat | grep -i "socket\|websocket\|io"
```

### Clear Log Before Test:
```bash
adb logcat -c
```

### Save Logs to File:
```bash
adb logcat > logcat_output.txt
```

---

## Success Indicators

### ✅ Testing Complete When:
- [ ] All 5 scenarios pass their expected behavior
- [ ] No unexpected push notifications sent
- [ ] Message latency is < 1 second when in active chat
- [ ] Notification delivery is < 5 seconds when away from chat
- [ ] App doesn't crash during any scenario
- [ ] Device tokens are properly managed
- [ ] WebSocket connections are stable
- [ ] No memory leaks or high CPU usage

### 📋 Required Documentation:
- [ ] Test date and time recorded
- [ ] Console logs captured for each scenario
- [ ] Screenshots of notification center (for each scenario)
- [ ] Any errors or issues logged
- [ ] Explanation for any failures

---

## Quick Debugging Commands

### Reset All Notification State:
```
1. Clear App Cache:
   Settings > Apps > Dolo > Storage > Clear Cache
   
2. Clear Notifications:
   Long-press notification > Clear all notifications
   
3. Re-register for Notifications:
   Settings > Apps > Dolo > Notifications > Toggle Off/On
   
4. Restart App:
   Close and reopen the app
```

### Test Push Notification Manually:
1. Go to Firebase Console > Messaging
2. Create a new campaign
3. Select your test user as target
4. Send test notification
5. Check if it appears on device

### Force WebSocket Reconnection:
```
Debug Steps:
1. Close the chat screen
2. Open a different chat
3. Close that chat
4. Reopen original chat
5. Check console for new connection logs
```

---

## Need Help?

### Where to Find Logs:

**iOS:**
- Xcode > Window > Devices and Simulators > Console

**Android:**
- Android Studio > Logcat
- Or command: `adb logcat`

**Backend:**
- SSH into server
- Check `/var/log/app/` directory
- Or check application logs dashboard

### Key Files to Check:

**Frontend:**
- [ChatScreen.dart](lib/screens/Inbox%20Section/ChatScreen.dart) - Main chat UI
- [SocketService.dart](lib/Controllers/SocketService.dart) - WebSocket handling
- [DeviceTokenService.dart](lib/Controllers/DeviceTokenService.dart) - FCM setup
- [NotificationService.dart](lib/Controllers/NotificationService.dart) - Notifications UI

**Backend:**
- Chat message handler (saves messages, emits WebSocket events, sends FCM)
- Socket.IO room management (tracks which user is in which room)
- FCM service (sends push notifications)

