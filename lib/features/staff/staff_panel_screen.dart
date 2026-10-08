import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../home/issue_ui_helpers.dart';
import '../../core/utils/map_launcher.dart';
import '../../core/utils/call_launcher.dart';
import '../../core/models/app_user.dart';
import '../../core/models/team_model.dart';
import '../../core/models/issues_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/issues_provider.dart';
import '../../core/providers/teams_provider.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/constants/neighborhoods_data.dart';
import '../../core/providers/notifications_provider.dart';
import '../auth/change_pin_sheet.dart';
import '../home/notifications_screen.dart';
import 'staff_performance_tab.dart';

/// Personel panelindeki "Aktif Görevlerim" ve "Tamamlananlar" listeleri için
/// seçilen ilçe filtresini tutar (null ise "Tüm İlçeler" demektir).
final _staffDistrictFilterProvider = StateProvider<String?>((ref) => null);

/// Personel panelindeki görev listeleri için seçilen tarih aralığını tutar
/// (null ise "Tüm Zamanlar" demektir). Filtre, işin bildirilme (oluşturulma)
/// tarihine göre uygulanır.
final _staffDateRangeFilterProvider = StateProvider<DateTimeRange?>((ref) => null);

/// Trabzon Büyükşehir Belediyesi Saha Personeli Görev Paneli.
/// Personel sadece kendisine ve ekibine zimmetlenmiş arızaları görür,
/// sahada durum günceller ve resmi çözüm notu ekler.
class StaffPanelScreen extends ConsumerWidget {
  const StaffPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).asData?.value;
    final staffIssuesAsync = ref.watch(staffIssuesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saha Personel Portalı',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                user?.teamName ?? 'Trabzon Büyükşehir Belediyesi',
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
              onPressed: () {
                ref.invalidate(allIssuesProvider);
                ref.invalidate(teamsProvider);
              },
            ),
            IconButton(
              tooltip: 'Çıkış Yap',
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.pending_actions_outlined),
                text: 'Aktif Görevlerim',
              ),
              Tab(
                icon: Icon(Icons.task_alt_outlined),
                text: 'Tamamlananlar',
              ),
              Tab(
                icon: Icon(Icons.insights_outlined),
                text: 'Performansım',
              ),
            ],
          ),
        ),
        body: staffIssuesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Text('Görevler yüklenemedi: $err', style: TextStyle(color: colorScheme.error)),
          ),
          data: (issues) {
            final activeTasks = issues.where((i) => !i.status.isClosed).toList();
            final completedTasks = issues.where((i) => i.status.isClosed).toList();

            return TabBarView(
              children: [
                // 1. Sekme: Aktif Görevler
                _StaffTaskList(
                  tasks: activeTasks,
                  emptyMessage: 'Şu anda üzerinize atanmış bekleyen bir görev bulunmuyor.',
                  emptyIcon: Icons.thumb_up_alt_outlined,
                  isActiveTab: true,
                ),

                // 2. Sekme: Tamamlanan Görevler
                _StaffTaskList(
                  tasks: completedTasks,
                  emptyMessage: 'Henüz tamamlanmış bir görev kaydınız yok.',
                  emptyIcon: Icons.assignment_turned_in_outlined,
                  isActiveTab: false,
                ),

                // 3. Sekme: Kişisel Performans Özeti
                const StaffPerformanceTab(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Görev listesi görünümü
class _StaffTaskList extends ConsumerWidget {
  final List<Issue> tasks;
  final String emptyMessage;
  final IconData emptyIcon;
  final bool isActiveTab;

  const _StaffTaskList({
    required this.tasks,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.isActiveTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider).asData?.value;
    final selectedDistrict = ref.watch(_staffDistrictFilterProvider);
    final selectedDateRange = ref.watch(_staffDateRangeFilterProvider);

    final filteredTasks = tasks.where((issue) {
      if (selectedDistrict != null && issue.district != selectedDistrict) {
        return false;
      }
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
        if (issue.createdAt.isBefore(start) || issue.createdAt.isAfter(end)) {
          return false;
        }
      }
      return true;
    }).toList();

    final hasActiveFilter = selectedDistrict != null || selectedDateRange != null;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(allIssuesProvider);
        ref.invalidate(teamsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Personel Durum & İzin Kartı (Sadece Aktif sekmesinde göster)
          if (isActiveTab && user != null) ...[
            // İlk Giriş / Varsayılan Şifre Uyarısı
            if (user.mustChangePin) ...[
              _MustChangePinWarningCard(user: user),
              const SizedBox(height: 12),
            ],
            _StaffHeaderCard(user: user),
            const SizedBox(height: 16),
          ],

          // İlçe + Tarih Aralığı filtre çipleri
          const _StaffFilterBar(),
          const SizedBox(height: 12),

          if (filteredTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      hasActiveFilter ? Icons.filter_alt_off_outlined : emptyIcon,
                      size: 56,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasActiveFilter
                          ? 'Seçtiğiniz filtrelere uyan bir görev bulunamadı.'
                          : emptyMessage,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...filteredTasks.map((task) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StaffTaskCard(task: task),
            )),
        ],
      ),
    );
  }
}

/// "Varsayılan Şifre Kullanıyorsunuz" Uyarı Kartı
class _MustChangePinWarningCard extends StatelessWidget {
  final AppUser user;

  const _MustChangePinWarningCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade700, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Varsayılan Şifre Kullanıyorsunuz!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Hesabınız varsayılan şifre (1234) ile açılmıştır. Güvenliğiniz için lütfen şifrenizi değiştiriniz.',
            style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => showChangePinSheet(context),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.lock_reset, size: 18),
              label: const Text(
                'Şifremi Şimdi Değiştir',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Aktif Görevlerim" ve "Tamamlananlar" listelerinin üstünde yer alan filtre çip satırı.
class _StaffFilterBar extends ConsumerWidget {
  const _StaffFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDistrict = ref.watch(_staffDistrictFilterProvider);
    final selectedDateRange = ref.watch(_staffDateRangeFilterProvider);
    final hasActiveFilter = selectedDistrict != null || selectedDateRange != null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: const Icon(Icons.location_city, size: 16),
              label: Text(selectedDistrict ?? 'İlçe Filtrele'),
              selected: selectedDistrict != null,
              onSelected: (_) => _showStaffDistrictPicker(context, ref),
            ),
          ),
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
              onSelected: (_) => _pickStaffDateRange(context, ref),
            ),
          ),
          if (hasActiveFilter)
            ActionChip(
              avatar: const Icon(Icons.close, size: 16, color: Colors.red),
              label: const Text(
                'Sıfırla',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                ref.read(_staffDistrictFilterProvider.notifier).state = null;
                ref.read(_staffDateRangeFilterProvider.notifier).state = null;
              },
            ),
        ],
      ),
    );
  }
}

