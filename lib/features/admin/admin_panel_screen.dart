import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/neighborhoods_data.dart';
import '../../core/models/issues_model.dart';
import '../../core/models/team_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/issues_provider.dart';
import '../../core/providers/teams_provider.dart';
import '../home/issue_ui_helpers.dart';
import '../home/issue_timeline_widget.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/utils/map_launcher.dart';
import '../../core/providers/notifications_provider.dart';
import '../auth/change_pin_sheet.dart';
import '../home/notifications_screen.dart';
import 'team_detail_sheet.dart';

/// Durum filtresi seçimini (Tümü / Beklemede / İşleme Alındı / Çözüldü)
/// tutan StateProvider. null -> "Tümü" seçili demektir.
final _statusFilterProvider = StateProvider<IssueStatus?>((ref) => null);

/// Yönetici panelindeki aktif alt sekme indeksi (0: Arızalar, 1: Ekipler, 2: Profil)
final _adminTabIndexProvider = StateProvider<int>((ref) => 0);

/// Arama çubuğuna yazılan metni tutar (boşsa arama yapılmıyor demektir).
final _searchQueryProvider = StateProvider<String>((ref) => '');

/// Seçilen ilçeyi tutar (null ise "Tüm İlçeler" seçilidir).
final _districtFilterProvider = StateProvider<String?>((ref) => null);

/// Seçilen başlangıç ve bitiş tarihlerini tutar (null ise "Tüm Zamanlar").
final _dateRangeFilterProvider = StateProvider<DateTimeRange?>((ref) => null);

/// Trabzon Büyükşehir Belediyesi Yönetici Paneli Ana Ekranı.
/// 3 ana sekmeye sahiptir:
/// 1. Arıza Havuzu & Dashboard: Şehir genelindeki tüm arızalar, renkli metrik kartları ve filtreler.
/// 2. Ekipler & Personeller: Trabzon Büyükşehir birimleri (TİSKİ, Fen İşleri vb.), kadroları ve görev havuzları.
/// 3. Yönetim & Profil: Yönetici bilgisi, sistem istatistikleri ve güvenli çıkış.
class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(_adminTabIndexProvider);
    final issuesAsync = ref.watch(allIssuesProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final teams = teamsAsync.valueOrNull ?? [];
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yönetici Portalı',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Trabzon Büyükşehir Belediyesi',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Bildirimler',
            icon: Badge(
              isLabelVisible: ref.watch(unreadNotificationCountProvider) > 0,
              label: Text('${ref.watch(unreadNotificationCountProvider)}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(allIssuesProvider),
          ),
          IconButton(
            tooltip: 'Çıkış Yap',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: IndexedStack(
        index: currentTab,
        children: [
          // 0. Sekme: Arıza Havuzu & Dashboard
          _AdminIssuesTab(issuesAsync: issuesAsync, teams: teams),
          // 1. Sekme: Ekipler ve Saha Personeli
          _AdminTeamsTab(issuesAsync: issuesAsync, teamsAsync: teamsAsync),
          // 2. Sekme: Profil ve İstatistikler
          _AdminProfileTab(issuesAsync: issuesAsync),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        onDestinationSelected: (index) {
          ref.read(_adminTabIndexProvider.notifier).state = index;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Arıza Havuzu',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Ekipler & Kadro',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: 'Yönetim',
          ),
        ],
      ),
    );
  }
}

/// 1. SEKME: ARIZA HAVUZU & DASHBOARD
class _AdminIssuesTab extends ConsumerWidget {
  final AsyncValue<List<Issue>> issuesAsync;
  final List<Team> teams;

