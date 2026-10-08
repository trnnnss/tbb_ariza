import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/app_user.dart';
import '../../core/models/issues_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/issues_provider.dart';
import '../report/report_issue_screen.dart';
import 'home_shell.dart';
import 'issue_ui_helpers.dart';
import 'issue_timeline_widget.dart';
import '../../core/utils/map_launcher.dart';

// Ana sayfa ekranını ve kullanıcıya ait bildirimleri yöneten widget
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  // Arıza bildirim formunu açar ve seçilen kategoriyi forma aktarır
  void _openReportScreen(BuildContext context, [IssueCategory? category]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportIssueScreen(initialCategory: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kullanıcı bilgilerini ve tema renklerini alır
    final authState = ref.watch(authControllerProvider);
    final user = authState.asData?.value;
    final colorScheme = Theme.of(context).colorScheme;

    // Ana sayfa içeriğini yenileme özelliğiyle birlikte oluşturur
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(userIssuesProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Kullanıcıya ait karşılama kartını gösterir
          _WelcomeCard(user: user, colorScheme: colorScheme),
          const SizedBox(height: 16),

          // Yeni arıza bildirimi oluşturmak için bildirim formunu açar
          FilledButton.icon(
            onPressed: () => _openReportScreen(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.tbbRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.warning_amber_rounded),
            label: const Text(
              'Arıza Bildir',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),

          // Kullanıcının arıza bildirebileceği kategorileri gösterir
          Text(
            'Kategoriler',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _CategoryGrid(
            onTapCategory: (category) => _openReportScreen(context, category),
          ),
          const SizedBox(height: 24),

          // Kullanıcının son arıza bildirimlerine ait başlık ve tümünü görme butonunu oluşturur
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Son bildirimlerim',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              TextButton(
                onPressed: () =>
                ref.read(homeShellIndexProvider.notifier).state = 1,
                child: const Text('Tümü'),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Kullanıcının son bildirimlerini listeler
          _RecentIssuesList(),
        ],
      ),
    );
  }
}

// Arıza kategorilerini üçlü grid yapısında gösteren widget
class _CategoryGrid extends StatelessWidget {
  final ValueChanged<IssueCategory> onTapCategory;

  const _CategoryGrid({required this.onTapCategory});

