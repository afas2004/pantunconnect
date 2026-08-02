import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors domain/model/Message.kt (Message + Chat)
class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final int timestamp;

  ChatMessage({
    this.id = '',
    this.chatId = '',
    this.senderId = '',
    this.text = '',
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  factory ChatMessage.fromMap(Map<String, dynamic> map, {String? overrideId}) {
    return ChatMessage(
      id: overrideId ?? map['id'] as String? ?? '',
      chatId: map['chatId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt(),
    );
  }

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ChatMessage.fromMap(doc.data() ?? {}, overrideId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
    };
  }

  ChatMessage copyWith({String? id}) => ChatMessage(
        id: id ?? this.id,
        chatId: chatId,
        senderId: senderId,
        text: text,
        timestamp: timestamp,
      );
}

class Chat {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final int lastMessageTimestamp;

  Chat({
    this.id = '',
    this.participants = const [],
    this.lastMessage = '',
    int? lastMessageTimestamp,
  }) : lastMessageTimestamp = lastMessageTimestamp ?? DateTime.now().millisecondsSinceEpoch;

  factory Chat.fromMap(Map<String, dynamic> map, {String? overrideId}) {
    return Chat(
      id: overrideId ?? map['id'] as String? ?? '',
      participants: (map['participants'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageTimestamp: (map['lastMessageTimestamp'] as num?)?.toInt(),
    );
  }

  factory Chat.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Chat.fromMap(doc.data() ?? {}, overrideId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': lastMessageTimestamp,
    };
  }

  /// Mirrors ChatRepository.getOtherParticipantId
  String? otherParticipantId(String currentUserId) {
    for (final p in participants) {
      if (p != currentUserId) return p;
    }
    return null;
  }
}