  const _AdminIssuesTab({required this.issuesAsync, required this.teams});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(_statusFilterProvider);
    final searchQuery = ref.watch(_searchQueryProvider);
    final selectedDistrict = ref.watch(_districtFilterProvider);
    final selectedDateRange = ref.watch(_dateRangeFilterProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return issuesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Arızalar yüklenirken sorun oluştu: $err',
              style: TextStyle(color: colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => ref.invalidate(allIssuesProvider),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
      data: (allIssues) {
        // İstatistik Sayaçları
        final totalCount = allIssues.length;
        final pendingCount = allIssues
            .where((i) => i.status == IssueStatus.beklemede)
            .length;
        final inProgressCount = allIssues
            .where((i) => i.status == IssueStatus.islemeAlindi)
            .length;
        final resolvedCount = allIssues
            .where((i) => i.status == IssueStatus.cozuldu)
            .length;

        // Çok kriterli filtreleme: Durum + İlçe + Tarih Aralığı + Arama
        final filteredIssues = allIssues.where((issue) {
          // 1. Durum Kontrolü (Beklemede, İşlemde, Çözüldü)
          if (selectedFilter != null && issue.status != selectedFilter) {
            return false;
          }

          // 2. İlçe Kontrolü (Ortahisar, Akçaabat vb.)
          if (selectedDistrict != null && issue.district != selectedDistrict) {
            return false;
          }

          // 3. Tarih Aralığı Kontrolü (Günün başı 00:00 ve sonu 23:59:59 dahil)
          if (selectedDateRange != null) {
            final start = DateTime(
              selectedDateRange.start.year,
              selectedDateRange.start.month,
              selectedDateRange.start.day,
            );
            final end = DateTime(
              selectedDateRange.end.year,
              selectedDateRange.end.month,
              selectedDateRange.end.day,
              23,
              59,
              59,
            );
            if (issue.createdAt.isBefore(start) ||
                issue.createdAt.isAfter(end)) {
              return false;
            }
          }

          // 4. Arama Çubuğu Kontrolü (Vatandaş adı, telefon, mahalle, açıklama veya ekip)
          if (searchQuery.trim().isNotEmpty) {
            final q = searchQuery.trim().toLowerCase();
            final matchName = issue.reporterName.toLowerCase().contains(q);
            final matchPhone = issue.reporterPhone.contains(q);
            final matchDesc = issue.description.toLowerCase().contains(q);
            final matchNeighborhood = issue.neighborhood.toLowerCase().contains(
              q,
            );
            final matchDistrict = issue.district.toLowerCase().contains(q);
            final matchTeam =
                issue.assignedTeamName?.toLowerCase().contains(q) ?? false;
            final matchStaff =
                issue.assignedStaffName?.toLowerCase().contains(q) ?? false;

            if (!matchName &&
                !matchPhone &&
                !matchDesc &&
                !matchNeighborhood &&
                !matchDistrict &&
                !matchTeam &&
                !matchStaff) {
              return false;
            }
          }

          return true;
        }).toList();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allIssuesProvider),
          child: CustomScrollView(
            slivers: [
              // Üst Renkli Metrik Kartları
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Başlık
                      Row(
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Şehir Genel Arıza Göstergeleri',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // 4 Renkli Metrik Kartı
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: 'Toplam',
                              count: totalCount,
                              color: const Color(0xFF1976D2),
                              icon: Icons.all_inbox_outlined,
                              isSelected: selectedFilter == null,
                              onTap: () =>
                              ref
                                  .read(_statusFilterProvider.notifier)
                                  .state =
                              null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MetricCard(
                              title: 'Bekleyen',
                              count: pendingCount,
                              color: const Color(0xFFE65100),
                              icon: Icons.hourglass_top_outlined,
                              isSelected:
                              selectedFilter == IssueStatus.beklemede,
                              onTap: () =>
                              ref
                                  .read(_statusFilterProvider.notifier)
                                  .state =
                                  IssueStatus.beklemede,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: 'İşlemde',
                              count: inProgressCount,
                              color: const Color(0xFF00838F),
                              icon: Icons.handyman_outlined,
                              isSelected:
                              selectedFilter == IssueStatus.islemeAlindi,
                              onTap: () =>
                              ref
                                  .read(_statusFilterProvider.notifier)
                                  .state =
                                  IssueStatus.islemeAlindi,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MetricCard(
                              title: 'Çözüldü',
                              count: resolvedCount,
                              color: const Color(0xFF2E7D32),
                              icon: Icons.check_circle_outline,
                              isSelected: selectedFilter == IssueStatus.cozuldu,
                              onTap: () =>
                              ref
                                  .read(_statusFilterProvider.notifier)
                                  .state =
                                  IssueStatus.cozuldu,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 1. ARAMA ÇUBUĞU
                      TextField(
                        onChanged: (val) =>
                        ref.read(_searchQueryProvider.notifier).state = val,
                        decoration: InputDecoration(
                          hintText: 'Vatandaş, telefon, mahalle veya arıza ara...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => ref
                                .read(_searchQueryProvider.notifier)
                                .state = '',
                          )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. GELİŞMİŞ FİLTRE ÇİPLERİ (İlçe + Tarih + Sıfırla)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // İLÇE SEÇİM ÇİPİ
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                avatar: const Icon(Icons.location_city, size: 16),
                                label: Text(
                                  selectedDistrict == null
                                      ? 'İlçe Filtrele'
                                      : 'İlçe: $selectedDistrict',
                                ),
                                selected: selectedDistrict != null,
                                onSelected: (_) =>
                                    _showDistrictPicker(context, ref),
                              ),
                            ),

                            // TARİH ARALIĞI ÇİPİ
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                avatar: const Icon(Icons.date_range, size: 16),
                                label: Text(
                                  selectedDateRange == null
                                      ? 'Tarih Aralığı'
                                      : '${DateFormat('dd.MM.yy').format(selectedDateRange.start)} - ${DateFormat('dd.MM.yy').format(selectedDateRange.end)}',
                                ),
                                selected: selectedDateRange != null,
                                onSelected: (_) =>
                                    _pickDateRange(context, ref),
                              ),
                            ),

                            // EĞER HERHANGİ BİR FİLTRE AKTİFSE "SIFIRLA" BUTONU
                            if (selectedFilter != null ||
                                selectedDistrict != null ||
                                selectedDateRange != null ||
                                searchQuery.isNotEmpty)
                              ActionChip(
                                avatar: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Filtreleri Sıfırla',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () {
                                  ref.read(_statusFilterProvider.notifier).state =
                                  null;
                                  ref
                                      .read(_districtFilterProvider.notifier)
                                      .state = null;
                                  ref
                                      .read(_dateRangeFilterProvider.notifier)
                                      .state = null;
                                  ref.read(_searchQueryProvider.notifier).state =
                                  '';
                                },
                              ),
                          ],
                        ),
                      ),

