# Backend Update Required for Typing Indicators

## Problem
The current backend sends `socket.id` as the userId in typing events, but the Flutter app needs the actual user ID to identify who is typing.

## Current Backend Code (Dolo-server/src/socket/chatSocket.js)

```javascript
// ❌ OLD CODE - This won't work properly
socket.on('typing', (roomId) => {
  socket.to(roomId).emit('userTyping', { userId: socket.id });
});
```

**Issue:** `socket.id` is a random Socket.IO connection ID, not the actual user ID from your database.

## Updated Backend Code - COPY THIS

Replace the typing handler in `Dolo-server/src/socket/chatSocket.js` with:

```javascript
// ✅ UPDATED CODE - Use this instead
socket.on('typing', (data) => {
  const { roomId, userId } = data;

  // Broadcast to everyone in the room EXCEPT the sender
  socket.to(roomId).emit('userTyping', {
    userId: userId,
    roomId: roomId
  });

  console.log(`✅ User ${userId} is typing in room ${roomId}`);
});
```

## Complete Updated File

Here's the complete updated `chatSocket.js`:

```javascript
// src/socket/chatSocket.js
module.exports = (io, db) => {
  io.on('connection', (socket) => {
    console.log('User connected:', socket.id);

    // Join a chat room
    socket.on('joinRoom', (roomId) => {
      socket.join(roomId);
      console.log(`User ${socket.id} joined room ${roomId}`);
    });

    // When a message is sent
    socket.on('sendMessage', async (data) => {
      const { senderId, receiverId, message, roomId } = data;

      // Save the message in DB
      const [result] = await db.query(
        'INSERT INTO messages (sender_id, receiver_id, message) VALUES (?, ?, ?)',
        [senderId, receiverId, message]
      );

      const savedMessage = {
        id: result.insertId,
        senderId,
        receiverId,
        message,
        createdAt: new Date(),
      };

      // Send to receiver (room)
      io.to(roomId).emit('receiveMessage', savedMessage);
    });

    // ✅ UPDATED: Typing indicator with userId
    socket.on('typing', (data) => {
      const { roomId, userId } = data;

      // Broadcast to room (excluding sender)
      socket.to(roomId).emit('userTyping', {
        userId: userId,
        roomId: roomId
      });

      console.log(`User ${userId} is typing in room ${roomId}`);
    });

    // Disconnect
    socket.on('disconnect', () => {
      console.log('User disconnected:', socket.id);
    });
  });
};
```

## What Changed?

### Before:
```javascript
socket.on('typing', (roomId) => {
  socket.to(roomId).emit('userTyping', { userId: socket.id });
});
```
- Received only `roomId` (string)
- Sent `socket.id` as userId (wrong!)

### After:
```javascript
socket.on('typing', (data) => {
  const { roomId, userId } = data;
  socket.to(roomId).emit('userTyping', {
    userId: userId,
    roomId: roomId
  });
});
```
- Receives `data` object with `roomId` and `userId`
- Sends actual `userId` (correct!)
- Also sends `roomId` for reference

## Testing

After updating, test with two users:

1. **User A** (userId: "ABC123") starts typing in chat
2. **Backend** receives: `{ roomId: "chat_1", userId: "ABC123" }`
3. **Backend** emits to room: `{ userId: "ABC123", roomId: "chat_1" }`
4. **User B** sees: "User is typing..." indicator in:
   - Inbox screen (chat list)
   - ChatScreen appbar

## Backend Logs Should Show:

```
User ABC123 is typing in room chat_1
User XYZ789 is typing in room chat_1
```

Not:
```
User aBc12DeF3 is typing in room chat_1  ❌ (This is socket.id, wrong!)
```

## Restart Backend

After making changes:

```bash
cd Dolo-server
# Kill existing process
# Restart server
npm start
```

You should see the updated typing events working!
