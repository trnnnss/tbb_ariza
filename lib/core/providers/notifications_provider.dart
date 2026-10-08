import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());

/// Kullanıcının rolüne göre (Vatandaş ise kendi telefonuna, Yönetici ise 'all_admins'a,
/// Personel ise 'team_`teamId`'ye gelen) bildirimleri canlı dinleyen StreamProvider.
final userNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final authState = ref.watch(authControllerProvider);
  final user = authState.asData?.value;

  if (user == null) {
    return Stream.value(<AppNotification>[]);
  }

  // Kullanıcının dinleyeceği alıcı kimlikleri
  final List<String> targetRecipients = [user.phone];

  if (user.role == UserRole.yonetici) {
    targetRecipients.add('all_admins');
  } else if (user.role == UserRole.personel && user.teamId != null) {
    targetRecipients.add('team_${user.teamId}');
  }

  return FirebaseFirestore.instance
      .collection('notifications')
      .where('recipientPhone', whereIn: targetRecipients)
      .snapshots()
      .map((snapshot) {
    final list = snapshot.docs
        .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // En yeni bildirimi en üste koy
    return list;
  });
});

/// Okunmamış bildirim sayısını döner
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(userNotificationsProvider).asData?.value ?? [];
  return notifications.where((n) => !n.isRead).length;
});