                      // Filtre Sonuç Bilgisi (Kaç arıza eşleşti)
                      if (selectedFilter != null ||
                          selectedDistrict != null ||
                          selectedDateRange != null ||
                          searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${filteredIssues.length} arıza listeleniyor',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Arıza Listesi
              if (filteredIssues.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 56,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Bu filtreye uyan arıza kaydı bulunamadı.',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final issue = filteredIssues[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AdminIssueCard(issue: issue, teams: teams),
                      );
                    }, childCount: filteredIssues.length),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Yöneticinin takvimden başlangıç ve bitiş tarihi seçmesini sağlayan fonksiyon.
Future<void> _pickDateRange(BuildContext context, WidgetRef ref) async {
  final currentRange = ref.read(_dateRangeFilterProvider);
  final now = DateTime.now();

  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2023), // En eski tarih
    lastDate: DateTime(now.year + 2), // En ileri tarih
    initialDateRange:
    currentRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 7)), // Varsayılan: Son 7 gün
          end: now,
        ),
    helpText: 'Tarih Aralığı Seçin',
    saveText: 'Filtrele',
    cancelText: 'Vazgeç',
  );

  if (picked != null) {
    ref.read(_dateRangeFilterProvider.notifier).state = picked;
  }
}

/// Trabzon ilçelerini alttan açılır liste halinde seçtiren fonksiyon.
void _showDistrictPicker(BuildContext context, WidgetRef ref) {
  final currentDistrict = ref.read(_districtFilterProvider);

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'İlçe Seçin',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('Tüm İlçeler'),
                    trailing: currentDistrict == null
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      ref.read(_districtFilterProvider.notifier).state = null;
                      Navigator.pop(ctx);
                    },
                  ),
                  ...NeighborhoodsData.districtNames.map((district) {
                    final isSelected = currentDistrict == district;
                    return ListTile(
                      title: Text(district),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () {
                        ref.read(_districtFilterProvider.notifier).state =
                            district;
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// İstatistik Metrik Kartı Widget'ı
class _MetricCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _MetricCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isSelected ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: isSelected ? 0.8 : 0.25),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
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

/// Zengin Arıza Kartı Widget'ı
class _AdminIssueCard extends StatelessWidget {
  final Issue issue;
  final List<Team> teams;

  const _AdminIssueCard({required this.issue, required this.teams});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusStyle = styleForStatus(
      issue.status,
      Theme.of(context).brightness,
    );
    final formattedDate = DateFormat('dd.MM.yyyy HH:mm')
        .format(issue.createdAt);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showAdminIssueDetailSheet(context, issue, teams),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst Satır: Kategori & Durum Rozeti
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      iconForCategory(issue.category),
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issue.category.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${issue.district}, ${issue.neighborhood}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusStyle.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      issue.status.label,
                      style: TextStyle(
                        color: statusStyle.foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Arıza Açıklaması
              Text(
                issue.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
              ),

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Atanan Ekip / Personel Rozeti (Varsa)
              if (issue.assignedTeamName != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.secondary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.engineering_outlined,
                        size: 16,
                        color: colorScheme.secondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Görevli: ${issue.assignedTeamName}${issue.assignedStaffName != null ? ' (${issue.assignedStaffName})' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSecondaryContainer,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Alt Bilgi: Bildiren Kişi ve Tarih
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            issue.reporterName,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// 2. SEKME: EKİPLER VE SAHA PERSONELİ KADROSU
class _AdminTeamsTab extends StatelessWidget {
  final AsyncValue<List<Issue>> issuesAsync;
  final AsyncValue<List<Team>> teamsAsync;

  const _AdminTeamsTab({required this.issuesAsync, required this.teamsAsync});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allIssues = issuesAsync.value ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Bilgilendirme Başlığı
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.groups_outlined, size: 28, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trabzon Büyükşehir Saha Ekipleri',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bir ekibe dokunarak personellerini listeleyebilir ve o ekibe atanmış görev havuzunu inceleyebilirsiniz.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Ekipler Listesi (Firestore'dan canlı olarak dinlenir)
        ...teamsAsync.when(
          loading: () => [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (err, st) => [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 40, color: colorScheme.error),
                  const SizedBox(height: 8),
                  Text(
                    'Ekipler yüklenirken sorun oluştu: $err',
                    style: TextStyle(color: colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
          data: (teams) {
            if (teams.isEmpty) {
              return [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Henüz kayıtlı ekip bulunmuyor.',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ];
            }
            return teams.map((team) {
              // Bu ekibe atanmış ve henüz çözülmemiş arızalar
              final assignedIssues = allIssues
                  .where((i) => i.assignedTeamId == team.id)
                  .toList();
              final activeCount = assignedIssues
                  .where((i) => !i.status.isClosed)
                  .length;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: team.color.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TeamDetailSheet(
                          team: team,
                          onSelectIssue: (issue) =>
                              _showAdminIssueDetailSheet(context, issue, teams),
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        // Ekip İkonu
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: team.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(team.icon, color: team.color, size: 26),
                        ),
                        const SizedBox(width: 14),
                        // Ekip Bilgileri
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                team.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                team.department,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  // Personel Sayısı
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${team.members.length} Personel',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Aktif Görev Rozeti
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: activeCount > 0
                                          ? Colors.orange.withValues(alpha: 0.15)
                                          : Colors.green.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$activeCount Aktif Görev',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: activeCount > 0
                                            ? Colors.orange[800]
                                            : Colors.green[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            }).toList();
          },
        ),
      ],
    );
  }
}
/// 3. SEKME: YÖNETİCİ PROFİLİ & SİSTEM DETAYLARI
class _AdminProfileTab extends ConsumerWidget {
  final AsyncValue<List<Issue>> issuesAsync;

  const _AdminProfileTab({required this.issuesAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).asData?.value;
    final colorScheme = Theme.of(context).colorScheme;
    final allIssues = issuesAsync.value ?? [];
    final resolvedCount = allIssues
        .where((i) => i.status.isClosed)
        .length;
    final resolvedPercent = allIssues.isEmpty
        ? 0
        : ((resolvedCount / allIssues.length) * 100).round();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Yönetici Profil Kartı
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.admin_panel_settings, size: 34),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Sistem Yöneticisi',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.phone ?? 'Yönetim Hesabı',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Sistem Yöneticisi (Admin)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Başarı & Çözüm Oranı Kartı
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Arıza Çözüm Performansı',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: allIssues.isEmpty
                        ? 0
                        : resolvedCount / allIssues.length,
                    minHeight: 10,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$resolvedCount / ${allIssues.length} arıza çözüldü',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '%$resolvedPercent Başarı',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Sistem & Kurum Bilgisi
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const Icon(Icons.location_city_outlined),
            title: const Text('Kurum'),
            subtitle: const Text('Trabzon Büyükşehir Belediyesi'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const Icon(Icons.cloud_done_outlined),
            title: const Text('Veritabanı Servisi'),
            subtitle: const Text('Google Cloud Firestore (Canlı Senkronize)'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const Icon(Icons.verified_outlined),
            title: const Text('Uygulama Sürümü'),
            subtitle: const Text('v1.0.0 — Üretim Sürümü'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Koyu Tema'),
            subtitle: const Text('Gözü yormayan modern karanlık arayüz'),
            trailing: Switch(
              value: ref.watch(themeModeProvider) == ThemeMode.dark,
              onChanged: (isDark) {
                ref.read(themeModeProvider.notifier).state = isDark
                    ? ThemeMode.dark
                    : ThemeMode.light;
              },
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Güvenlik & Şifre İşlemleri
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: ListTile(
            onTap: () => showChangePinSheet(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const Icon(Icons.lock_reset_outlined),
            title: const Text('Şifre Değiştir'),
            subtitle: const Text('Hesabınızın giriş şifresini (PIN) yenileyin'),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
        const SizedBox(height: 24),

        // Çıkış Butonu
        FilledButton.tonalIcon(
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: Colors.red[700],
            backgroundColor: Colors.red.withValues(alpha: 0.1),
          ),
          icon: const Icon(Icons.logout),
          label: const Text(
            'Güvenli Çıkış Yap',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

/// ARIZA DÜZENLEME & EKİP ATAMA MODAL ARAYÜZÜ (BOTTOM SHEET)

void _showAdminIssueDetailSheet(
    BuildContext context, Issue issue, List<Team> teams) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _AdminIssueDetailContent(issue: issue, teams: teams),
  );
}

class _AdminIssueDetailContent extends ConsumerStatefulWidget {
  final Issue issue;
  final List<Team> teams;

  const _AdminIssueDetailContent({required this.issue, required this.teams});

  @override
  ConsumerState<_AdminIssueDetailContent> createState() =>
      _AdminIssueDetailContentState();
}

class _AdminIssueDetailContentState
    extends ConsumerState<_AdminIssueDetailContent> {
  late IssueStatus _selectedStatus;
  late IssuePriority _selectedPriority;
  late final TextEditingController _noteController;

  Team? _selectedTeam;
  StaffMember? _selectedStaff;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.issue.status;
    _selectedPriority = widget.issue.priority;
    _noteController = TextEditingController(
      text: widget.issue.assignedNote ?? '',
    );

    // Başlangıç ekibi: önceden atanmışsa o ekip, yoksa kategorisine göre önerilen ekip
    if (widget.issue.assignedTeamId != null) {
      _selectedTeam = findTeamById(widget.teams, widget.issue.assignedTeamId);
    } else {
      _selectedTeam = findTeamForCategory(widget.teams, widget.issue.category);
    }

    // Başlangıç personeli: atanmışsa bul
    if (widget.issue.assignedStaffName != null && _selectedTeam != null) {
      try {
        _selectedStaff = _selectedTeam!.members.firstWhere(
              (m) => m.name == widget.issue.assignedStaffName,
        );
      } catch (_) {
        _selectedStaff = null;
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final actorName = ref.read(authControllerProvider).asData?.value?.name;
      await updateIssueStatus(
        issueId: widget.issue.id,
        status: _selectedStatus,
        assignedNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        assignedTeamId: _selectedTeam?.id,
        assignedTeamName: _selectedTeam?.name,
        assignedStaffName: _selectedStaff?.name,
        priority: _selectedPriority,
        actorName: actorName,
      );
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _selectedTeam != null
                  ? 'Arıza "${_selectedTeam!.name}" ekibine atandı ve güncellendi.'
                  : 'Arıza güncellendi.',
            ),
            backgroundColor: Colors.green[800],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Güncelleme başarısız: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    final colorScheme = Theme.of(context).colorScheme;
    final formattedDate = DateFormat('dd.MM.yyyy HH:mm')
        .format(issue.createdAt);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Kategori Başlığı ve İkonu
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.primary,
                  child: Icon(iconForCategory(issue.category), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.category.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Kayıt ID: ${issue.id}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Varsa Fotoğraf
            if (issue.photoUrl != null && issue.photoUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  issue.photoUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 120,
                    color: colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, size: 36),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Açıklama & Konum
            Text(
              issue.description,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              '${issue.district}, ${issue.neighborhood}'
                  '${issue.addressDetail != null && issue.addressDetail!.isNotEmpty ? ' — ${issue.addressDetail}' : ''}',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bildiren: ${issue.reporterName} (${issue.reporterPhone}) • $formattedDate',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => MapLauncher.openMap(
                context: context,
                latitude: issue.latitude,
                longitude: issue.longitude,
                district: issue.district,
                neighborhood: issue.neighborhood,
              ),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Haritada Göster & Yol Tarifi Al'),
            ),
            const SizedBox(height: 14),
            IssueTimelineWidget(issue: issue),
            const Divider(height: 28),

            // --- EKİP VE PERSONEL ATAMASI ---
            Text(
              'Sorumlu Ekip & Personel Atama',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Ekip Dropdown
            DropdownButtonFormField<Team?>(
              initialValue: _selectedTeam,
              decoration: const InputDecoration(
                labelText: 'Müdahale Edecek Ekip',
                prefixIcon: Icon(Icons.groups_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Atama Yapılmadı (Boş)'),
                ),
                ...widget.teams.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Row(
                      children: [
                        Icon(t.icon, size: 18, color: t.color),
                        const SizedBox(width: 8),
                        Text(t.name, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (newTeam) {
                setState(() {
                  _selectedTeam = newTeam;
                  _selectedStaff = null;
                });
              },
            ),
            const SizedBox(height: 10),

            // Personel Dropdown (Ekip seçiliyse aktif)
            if (_selectedTeam != null) ...[
              DropdownButtonFormField<StaffMember?>(
                key: ValueKey(_selectedTeam?.id),
                initialValue: _selectedStaff,
                decoration: InputDecoration(
                  labelText: '${_selectedTeam!.name} Personeli',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Tüm Ekip (Genel Havuz)'),
                  ),
                  ..._selectedTeam!.members.map((m) {
                    final isStaffActive = m.isActive;
                    String leaveText = '';
                    if (!isStaffActive) {
                      if (m.leaveStartDate != null && m.leaveEndDate != null) {
                        final s = DateFormat('dd.MM').format(m.leaveStartDate!);
                        final e = DateFormat('dd.MM').format(m.leaveEndDate!);
                        leaveText = ' - [İzinli: $s - $e]';
                      } else {
                        leaveText = ' - [İzinli]';
                      }
                    }
                    return DropdownMenuItem(
                      value: m,
                      child: Text(
                        '${m.name} (${m.title})$leaveText',
                        style: TextStyle(
                          fontSize: 13,
                          color: isStaffActive ? null : Colors.orange,
                        ),
                      ),
                    );
                  }),
                ],
                onChanged: (newStaff) {
                  setState(() => _selectedStaff = newStaff);
                },
              ),
              const SizedBox(height: 14),
            ],

            // --- DURUM GÜNCELLEME ---
            Text(
              'Arıza Durumu',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: IssueStatus.values.map((status) {
                final selected = _selectedStatus == status;
                final style = styleForStatus(
                  status,
                  Theme.of(context).brightness,
                );
                return ChoiceChip(
                  label: Text(status.label),
                  selected: selected,
                  selectedColor: style.background,
                  labelStyle: TextStyle(
                    color: selected ? style.foreground : null,
                    fontWeight: selected ? FontWeight.bold : null,
                  ),
                  onSelected: (_) => setState(() => _selectedStatus = status),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // --- ÖNCELİK SIRASI ---
            Text(
              'Öncelik Sırası',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: IssuePriority.values.map((priority) {
                final selected = _selectedPriority == priority;
                final style = styleForPriority(
                  priority,
                  Theme.of(context).brightness,
                );
                return ChoiceChip(
                  label: Text(priority.label),
                  avatar: Icon(style.icon, size: 15, color: selected ? style.foreground : null),
                  selected: selected,
                  selectedColor: style.background,
                  labelStyle: TextStyle(
                    color: selected ? style.foreground : null,
                    fontWeight: selected ? FontWeight.bold : null,
                  ),
                  onSelected: (_) => setState(() => _selectedPriority = priority),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // --- YÖNETİCİ NOTU ---
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Resmi Çözüm / Görev Notu',
                hintText:
                'Örn: Ekipler olay yerine sevk edildi, onarım sürüyor.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // --- KAYDET BUTONU ---
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _isSaving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.check),
              label: Text(
                _isSaving ? 'Kaydediliyor...' : 'Görevi Ata & Kaydet',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}