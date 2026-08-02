import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_model.dart';

/// Mirrors data/repository/ChatRepository.kt, including the getOrCreateChat addition made on
/// the Kotlin side (there was previously no way to start a NEW chat, only read existing ones).
class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _chats => _firestore.collection('chats');

  Stream<List<Chat>> getChats(String userId) {
    // arrayContains + orderBy would require a composite index (silent FAILED_PRECONDITION until
    // created manually in the console) - sort client-side instead, chat lists are small.
    return _chats.where('participants', arrayContains: userId).snapshots().map((snapshot) {
      final chats = snapshot.docs.map(Chat.fromDoc).toList();
      chats.sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));
      return chats;
    });
  }

  Stream<List<ChatMessage>> getMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ChatMessage.fromDoc).toList());
  }

  /// Finds an existing 1:1 chat between the two users, or creates one if none exists yet.
  Future<String> getOrCreateChat(String currentUserId, String otherUserId) async {
    final existingSnapshot = await _chats.where('participants', arrayContains: currentUserId).get();
    for (final doc in existingSnapshot.docs) {
      final participants = List<String>.from(doc.data()['participants'] as List? ?? []);
      if (participants.length == 2 && participants.contains(otherUserId)) {
        return doc.id;
      }
    }

    final newChatRef = _chats.doc();
    final newChat = Chat(
      id: newChatRef.id,
      participants: [currentUserId, otherUserId],
      lastMessage: '',
      lastMessageTimestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await newChatRef.set(newChat.toMap());
    return newChatRef.id;
  }

  String? getOtherParticipantId(Chat chat, String currentUserId) => chat.otherParticipantId(currentUserId);

  Future<void> sendMessage(String chatId, ChatMessage message) async {
    final batch = _firestore.batch();

    final messageRef = _chats.doc(chatId).collection('messages').doc();
    final messageWithId = message.copyWith(id: messageRef.id);
    batch.set(messageRef, messageWithId.toMap());

    final chatRef = _chats.doc(chatId);
    batch.update(chatRef, {
      'lastMessage': message.text,
      'lastMessageTimestamp': message.timestamp,
    });

    await batch.commit();
  }
}
