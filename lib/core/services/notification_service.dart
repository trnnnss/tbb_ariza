import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/app_notification.dart';

/// Cihaz içi yerel bildirimleri (durum çubuğu bildirimleri) ve
/// Firestore bildirim kayıtlarını yöneten ana servis.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Servisi başlatır ve Android/iOS bildirim izinlerini ayarlar
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Android başlatma ayarları (varsayılan launcher ikonu)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS / Darwin başlatma ayarları
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(initSettings);

    // Android 13+ için bildirim izni isteği
    final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }

    _isInitialized = true;
  }

  /// Telefonun üst bildirim çubuğunda sesli ve titreşimli bildirim gösterir
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'tbb_ariza_channel',
      'TBB Arıza Bildirimleri',
      channelDescription: 'Arıza süreç ve atama bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }

  /// Firestore'a yeni bir bildirim kaydı yazar
  Future<void> createNotification({
    required String recipientPhone,
    required String title,
    required String body,
    required NotificationType type,
    String? issueId,
  }) async {
    final notification = AppNotification(
      id: '',
      recipientPhone: recipientPhone,
      title: title,
      body: body,
      type: type,
      issueId: issueId,
      createdAt: DateTime.now(),
    );

    await FirebaseFirestore.instance.collection('notifications').add(notification.toMap());
  }

  /// 1. YÖNETİCİYE BİLDİRİM: Vatandaş yeni arıza bildirdiğinde tüm yöneticilere bildirim yollar
  Future<void> notifyAdminsNewIssue({
    required String district,
    required String neighborhood,
    required String categoryName,
    required String issueId,
  }) async {
    await createNotification(
      recipientPhone: 'all_admins',
      title: '🚨 Yeni Arıza Bildirimi ($categoryName)',
      body: '$district / $neighborhood bölgesinde yeni bir arıza kaydı oluşturuldu.',
      type: NotificationType.newIssue,
      issueId: issueId,
    );
  }

  /// 2. PERSONELE & VATANDAŞA BİLDİRİM: Yönetici arızayı ekibe sevk ettiğinde
  Future<void> notifyAssignment({
    required String teamId,
    required String teamName,
    required String reporterPhone,
    required String categoryName,
    required String district,
    required String issueId,
  }) async {
    // A) Personele / İlgili Ekibe Bildirim:
    await createNotification(
      recipientPhone: 'team_$teamId',
      title: '📋 Yeni Görev Zimmetlendi!',
      body: '$teamName biriminize $district ilçesinde yeni bir $categoryName görevi atandı.',
      type: NotificationType.assignedToTeam,
      issueId: issueId,
    );

    // B) Vatandaşa Bildirim:
    await createNotification(
      recipientPhone: reporterPhone,
      title: '🚀 Arızanız Saha Ekibine Sevk Edildi',
      body: 'Bildirdiğiniz $categoryName arızası incelendi ve $teamName ekiplerimize yönlendirildi.',
      type: NotificationType.assignedToTeam,
      issueId: issueId,
    );
  }

  /// 3. VATANDAŞA & YÖNETİCİYE BİLDİRİM: Arıza çözülüp kapatıldığında
  Future<void> notifyIssueResolved({
    required String reporterPhone,
    required String teamName,
    required String categoryName,
    required String district,
    required String solutionNote,
    required String issueId,
  }) async {
    // A) Vatandaşa Bildirim:
    await createNotification(
      recipientPhone: reporterPhone,
      title: '✅ Arızanız Giderildi ve Çözüldü!',
      body: '$teamName tarafından arızanız onarıldı. Not: $solutionNote',
      type: NotificationType.resolved,
      issueId: issueId,
    );

    // B) Yöneticilere Bilgilendirme:
    await createNotification(
      recipientPhone: 'all_admins',
      title: '🎉 Bir Görev Tamamlandı ($categoryName)',
      body: '$teamName, $district ilçesindeki arıza kaydını başarıyla sonuçlandırdı.',
      type: NotificationType.resolved,
      issueId: issueId,
    );
  }
}