  @override
  Widget build(BuildContext context) {
    // Kategori kartlarında kullanılacak tema renklerini alır
    final colorScheme = Theme.of(context).colorScheme;

    // Arıza kategorilerini kartlar halinde oluşturur
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.05,
      children: IssueCategory.values.map((category) {
        return InkWell(
          onTap: () => onTapCategory(category),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  iconForCategory(category),
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  category.label,
                  style: const TextStyle(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// Kullanıcının adı ve mahalle bilgisini gösteren karşılama kartı
class _WelcomeCard extends StatelessWidget {
  final AppUser? user;
  final ColorScheme colorScheme;

  const _WelcomeCard({
    required this.user,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    // Kullanıcı bilgilerini içeren karşılama kartını oluşturur
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            radius: 22,
            child: const Icon(Icons.person, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Merhaba, ${user?.name.isNotEmpty == true ? user!.name : 'Vatandaş'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.neighborhood ?? 'Trabzon',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Kullanıcının son arıza bildirimlerini veritabanından alıp gösterir
class _RecentIssuesList extends ConsumerWidget {
  const _RecentIssuesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kullanıcının son bildirimlerini ve tema renklerini alır
    final recentAsync = ref.watch(recentUserIssuesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Veri yükleme, hata ve başarılı veri durumlarını yönetir
    return recentAsync.when(
      // Bildirimler yüklenirken yükleme göstergesi gösterir
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),

      // Bildirimler alınırken hata oluştuğunda hata mesajı gösterir
      error: (err, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Kayıtlar yüklenemedi.',
            style: TextStyle(
              color: colorScheme.error,
              fontSize: 13,
            ),
          ),
        ),
      ),

      // Bildirimler başarıyla alındığında listeyi oluşturur
      data: (issues) {
        // Kullanıcının hiç bildirimi yoksa bilgilendirme mesajı gösterir
        if (issues.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(
              vertical: 24,
              horizontal: 16,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Center(
              child: Text(
                'Henüz bir arıza bildiriminiz bulunmuyor.',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        // Kullanıcının bildirimlerini liste halinde gösterir
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: issues.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              IssueListTile(issue: issues[index]),
        );
      },
    );
  }
}

// Tek bir arıza bildirimini özet bilgilerle gösteren liste kartı
class IssueListTile extends StatelessWidget {
  final Issue issue;
  final VoidCallback? onTap;

  const IssueListTile({
    super.key,
    required this.issue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Bildirimin durumuna ve oluşturulma tarihine ait gösterim bilgilerini hazırlar
    final colorScheme = Theme.of(context).colorScheme;
    final statusStyle = styleForStatus(
      issue.status,
      Theme.of(context).brightness,
    );
    final formattedDate =
    DateFormat('dd.MM.yyyy HH:mm').format(issue.createdAt);

    // Bildirim kartına tıklandığında detay ekranını açar
    return InkWell(
      onTap: onTap ?? () => showIssueDetailSheet(context, issue),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bildirimin kategorisine ait ikonu gösterir
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                iconForCategory(issue.category),
                color: colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Bildirimin kategori, durum, konum, açıklama ve tarih bilgilerini gösterir
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        issue.category.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusStyle.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          issue.status.label,
                          style: TextStyle(
                            color: statusStyle.foreground,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${issue.district}, ${issue.neighborhood}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    issue.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Seçilen arıza bildiriminin tüm detaylarını alt panel içerisinde gösterir
void showIssueDetailSheet(BuildContext context, Issue issue) {
  // Detay panelinde kullanılacak durum ve tarih bilgilerini hazırlar
  final colorScheme = Theme.of(context).colorScheme;
  final statusStyle = styleForStatus(
    issue.status,
    Theme.of(context).brightness,
  );
  final formattedDate =
  DateFormat('dd.MM.yyyy HH:mm').format(issue.createdAt);

  // Arıza detaylarını gösteren alt paneli açar
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(20),
      ),
    ),
    builder: (context) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bildirimin kategori ve mevcut durum bilgilerini gösterir
              Row(
                children: [
                  Icon(
                    iconForCategory(issue.category),
                    color: colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    issue.category.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusStyle.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      issue.status.label,
                      style: TextStyle(
                        color: statusStyle.foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Bildirime ait fotoğraf varsa görüntüler
              if (issue.photoUrl != null && issue.photoUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    issue.photoUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 120,
                      color: colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Bildirimin açıklama metnini gösterir
              Text(
                'Açıklama',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                issue.description,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Bildirimin konum bilgilerini gösterir
              Text(
                'Konum',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${issue.district} / ${issue.neighborhood}',
                style: const TextStyle(fontSize: 14),
              ),

              // Adres detay bilgisi mevcutsa gösterir
              if (issue.addressDetail != null &&
                  issue.addressDetail!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  issue.addressDetail!,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),

              // Bildirimin konumunu harita üzerinde açar
              OutlinedButton.icon(
                onPressed: () => MapLauncher.openMap(
                  context: context,
                  latitude: issue.latitude,
                  longitude: issue.longitude,
                  district: issue.district,
                  neighborhood: issue.neighborhood,
                ),
                icon: const Icon(
                  Icons.map_outlined,
                  size: 18,
                ),
                label: const Text('Haritada Konumu Göster'),
              ),
              const SizedBox(height: 16),

              // Arıza bildiriminin işlem ve durum değişikliklerini gösterir
              IssueTimelineWidget(issue: issue),
              const SizedBox(height: 16),

              // Belediye tarafından eklenen not varsa gösterir
              if (issue.assignedNote != null &&
                  issue.assignedNote!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Belediye Notu',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        issue.assignedNote!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Bildirimin oluşturulma tarihini gösterir
              Text(
                'Bildirim Tarihi: $formattedDate',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}