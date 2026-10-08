import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/issues_provider.dart';
import 'home_tab.dart' show IssueListTile;

// Kullanıcının kendi arıza bildirimlerini listeleyen ekran
class MyIssuesTab extends ConsumerWidget {
  const MyIssuesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kullanıcıya ait arıza bildirimlerini ve tema renklerini alır
    final issuesAsync = ref.watch(userIssuesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Listeyi yenileme özelliğini ve veri durumlarını yönetir
    return RefreshIndicator(
      // Liste aşağı çekildiğinde bildirim verilerini yeniden yükler
      onRefresh: () async => ref.invalidate(userIssuesProvider),
      child: issuesAsync.when(
        // Veriler yüklenirken yükleme göstergesi gösterir
        loading: () => const Center(child: CircularProgressIndicator()),

        // Veriler alınırken hata oluştuğunda hata mesajını gösterir
        error: (err, st) => ListView(
          children: [
            const SizedBox(height: 80),
            Icon(Icons.error_outline, size: 40, color: colorScheme.error),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Bildirimler yüklenirken bir sorun oluştu.',
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          ],
        ),

        // Veriler başarıyla alındığında arıza listesini oluşturur
        data: (issues) {
          // Kullanıcının henüz arıza bildirimi yoksa boş liste mesajını gösterir
          if (issues.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 100),
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Henüz bir arıza bildiriminiz yok.',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            );
          }

          // Kullanıcının arıza bildirimlerini kartlar halinde listeler
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: issues.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                IssueListTile(issue: issues[index]),
          );
        },
      ),
    );
  }
}