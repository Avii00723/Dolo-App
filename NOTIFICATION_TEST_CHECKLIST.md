# Chat Notification Test Verification Checklist

Date: ________________  
Tester: ________________  
Build Version: ________________

---

## Test Environment Setup

### Device A (Sender - User A)
- [ ] Device OS: Android / iOS
- [ ] App Installed and Running
- [ ] User Logged In: ________________
- [ ] Internet Connection: WiFi / Mobile Data
- [ ] Firebase Configured

### Device B (Receiver - User B)
- [ ] Device OS: Android / iOS
- [ ] App Installed and Running
- [ ] User Logged In: ________________
- [ ] Internet Connection: WiFi / Mobile Data
- [ ] Firebase Configured
- [ ] Notifications Enabled in Settings

### Backend
- [ ] WebSocket Server Running: http://__________ (URL)
- [ ] Firebase Cloud Messaging Configured
- [ ] Device Token Endpoints Working
- [ ] Notification Service Active

---

## Scenario 1: Same Chat Open

**Test Date:** __________  
**Test Time:** __________  
**Chat ID Used:** __________

### Prerequisites:
- [ ] Open Chat on Device A (User A)
- [ ] Open Same Chat on Device B (User B)
- [ ] Both users can see the chat history
- [ ] WebSocket connected on both devices (check console)

### Execution:
1. [ ] From Device A, send message: "_________________________"
2. [ ] On Device B, watch for:
   - [ ] Message appears instantly in chat window
   - [ ] Timestamp shows current time
   - [ ] Message shows as from User A

### Verification:
- [ ] ✅ receiveMessage via WebSocket: **RECEIVED** / **NOT RECEIVED**
- [ ] ❌ Push Notification: **APPEARED** (FAIL!) / **DID NOT APPEAR** (PASS!)
  
**Console Log Confirmation (Device B):**
```
Copy-paste relevant console output:
________________________________
________________________________
________________________________
```

### Result: 
- [ ] **PASS** - Message received, no push notification
- [ ] **FAIL** - Push notification appeared
- [ ] **INCONCLUSIVE** - Device issue

### Notes:
________________________________

---

## Scenario 2: Different Screen

**Test Date:** __________  
**Test Time:** __________  
**Chat ID Used:** __________

### Prerequisites:
- [ ] Have Device B open Chat X and joined room
- [ ] Verify console shows: "📥 Joined chat room: {chatId}"

### Execution:
1. [ ] On Device B, navigate AWAY from ChatScreen (go to Home/Inbox)
2. [ ] Verify console shows: "📤 Left chat room: {chatId}"
3. [ ] Confirm Device B is NOW on Home screen (not viewing chat)
4. [ ] From Device A, send message: "_________________________"
5. [ ] On Device B, watch for:
   - [ ] Push notification in notification center
   - [ ] Notification title and body are correct

### Verification:
- [ ] ✅ receiveMessage: **NOT RECEIVED** (expected, user not in room)
- [ ] ✅ Push Notification: **APPEARED** / **DID NOT APPEAR** (FAIL!)

**Console Log Confirmation (Device B):**
```
Copy-paste "Left chat room" output:
________________________________

Copy-paste FCM notification received:
________________________________
```

### Notification Details:
- [ ] Title: _________________________
- [ ] Body: _________________________
- [ ] Can tap notification to navigate to chat: YES / NO

### Result:
- [ ] **PASS** - Push notification appeared
- [ ] **FAIL** - No push notification appeared
- [ ] **INCONCLUSIVE** - Device issue

### Notes:
________________________________

---

## Scenario 3: Different Chat

**Test Date:** __________  
**Test Time:** __________  
**Receiver Viewing Chat ID:** __________  
**Message Sent in Chat ID:** __________

### Prerequisites:
- [ ] Device B has Chat Y open
- [ ] Verify console shows: "📥 Joined chat room: {Chat Y ID}"
- [ ] Device A will send message to Chat X (different from Chat Y)

### Execution:
1. [ ] Confirm Device B is viewing Chat Y
2. [ ] From Device A, send message to Chat X: "_________________________"
3. [ ] On Device B, watch for:
   - [ ] Push notification appears (from Chat X)
   - [ ] Chat Y screen does NOT update with new message
   - [ ] Notification shows sender info from Chat X

### Verification:
- [ ] ✅ Push Notification: **APPEARED** / **DID NOT APPEAR** (FAIL!)
- [ ] ❌ In-app message in Chat Y: **APPEARED** (FAIL!) / **DID NOT APPEAR** (PASS!)

**Console Log Confirmation (Device B):**
```
Still shows Chat Y room:
________________________________

FCM notification received from Chat X:
________________________________
```

### Notification Details:
- [ ] Notification is from Chat X (not Chat Y): YES / NO
- [ ] Tapping notification navigates to Chat X: YES / NO
- [ ] Message appears in Chat X after tap: YES / NO

### Result:
- [ ] **PASS** - Correct push notification sent
- [ ] **FAIL** - Wrong notification or no notification
- [ ] **INCONCLUSIVE** - Device issue

### Notes:
________________________________

---

## Scenario 4a: App Backgrounded

**Test Date:** __________  
**Test Time:** __________  
**Chat ID Used:** __________

### Prerequisites:
- [ ] Have Device B open Chat X
- [ ] Verify console shows: "📥 Joined chat room: {chatId}"

