import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_tab.dart';
import 'my_issues_tab.dart';
import 'profile_tab.dart';

import 'notifications_screen.dart';
import '../../core/providers/notifications_provider.dart';

/// Alt menüde hangi sekmenin seçili olduğunu tutar.
final homeShellIndexProvider = StateProvider<int>((ref) => 0);

/// Vatandaş kullanıcının ana ekran yapısını oluşturan widget.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Seçili sekmeyi ve okunmamış bildirim sayısını alır.
    final selectedIndex = ref.watch(homeShellIndexProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    // Uygulamanın AppBar, içerik ve alt navigasyon bölümlerini oluşturur.
    return Scaffold(
      // Uygulamanın üst başlık ve bildirim butonunu oluşturur.
      appBar: AppBar(
        title: const Text('TBB Arıza Bildirim'),
        centerTitle: false,
        actions: [
          // Okunmamış bildirim sayısını gösteren bildirim butonunu oluşturur.
          IconButton(
            tooltip: 'Bildirimler',
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () {
              // Bildirimler ekranını açar.
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),

      // Seçilen sekmeye göre ilgili ekranı gösterir.
      body: IndexedStack(
        index: selectedIndex,
        children: const [
          HomeTab(),
          MyIssuesTab(),
          ProfileTab(),
        ],
      ),

      // Ana sayfa, bildirimler ve profil arasında geçiş sağlayan alt menüyü oluşturur.
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,

        // Kullanıcı farklı bir sekmeye dokunduğunda seçili sekmeyi değiştirir.
        onDestinationSelected: (index) =>
        ref.read(homeShellIndexProvider.notifier).state = index,

        // Alt menüde gösterilecek sekmeleri tanımlar.
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Bildirimlerim',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}