void _showStaffDistrictPicker(BuildContext context, WidgetRef ref) {
  final currentDistrict = ref.read(_staffDistrictFilterProvider);

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
              child: Text('İlçe Seçin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: const Text('Tüm İlçeler'),
                    trailing: currentDistrict == null ? const Icon(Icons.check, color: Colors.blue) : null,
                    onTap: () {
                      ref.read(_staffDistrictFilterProvider.notifier).state = null;
                      Navigator.pop(ctx);
                    },
                  ),
                  ...NeighborhoodsData.districtNames.map((district) {
                    final isSelected = currentDistrict == district;
                    return ListTile(
                      title: Text(district),
                      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                      onTap: () {
                        ref.read(_staffDistrictFilterProvider.notifier).state = district;
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

Future<void> _pickStaffDateRange(BuildContext context, WidgetRef ref) async {
  final currentRange = ref.read(_staffDateRangeFilterProvider);
  final now = DateTime.now();

  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2023),
    lastDate: DateTime(now.year + 2),
    initialDateRange: currentRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    helpText: 'Tarih Aralığı Seçin',
    saveText: 'Filtrele',
    cancelText: 'Vazgeç',
  );

  if (picked != null) {
    ref.read(_staffDateRangeFilterProvider.notifier).state = picked;
  }
}

/// Üst Personel Özet & İzin Kartı (Canlı Firestore Verileriyle)
class _StaffHeaderCard extends ConsumerWidget {
  final AppUser user;

  const _StaffHeaderCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final teamsAsync = ref.watch(teamsProvider);

    Team? myTeam;
    StaffMember? myMember;

    final teams = teamsAsync.valueOrNull ?? [];
    for (final t in teams) {
      for (final m in t.members) {
        final normUserPhone = user.phone.replaceAll(RegExp(r'[^0-9]'), '');
        final normMemPhone = m.phone.replaceAll(RegExp(r'[^0-9]'), '');

        if ((normUserPhone.isNotEmpty && normMemPhone.endsWith(normUserPhone)) ||
            (normUserPhone.isNotEmpty && normUserPhone.endsWith(normMemPhone)) ||
            m.name.trim().toLowerCase() == user.name.trim().toLowerCase()) {
          myTeam = t;
          myMember = m;
          break;
        }
      }
      if (myMember != null) break;
    }

    final isStaffActive = myMember?.isActive ?? true;
    final title = myMember?.title ?? 'Saha Personeli';
    final teamName = myTeam?.name ?? user.teamName ?? 'Trabzon Büyükşehir Ekibi';
    final leaderInfo = myTeam != null ? 'Ekip Amiri: ${myTeam.leaderName}' : null;

    final hasLeaveDates = myMember?.leaveStartDate != null && myMember?.leaveEndDate != null;
    final leaveStartStr = myMember?.leaveStartDate != null
        ? DateFormat('dd.MM.yyyy').format(myMember!.leaveStartDate!)
        : null;
    final leaveEndStr = myMember?.leaveEndDate != null
        ? DateFormat('dd.MM.yyyy').format(myMember!.leaveEndDate!)
        : null;
    final leaveReason = myMember?.leaveReason;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isStaffActive
            ? colorScheme.primaryContainer.withValues(alpha: 0.35)
            : Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isStaffActive
              ? colorScheme.outlineVariant
              : Colors.orange.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isStaffActive ? colorScheme.primary : Colors.orange,
                foregroundColor: Colors.white,
                radius: 26,
                child: Icon(
                  isStaffActive ? Icons.engineering : Icons.pause_circle_outline,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name.isNotEmpty ? user.name : 'Saha Personeli',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$title • $teamName',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                    if (leaderInfo != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        leaderInfo,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isStaffActive
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isStaffActive
                            ? Colors.green.withValues(alpha: 0.4)
                            : Colors.orange.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isStaffActive ? Icons.check_circle : Icons.pause_circle,
                          size: 14,
                          color: isStaffActive ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isStaffActive ? 'Görevde' : 'İzinli',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isStaffActive ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _showStaffProfileModal(
                      context,
                      user: user,
                      member: myMember,
                      team: myTeam,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Detaylar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 14, color: colorScheme.primary),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // İzinli İse Canlı İzin Bilgisi Kutusu
          if (!isStaffActive) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_busy, color: Colors.orange, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Saha İzin Bilgisi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                        if (hasLeaveDates)
                          Text(
                            'Tarih Aralığı: $leaveStartStr - $leaveEndStr',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        if (leaveReason != null && leaveReason.isNotEmpty)
                          Text(
                            'Nedeni: $leaveReason',
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          'Şu anda izinli durumdasınız. Yeni saha arıza atamaları durdurulmuştur.',
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Personelin Kendi Kişisel, İzin ve Şifre Bilgilerini Gösteren Modal
void _showStaffProfileModal(
  BuildContext context, {
  required AppUser user,
  required StaffMember? member,
  required Team? team,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final colorScheme = Theme.of(ctx).colorScheme;
      final isStaffActive = member?.isActive ?? true;
      final hasLeaveDates = member?.leaveStartDate != null && member?.leaveEndDate != null;
      final leaveStartStr = member?.leaveStartDate != null
          ? DateFormat('dd.MM.yyyy').format(member!.leaveStartDate!)
          : '—';
      final leaveEndStr = member?.leaveEndDate != null
          ? DateFormat('dd.MM.yyyy').format(member!.leaveEndDate!)
          : '—';

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.primary,
                    child: const Icon(Icons.badge_outlined, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          member?.title ?? 'Saha Personeli',
                          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 16),

              const Text(
                'Kişisel & Ekip Bilgilerim',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 10),

              _ProfileInfoTile(
                icon: Icons.phone_outlined,
                title: 'Telefon Numarası',
                subtitle: user.phone,
              ),
              _ProfileInfoTile(
                icon: Icons.groups_outlined,
                title: 'Bağlı Olduğu Ekip',
                subtitle: team?.name ?? user.teamName ?? '—',
              ),
              _ProfileInfoTile(
                icon: Icons.domain_outlined,
                title: 'Daire Başkanlığı / Birim',
                subtitle: team?.department ?? '—',
              ),
              if (team != null)
                _ProfileInfoTile(
                  icon: Icons.supervisor_account_outlined,
                  title: 'Ekip Amiri',
                  subtitle: '${team.leaderName} (${team.leaderPhone})',
                ),

              const SizedBox(height: 16),
              const Text(
                'Mevcut Saha & İzin Durumu',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 10),

              Card(
                elevation: 0,
                color: isStaffActive
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isStaffActive
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isStaffActive ? Icons.check_circle : Icons.pause_circle,
                            color: isStaffActive ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isStaffActive
                                ? 'Durum: Görevde (Aktif Sahada)'
                                : 'Durum: İzinli (Saha Dışı)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isStaffActive ? Colors.green[800] : Colors.orange[800],
                            ),
                          ),
                        ],
                      ),
                      if (!isStaffActive) ...[
                        const SizedBox(height: 10),
                        if (hasLeaveDates) ...[
                          Text('• İzin Başlangıç: $leaveStartStr', style: const TextStyle(fontSize: 12)),
                          Text('• İzin Bitiş: $leaveEndStr', style: const TextStyle(fontSize: 12)),
                        ],
                        if (member?.leaveReason != null && member!.leaveReason!.isNotEmpty)
                          Text('• İzin Sebebi: ${member.leaveReason}', style: const TextStyle(fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Güvenlik & Şifre İşlemleri
              const Text(
                'Güvenlik & Şifre İşlemleri',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        showChangePinSheet(context);
                      },
                      icon: const Icon(Icons.lock_reset_outlined, size: 18),
                      label: const Text('Şifre Değiştir'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange[900],
                        side: BorderSide(color: Colors.orange.shade300),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showResetPinConfirmationDialog(context, user: user);
                      },
                      icon: const Icon(Icons.restart_alt_outlined, size: 18),
                      label: const Text('Şifre Sıfırla'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Şifre Sıfırlama Onay Diyaloğu
void _showResetPinConfirmationDialog(
  BuildContext context, {
  required AppUser user,
}) {
  showDialog(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.restart_alt_outlined, color: Colors.orange),
          SizedBox(width: 8),
          Text('Şifre Sıfırlama'),
        ],
      ),
      content: const Text(
        'Şifreniz varsayılan olan "1234" şifresine sıfırlanacaktır. Devam etmek istiyor musunuz?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.orange[800]),
          onPressed: () async {
            Navigator.of(dialogCtx).pop();
            final messenger = ScaffoldMessenger.of(context);
            try {
              final authService = AuthService();
              await authService.resetPinToDefault(user.phone);
              messenger.showSnackBar(
                SnackBar(
                  content: const Text(
                    'Şifreniz varsayılana (1234) sıfırlandı. Yeni şifreniz: 1234',
                  ),
                  backgroundColor: Colors.green[800],
                ),
              );
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(content: Text('Şifre sıfırlama başarısız: $e')),
              );
            }
          },
          child: const Text('Şifreyi Sıfırla (1234)'),
        ),
      ],
    ),
  );
}

class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ProfileInfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Saha Görev Kartı
class _StaffTaskCard extends ConsumerWidget {
  final Issue task;

  const _StaffTaskCard({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusStyle = styleForStatus(task.status, Theme.of(context).brightness);
    final priorityStyle = styleForPriority(task.priority, Theme.of(context).brightness);
    final formattedDate = DateFormat('dd.MM.yyyy HH:mm').format(task.createdAt);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Satır: Kategori & Durum Rozeti
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.primary,
                  child: Icon(iconForCategory(task.category), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.category.label,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        '${task.district} / ${task.neighborhood}',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusStyle.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        task.status.label,
                        style: TextStyle(
                          color: statusStyle.foreground,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (task.priority != IssuePriority.normal) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: priorityStyle.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(priorityStyle.icon, size: 11, color: priorityStyle.foreground),
                            const SizedBox(width: 3),
                            Text(
                              task.priority.label,
                              style: TextStyle(
                                color: priorityStyle.foreground,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Varsa Fotoğraf
            if (task.photoUrl != null && task.photoUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  task.photoUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Personelin yüklediği öncesi/sonrası fotoğraf ve video
            if ((task.beforePhotoUrl != null && task.beforePhotoUrl!.isNotEmpty) ||
                (task.afterPhotoUrl != null && task.afterPhotoUrl!.isNotEmpty) ||
                (task.videoUrl != null && task.videoUrl!.isNotEmpty)) ...[
              _StaffMediaPreview(task: task),
              const SizedBox(height: 10),
            ],

            // Açıklama
            Text(
              task.description,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 8),

            // Adres Detayı
            if (task.addressDetail != null && task.addressDetail!.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 15, color: colorScheme.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      task.addressDetail!,
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            // Varsa Belediye Notu
            if (task.assignedNote != null && task.assignedNote!.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Not: ${task.assignedNote}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Bildiren Vatandaş ve Tarih
            Text(
              'Bildiren: ${task.reporterName} • $formattedDate',
              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 12),

            // Alt İşlem Butonları
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => CallLauncher.call(
                      context: context,
                      phone: task.reporterPhone,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Icon(Icons.call_outlined, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => MapLauncher.openMap(
                      context: context,
                      latitude: task.latitude,
                      longitude: task.longitude,
                      district: task.district,
                      neighborhood: task.neighborhood,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.navigation_outlined, size: 18),
                    label: const Text('Yol Tarifi', overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _showStaffTaskModal(context, task),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.handyman_outlined, size: 18),
                    label: Text(
                      task.status == IssueStatus.cozuldu ? 'Çözüm Notu' : 'Müdahale Et',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Görev kartında personelin yüklediği "öncesi/sonrası" fotoğrafları ve
/// varsa videoyu küçük önizlemeler halinde gösterir.
class _StaffMediaPreview extends StatelessWidget {
  final Issue task;

  const _StaffMediaPreview({required this.task});

  Widget _thumb(BuildContext context, {required String label, required String url}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              height: 90,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasBefore = task.beforePhotoUrl != null && task.beforePhotoUrl!.isNotEmpty;
    final hasAfter = task.afterPhotoUrl != null && task.afterPhotoUrl!.isNotEmpty;
    final hasVideo = task.videoUrl != null && task.videoUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasBefore || hasAfter)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasBefore) _thumb(context, label: 'ÖNCESİ', url: task.beforePhotoUrl!),
              if (hasBefore && hasAfter) const SizedBox(width: 8),
              if (hasAfter) _thumb(context, label: 'SONRASI', url: task.afterPhotoUrl!),
            ],
          ),
        if (hasVideo) ...[
          if (hasBefore || hasAfter) const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(task.videoUrl!), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('Müdahale Videosunu Aç'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              minimumSize: const Size(double.infinity, 0),
            ),
          ),
        ],
      ],
    );
  }
}

class _MediaPickerTile extends StatelessWidget {
  final String label;
  final String? existingUrl;
  final XFile? pickedFile;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _MediaPickerTile({
    required this.label,
    required this.existingUrl,
    required this.pickedFile,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasExisting = existingUrl != null && existingUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onPick,
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: pickedFile != null
                    ? Image.file(File(pickedFile!.path), height: 110, width: double.infinity, fit: BoxFit.cover)
                    : hasExisting
                    ? Image.network(existingUrl!, height: 110, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _emptyBox(colorScheme))
                    : _emptyBox(colorScheme),
              ),
              if (pickedFile != null)
                IconButton.filled(
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 16),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    minimumSize: const Size(28, 28),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyBox(ColorScheme colorScheme) {
    return Container(
      height: 110,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Icon(Icons.add_a_photo_outlined, color: colorScheme.onSurfaceVariant),
    );
  }
}

void _showStaffTaskModal(BuildContext context, Issue task) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _StaffTaskModalContent(task: task),
  );
}

class _StaffTaskModalContent extends ConsumerStatefulWidget {
  final Issue task;

  const _StaffTaskModalContent({required this.task});

  @override
  ConsumerState<_StaffTaskModalContent> createState() => _StaffTaskModalContentState();
}

class _StaffTaskModalContentState extends ConsumerState<_StaffTaskModalContent> {
  late IssueStatus _selectedStatus;
  late final TextEditingController _noteController;
  bool _isSaving = false;

  XFile? _beforeImage;
  XFile? _afterImage;
  XFile? _pickedVideo;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.task.status;
    _noteController = TextEditingController(text: widget.task.assignedNote ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto({required bool isBefore}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera ile çek'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1600);
    if (picked != null && mounted) {
      setState(() {
        if (isBefore) {
          _beforeImage = picked;
        } else {
          _afterImage = picked;
        }
      });
    }
  }

  Future<void> _pickVideo() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Kamera ile çek'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 3),
    );
    if (picked != null && mounted) {
      setState(() => _pickedVideo = picked);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final actorName = ref.read(authControllerProvider).asData?.value?.name;

      String? beforePhotoUrl;
      if (_beforeImage != null) {
        beforePhotoUrl = await CloudinaryService().uploadImage(File(_beforeImage!.path));
      }
      String? afterPhotoUrl;
      if (_afterImage != null) {
        afterPhotoUrl = await CloudinaryService().uploadImage(File(_afterImage!.path));
      }
      String? videoUrl;
      if (_pickedVideo != null) {
        videoUrl = await CloudinaryService().uploadVideo(File(_pickedVideo!.path));
      }

      await updateIssueStatus(
        issueId: widget.task.id,
        status: _selectedStatus,
        assignedNote: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        actorName: actorName,
        beforePhotoUrl: beforePhotoUrl,
        afterPhotoUrl: afterPhotoUrl,
        videoUrl: videoUrl,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Görev durumu ve çözüm notu başarıyla güncellendi.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(iconForCategory(task.category), color: colorScheme.primary, size: 24),
                const SizedBox(width: 10),
                Text(
                  task.category.label,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${task.district} / ${task.neighborhood}',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const Divider(height: 24),

            // Durum Seçimi
            const Text(
              'Müdahale Durumu',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Yolda'),
                  avatar: const Icon(Icons.directions_car_filled_outlined, size: 16),
                  selected: _selectedStatus == IssueStatus.yolda,
                  onSelected: (_) => setState(() => _selectedStatus = IssueStatus.yolda),
                ),
                ChoiceChip(
                  label: const Text('Başladı (Sahadayım)'),
                  avatar: const Icon(Icons.handyman_outlined, size: 16),
                  selected: _selectedStatus == IssueStatus.basladi,
                  onSelected: (_) => setState(() => _selectedStatus = IssueStatus.basladi),
                ),
                ChoiceChip(
                  label: const Text('Tamamlandı'),
                  avatar: const Icon(Icons.check_circle_outline, size: 16),
                  selected: _selectedStatus == IssueStatus.cozuldu,
                  onSelected: (_) => setState(() => _selectedStatus = IssueStatus.cozuldu),
                ),
                ChoiceChip(
                  label: const Text('Ertelendi'),
                  avatar: const Icon(Icons.schedule_outlined, size: 16),
                  selected: _selectedStatus == IssueStatus.ertelendi,
                  onSelected: (_) => setState(() => _selectedStatus = IssueStatus.ertelendi),
                ),
                ChoiceChip(
                  label: const Text('İptal'),
                  avatar: const Icon(Icons.cancel_outlined, size: 16),
                  selected: _selectedStatus == IssueStatus.iptal,
                  onSelected: (_) => setState(() => _selectedStatus = IssueStatus.iptal),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Çözüm Notu
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Saha Çözüm / Müdahale Notu',
                hintText: 'Örn: Patlak boru kaynaklandı, su şebekeye verildi.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Müdahale Öncesi/Sonrası Fotoğraf ve Video
            const Text(
              'Müdahale Fotoğrafları (opsiyonel)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MediaPickerTile(
                    label: 'Öncesi',
                    existingUrl: task.beforePhotoUrl,
                    pickedFile: _beforeImage,
                    onPick: () => _pickPhoto(isBefore: true),
                    onClear: () => setState(() => _beforeImage = null),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MediaPickerTile(
                    label: 'Sonrası',
                    existingUrl: task.afterPhotoUrl,
                    pickedFile: _afterImage,
                    onPick: () => _pickPhoto(isBefore: false),
                    onClear: () => setState(() => _afterImage = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickVideo,
              icon: Icon(_pickedVideo == null ? Icons.videocam_outlined : Icons.check_circle_outline),
              label: Text(
                _pickedVideo == null
                    ? (task.videoUrl != null && task.videoUrl!.isNotEmpty
                    ? 'Video Değiştir'
                    : 'Video Ekle (opsiyonel)')
                    : 'Video Seçildi (${_pickedVideo!.name})',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(double.infinity, 0),
              ),
            ),
            const SizedBox(height: 20),

            // Geçmiş Kayıtlar
            if (task.history.isNotEmpty) ...[
              const Text(
                'Geçmiş Kayıtlar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Scrollbar(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: task.history.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (context, index) {
                      final entry = task.history.reversed.toList()[index];
                      final entryDate = DateFormat('dd.MM.yyyy HH:mm').format(entry.timestamp);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.status.label,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                                Text(
                                  entryDate,
                                  style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                            if (entry.actorName != null && entry.actorName!.isNotEmpty)
                              Text(
                                entry.actorName!,
                                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                              ),
                            if (entry.note != null && entry.note!.isNotEmpty)
                              Text(
                                entry.note!,
                                style: const TextStyle(fontSize: 11),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Kaydet Butonu
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Değişiklikleri Kaydet & Gönder'),
            ),
          ],
        ),
      ),
    );
  }
}