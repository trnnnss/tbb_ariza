import 'package:cloud_firestore/cloud_firestore.dart';

// Bildirim türlerini belirleyen enum yapısı.
enum NotificationType {
  newIssue,       // Yöneticiye: Yeni arıza bildirildi
  assignedToTeam, // Personele & Vatandaşa: Ekibe sevk edildi
  inProgress,     // Vatandaşa & Yöneticiye: Saha çalışması başladı
  resolved,       // Vatandaşa & Yöneticiye: Arıza çözüldü
}

// Uygulamadaki bildirim verilerini temsil eden model sınıfı.
class AppNotification {
  final String id;
  final String recipientPhone;
  final String title;
  final String body;
  final NotificationType type;
  final String? issueId;
  final bool isRead;
  final DateTime createdAt;

  // AppNotification nesnesinin oluşturulmasını sağlayan constructor.
  AppNotification({
    required this.id,
    required this.recipientPhone,
    required this.title,
    required this.body,
    required this.type,
    this.issueId,
    this.isRead = false,
    required this.createdAt,
  });

  // Modeldeki verileri Firestore'a kaydedilebilecek Map yapısına dönüştürür.
  Map<String, dynamic> toMap() {
    return {
      'recipientPhone': recipientPhone,
      'title': title,
      'body': body,
      'type': type.name,
      'issueId': issueId,
      'isRead': isRead,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  // Firestore'dan alınan Map verisini AppNotification nesnesine dönüştürür.
  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    // Firestore'dan gelen tarih bilgisini DateTime formatına dönüştürür.
    DateTime parsedCreatedAt;
    final rawCreated = map['createdAt'];

    if (rawCreated is Timestamp) {
      parsedCreatedAt = rawCreated.toDate();
    } else if (rawCreated is int) {
      parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(rawCreated);
    } else if (rawCreated is num) {
      parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(rawCreated.toInt());
    } else {
      parsedCreatedAt = DateTime.now();
    }

    // Firestore'dan gelen bildirim türünü NotificationType enum değerine dönüştürür.
    final typeStr = map['type'] as String?;
    final type = NotificationType.values.firstWhere(
          (e) => e.name == typeStr,
      orElse: () => NotificationType.newIssue,
    );

    // Elde edilen verilerle AppNotification nesnesi oluşturulur.
    return AppNotification(
      id: id,
      recipientPhone: (map['recipientPhone'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      type: type,
      issueId: map['issueId'] as String?,
      isRead: (map['isRead'] as bool?) ?? false,
      createdAt: parsedCreatedAt,
    );
  }
}