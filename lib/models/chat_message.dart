import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatMessageType {
  text,
  location;

  static ChatMessageType fromFirestoreValue(String value) {
    return ChatMessageType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ChatMessageType.text,
    );
  }
}

/// Un message échangé entre un client et son chauffeur pour une course,
/// stocké dans `ride_requests/{rideId}/messages/{messageId}`.
class ChatMessage {
  const ChatMessage({
    this.id,
    required this.senderUid,
    required this.type,
    this.text,
    this.locationAddress,
    this.latitude,
    this.longitude,
    this.timestamp,
  });

  final String? id;
  final String senderUid;
  final ChatMessageType type;
  final String? text;
  final String? locationAddress;
  final double? latitude;
  final double? longitude;
  final DateTime? timestamp;

  Map<String, dynamic> toMap() {
    return {
      'senderUid': senderUid,
      'type': type.name,
      if (text != null) 'text': text,
      if (locationAddress != null) 'locationAddress': locationAddress,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final timestamp = data['timestamp'];
    return ChatMessage(
      id: doc.id,
      senderUid: data['senderUid'] as String? ?? '',
      type: ChatMessageType.fromFirestoreValue(data['type'] as String? ?? 'text'),
      text: data['text'] as String?,
      locationAddress: data['locationAddress'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      timestamp: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}
