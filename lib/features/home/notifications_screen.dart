import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/app_notification.dart';
import '../../core/providers/notifications_provider.dart';

// Bildirimlerin listelendiği ekran
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final notificationsAsync = ref.watch(userNotificationsProvider);
    final theme = Theme.of(context);

    // Bildirim ekranının temel Scaffold ve AppBar yapısı oluşturulur.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [

          // Tüm okunmamış bildirimleri okundu olarak işaretleyen buton oluşturulur.
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Tümünü Okundu İşaretle',
            onPressed: () async {
              final list = notificationsAsync.asData?.value ?? [];
              final batch = FirebaseFirestore.instance.batch();

              for (final notif in list.where((n) => !n.isRead)) {
                final ref = FirebaseFirestore.instance
                    .collection('notifications')
                    .doc(notif.id);

                batch.update(ref, {'isRead': true});
              }

              await batch.commit();
            },
          ),
        ],
      ),

      // Bildirim verisinin yüklenme, hata ve başarılı veri durumları yönetilir.
      body: notificationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),//dairesel yükkleme animasyonu
        ),
        error: (e, _) => Center(
          child: Text('Hata: $e'),
        ),
        data: (notifications) {

          // Bildirim bulunmadığında kullanıcıya boş bildirim ekranı gösterilir.
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 72,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz bir bildiriminiz yok',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          // Bildirimler liste halinde oluşturulur ve her bildirim için kart kullanılır.
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = notifications[index];
              return _NotificationCard(item: item);
            },
          );
        },
      ),
    );
  }
}

// Tek bir bildirimin kart görünümünü oluşturan widget tanımlanır.
class _NotificationCard extends StatelessWidget {
  final AppNotification item;

  const _NotificationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Bildirim türüne göre gösterilecek ikon ve renk belirlenir.
    IconData icon;
    Color iconColor;

    switch (item.type) {
      case NotificationType.newIssue:
        icon = Icons.warning_amber_rounded;
        iconColor = Colors.orange;
        break;
      case NotificationType.assignedToTeam:
        icon = Icons.assignment_outlined;
        iconColor = Colors.blue;
        break;
      case NotificationType.inProgress:
        icon = Icons.build_circle_outlined;
        iconColor = Colors.amber[800]!;
        break;
      case NotificationType.resolved:
        icon = Icons.check_circle_outline;
        iconColor = Colors.green;
        break;
    }

    // Bildirim tarihi kullanıcıya uygun tarih ve saat formatına dönüştürülür.
    final formattedDate = DateFormat('dd.MM.yyyy HH:mm').format(item.createdAt);

    // Bildirim kartının görünümü ve okunma durumuna göre renkleri belirlenir.
    return Card(
      elevation: 0,
      color: item.isRead
          ? (isDark ? Colors.grey[900] : Colors.grey[50])
          : (isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue[50]),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.isRead
              ? (isDark ? Colors.white12 : Colors.black12)
              : Colors.blue.withValues(alpha: 0.4),
          width: item.isRead ? 1 : 1.5,
        ),
      ),

      // Bildirime tıklandığında okunmamış bildirim Firestore üzerinde güncellenir.
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (!item.isRead) {
            FirebaseFirestore.instance
                .collection('notifications')
                .doc(item.id)
                .update({'isRead': true});
          }
        },

        // Bildirim kartının ikon, başlık, içerik ve tarih bölümleri oluşturulur.
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Bildirim başlığı ve okunmamış bildirim göstergesi oluşturulur.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: item.isRead
                                  ? FontWeight.w600
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Bildirim açıklaması kullanıcıya gösterilir.
                    Text(
                      item.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Bildirimin oluşturulma tarihi gösterilir.
                    Text(
                      formattedDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}