### Execution:
1. [ ] On Device B, press HOME button (app goes to background)
2. [ ] Verify in console: "📱 App paused - stopping auto-refresh"
3. [ ] Wait 5 seconds to ensure app is backgrounded
4. [ ] From Device A, send message: "_________________________"
5. [ ] On Device B, check notification center:
   - [ ] Push notification appears
   - [ ] Notification can be tapped

### Verification:
- [ ] ✅ Push Notification: **APPEARED** / **DID NOT APPEAR** (FAIL!)
- [ ] ✅ Notification is from Chat X: YES / NO

### Notification Details:
- [ ] Title: _________________________
- [ ] Body: _________________________
- [ ] When tapped, opens app: YES / NO
- [ ] When tapped, navigates to Chat X: YES / NO

### Result:
- [ ] **PASS** - Push notification appeared correctly
- [ ] **FAIL** - No notification
- [ ] **INCONCLUSIVE** - Device backgrounding issue

### Notes:
________________________________

---

## Scenario 4b: App Closed

**Test Date:** __________  
**Test Time:** __________  
**Chat ID Used:** __________

### Prerequisites:
- [ ] Have Device B open Chat X (or any chat)
- [ ] Verify WebSocket is connected

### Execution:
1. [ ] On Device B, CLOSE THE APP completely:
   - [ ] Swipe away from recent apps, OR
   - [ ] Force close from Settings
2. [ ] Wait 10 seconds
3. [ ] From Device A, send message: "_________________________"
4. [ ] On Device B, check notification center:
   - [ ] Push notification appears
   - [ ] Notification title/body are correct

### Verification:
- [ ] ✅ Push Notification: **APPEARED** / **DID NOT APPEAR** (FAIL!)
- [ ] ✅ Notification persists after app closed: YES / NO

### Notification Details:
- [ ] Title: _________________________
- [ ] Body: _________________________
- [ ] Tap notification, app launches: YES / NO
- [ ] After app launch, navigates to correct chat: YES / NO
- [ ] Message visible in chat: YES / NO

### Result:
- [ ] **PASS** - Push notification delivered and actionable
- [ ] **FAIL** - No notification or incorrect behavior
- [ ] **INCONCLUSIVE** - Device/OS issue

### Notes:
________________________________

---

## Scenario 5: Only Receiver in Chat

**Test Date:** __________  
**Test Time:** __________  
**Chat ID Used:** __________

### Prerequisites:
- [ ] Device A (User A): DO NOT open Chat X
- [ ] Device B (User B): Open Chat X and join room
- [ ] Verify console on Device B: "📥 Joined chat room: {chatId}"

### Execution:
1. [ ] Confirm Device A does NOT have Chat X open
2. [ ] Confirm Device B HAS Chat X open
3. [ ] From Device A, send message: "_________________________"
   - (May need to use API directly or backend console if User A isn't in the app)
4. [ ] On Device B, watch for:
   - [ ] Message appears in Chat X immediately
   - [ ] NO push notification appears
   - [ ] Message received via WebSocket

### Verification:
- [ ] ✅ receiveMessage via WebSocket: **RECEIVED** / **NOT RECEIVED** (FAIL!)
- [ ] ❌ Push Notification: **APPEARED** (FAIL!) / **DID NOT APPEAR** (PASS!)

**Console Log Confirmation (Device B):**
```
Copy-paste WebSocket message received:
________________________________

Copy-paste that NO push notification was received:
________________________________
```

### Result:
- [ ] **PASS** - Message received, no push notification
- [ ] **FAIL** - Push notification appeared
- [ ] **INCONCLUSIVE** - Device/sender issue

### Notes:
________________________________

---

## Overall Test Summary

| Scenario | Expected | Result | Status |
|----------|----------|--------|--------|
| 1. Same Chat Open | recMsg YES, Notif NO | ________ | ✅ / ❌ |
| 2. Different Screen | recMsg NO, Notif YES | ________ | ✅ / ❌ |
| 3. Different Chat | Notif YES | ________ | ✅ / ❌ |
| 4a. App Backgrounded | Notif YES | ________ | ✅ / ❌ |
| 4b. App Closed | Notif YES | ________ | ✅ / ❌ |
| 5. Only Receiver | recMsg YES, Notif NO | ________ | ✅ / ❌ |

### Final Result:
- [ ] **ALL PASS** - Ready to mark task as done ✅
- [ ] **SOME FAIL** - Issues found, document below

---

## Issues Found

### Issue 1:
**Scenario:** _______  
**Description:** ________________________________  
**Expected:** ________________________________  
**Actual:** ________________________________  
**Root Cause (if known):** ________________________________  

### Issue 2:
**Scenario:** _______  
**Description:** ________________________________  
**Expected:** ________________________________  
**Actual:** ________________________________  
**Root Cause (if known):** ________________________________  

---

## Additional Notes

**Browser Console Logs:**
```
________________________________
________________________________
________________________________
```

**Firebase Console Observations:**
________________________________

**Backend Logs:**
```
________________________________
________________________________
```

**Device-Specific Issues:**
- Device A: ________________________________
- Device B: ________________________________

---

## Sign-Off

- [ ] All test scenarios completed
- [ ] Results documented
- [ ] Issues logged (if any)
- [ ] Ready for code review / deployment

**Tester Signature:** ________________  
**Date Completed:** ________________  
**Next Steps:** ________________________________

