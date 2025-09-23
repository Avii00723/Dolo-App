import 'package:cloud_firestore/cloud_firestore.dart';

final chats = FirebaseFirestore.instance.collection('chats');

// Send a message (add to subcollection)
Future<void> sendMessage(String chatId, Map<String, dynamic> messageData) async {
  await chats.doc(chatId).collection('messages').add(messageData);
}

// Stream chat messages
Stream<QuerySnapshot> getMessages(String chatId) {
  return chats.doc(chatId).collection('messages').orderBy('timestamp').snapshots();
}
