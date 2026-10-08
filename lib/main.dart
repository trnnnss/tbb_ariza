import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'core/providers/auth_provider.dart';
import 'core/models/app_user.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_shell.dart';
import 'features/admin/admin_panel_screen.dart';
import 'features/staff/staff_panel_screen.dart';
import 'core/constants/app_theme.dart';
import 'core/providers/theme_provider.dart';

import 'core/services/notification_service.dart';
import 'core/providers/notifications_provider.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Bildirim servisini başlatıyoruz
  try {
    await NotificationService().initialize();
  } catch (_) {}

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'TBB Arıza Bildirim',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // Uygulama açılır açılmaz gösterilecek ilk widget: AuthGate.
      home: const AuthGate(),
    );
  }
}

/// Kullanıcının oturum durumuna VE rolüne göre doğru ana ekranı seçen widget.
/// main.dart'ın en kritik parçası - uygulamanın "trafik polisi" gibi düşünülebilir.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  String? _lastNotifId;

  @override
  Widget build(BuildContext context) {
    // authControllerProvider'ı dinliyoruz
    final authState = ref.watch(authControllerProvider);

    // Giriş yapılmışsa canlı bildirimleri dinle ve durum çubuğunda göster
    ref.listen(userNotificationsProvider, (previous, next) {
      final list = next.asData?.value;
      if (list != null && list.isNotEmpty) {
        final newest = list.first;
        // Eğer yeni ve henüz okunmamış bir bildirim geldiyse telefonun üstünde göster
        if (!newest.isRead && newest.id != _lastNotifId) {
          _lastNotifId = newest.id;
          NotificationService().showLocalNotification(
            id: newest.id.hashCode,
            title: newest.title,
            body: newest.body,
          );
        }
      }
    });

    return authState.when(
      // Oturum hâlâ kontrol ediliyorsa: native splash zaten ekranda
      // görünüyor (preserve sayesinde), burada sadece beyaz bir zemin
      // gösteriyoruz ki native splash ile bizim ekranımız arasında
      // renk uyuşmazlığından kaynaklı bir "flaş" olmasın.
      loading: () => const Scaffold(),

      // Bir hata oluştuysa (örn. Firestore'a ulaşılamadı): güvenli
      // tarafta kalıp giriş ekranını gösteriyoruz. FlutterNativeSplash.remove()
      // çağrısı, artık gerçek bir Flutter ekranı hazır olduğu için native
      // splash'ı kaldırıyor (aksi halde ekranda sonsuza kadar kalırdı).
      error: (err, st) {
        FlutterNativeSplash.remove();
        return const LoginScreen();
      },

      // Oturum durumu netleşti (kullanıcı var ya da yok, kesin biliyoruz):
      data: (user) {
        // Artık gerçek içerik gösterileceği için native splash'ı kaldırıyoruz.
        FlutterNativeSplash.remove();

        // Kayıtlı bir oturum yoksa (user null) -> giriş ekranına yönlendir.
        if (user == null) {
          return const LoginScreen();
        }

        // Kullanıcının rolü "yönetici" ise -> Yönetici Paneli'ni göster.
        // Bu panelde tüm arızalar listelenir, filtrelenebilir ve
        // durumları güncellenebilir (bkz. admin_panel_screen.dart).
        if (user.role == UserRole.yonetici) {
          return const AdminPanelScreen();
        }

        // --- YENİ EKLENECEK KISIM ---
        // Kullanıcının rolü "personel" ise -> Saha Personeli Paneli'ni göster.
        if (user.role == UserRole.personel) {
          return const StaffPanelScreen();
        }
        // Diğer tüm durumlarda (yani rol "vatandas" ise) -> normal
        // vatandaş ana ekranını (sekmeli: Ana Sayfa/Bildirimlerim/Profil) göster.
        return const HomeShell();
      },
    );
  }
}