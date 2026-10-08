import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/issues_model.dart';
import '../../core/models/team_model.dart';
import '../../core/providers/issues_provider.dart';
import '../../core/providers/teams_provider.dart';
import '../home/issue_ui_helpers.dart';

/// Bir ekibin personellerini ve o ekibe atanmış görev havuzunu gösteren detay sayfası.
class TeamDetailSheet extends ConsumerWidget {
  final Team team;
  final Function(Issue issue)? onSelectIssue;

  const TeamDetailSheet({
    super.key,
    required this.team,
    this.onSelectIssue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    // Sayfa açıldığında gelen `team` sabit bir anlık görüntüdür; canlı
    // güncellemeleri yansıtmak için Firestore'dan gelen güncel ekibi kullanıyoruz.
    final teamsAsync = ref.watch(teamsProvider);
    final team = findTeamById(teamsAsync.valueOrNull ?? [], this.team.id) ??
        this.team;
    final assignedIssues = ref.watch(teamIssuesProvider(team.id));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(team.name),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.people_outline),
                text: 'Personeller (${team.members.length})',
              ),
              Tab(
                icon: const Icon(Icons.assignment_outlined),
                text: 'Görev Havuzu (${assignedIssues.length})',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 1. Sekme: Personel Kadrosu
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Ekip Özeti Kartı (Ekip Amiri bilgisi ve Düzenle Butonu)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: team.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: team.color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: team.color,
                        foregroundColor: Colors.white,
                        radius: 24,
                        child: Icon(team.icon, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              team.department,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ekip Amiri: ${team.leaderName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              team.leaderPhone,
                              style: TextStyle(
                                fontSize: 12,
                                color: team.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: team.color),
                        tooltip: 'Ekip Amirini Düzenle',
                        onPressed: () => _showEditLeaderBottomSheet(
                          context: context,
                          team: team,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Personel Başlığı & "Personel Ekle" Butonu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saha Personelleri',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Dokunarak durum değiştirebilir veya düzenleyebilirsiniz',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _showStaffFormBottomSheet(
                        context: context,
                        team: team,
                        staff: null,
                      ),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: const Text(
                        'Personel Ekle',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Personel Kartları Listesi
                if (team.members.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.group_off_outlined,
                          size: 40,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bu ekipte henüz kayıtlı personel bulunmuyor.',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _showStaffFormBottomSheet(
                            context: context,
                            team: team,
                            staff: null,
                          ),
                          icon: const Icon(Icons.person_add_outlined, size: 18),
                          label: const Text('İlk Personeli Ekle'),
                        ),
                      ],
                    ),
                  )
                else
                  ...team.members.map((member) {
                    final isStaffActive = member.isActive;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                          child: Text(
                            member.name.isNotEmpty ? member.name[0] : 'P',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          member.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${member.title} • ${member.phone}'),
                            if (!isStaffActive &&
                                (member.leaveStartDate != null ||
                                    member.leaveReason != null)) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(Icons.event_note,
                                      size: 12, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'İzin: ${member.leaveStartDate != null && member.leaveEndDate != null ? "${DateFormat('dd.MM').format(member.leaveStartDate!)} - ${DateFormat('dd.MM.yyyy').format(member.leaveEndDate!)}" : ""}${member.leaveReason != null && member.leaveReason!.isNotEmpty ? " (${member.leaveReason})" : ""}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Aktif/İzinli Rozeti
                            InkWell(
                              onTap: () async {
                                if (isStaffActive) {
                                  // Görevde -> İzinli yapma modalını aç
                                  _showLeaveDatePickerDialog(
                                    context: context,
                                    team: team,
                                    staff: member,
                                  );
                                } else {
                                  // İzinli -> Görevde yap
                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    await updateStaffActiveStatus(
                                      teamId: team.id,
                                      staffId: member.id,
                                      isActive: true,
                                    );
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${member.name} tekrar Görevde olarak güncellendi.',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Durum güncellenemedi: $e'),
                                      ),
                                    );
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
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
                                      isStaffActive
                                          ? Icons.check_circle_outline
                                          : Icons.pause_circle_outline,
                                      size: 14,
                                      color: isStaffActive
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isStaffActive ? 'Görevde' : 'İzinli',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isStaffActive
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),

                            // Düzenle Butonu
                            IconButton(
                              icon: Icon(
                                Icons.edit_outlined,
                                size: 20,
                                color: colorScheme.primary,
                              ),
                              tooltip: 'Personeli Düzenle',
                              onPressed: () => _showStaffFormBottomSheet(
                                context: context,
                                team: team,
                                staff: member,
                              ),
                            ),

                            // Sil Butonu
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: colorScheme.error,
                              ),
                              tooltip: 'Personeli Sil',
                              onPressed: () => _showDeleteConfirmationDialog(
                                context: context,
                                team: team,
                                staff: member,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),

            // 2. Sekme: Ekibe Atanmış Görevler Havuzu
            assignedIssues.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.green.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aktif Görev Bulunmuyor',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bu ekibe atanmış ve çözüm bekleyen arıza yok.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: assignedIssues.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final issue = assignedIssues[index];
                final statusStyle = styleForStatus(
                  issue.status,
                  Theme.of(context).brightness,
                );
                final formattedDate = DateFormat('dd.MM.yyyy HH:mm')
                    .format(issue.createdAt);

                return InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    if (onSelectIssue != null) {
                      onSelectIssue!(issue);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${issue.category.label}, ${issue.district}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
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
                          issue.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (issue.assignedStaffName != null) ...[
                              Icon(
                                Icons.person_pin_outlined,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Zimmetli: ${issue.assignedStaffName}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                            ],
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Personeli Hızlı İzinli Yapma ve Tarih / Sebep Seçme Diyaloğu
void _showLeaveDatePickerDialog({
  required BuildContext context,
  required Team team,
  required StaffMember staff,
}) {
  DateTimeRange? selectedRange;
  final reasonController = TextEditingController();

  showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (context, setDialogState) {
        final startStr = selectedRange != null
            ? DateFormat('dd.MM.yyyy').format(selectedRange!.start)
            : null;
        final endStr = selectedRange != null
            ? DateFormat('dd.MM.yyyy').format(selectedRange!.end)
            : null;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.pause_circle_outline, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${staff.name} - İzin Tanımla',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Personelin izinli olacağı tarih aralığını ve izin nedenini belirleyebilirsiniz.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 2),
                      initialDateRange: selectedRange ??
                          DateTimeRange(
                            start: now,
                            end: now.add(const Duration(days: 7)),
                          ),
                      helpText: 'İzin Tarih Aralığı Seçin',
                      saveText: 'Seç',
                    );
                    if (picked != null) {
                      setDialogState(() => selectedRange = picked);
                    }
                  },
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    selectedRange != null
                        ? '$startStr - $endStr'
                        : 'İzin Tarih Aralığı Seç (İsteğe Bağlı)',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'İzin Sebebi (İsteğe Bağlı)',
                    hintText: 'Örn: Yıllık İzin, Raporlu vb.',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
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
                  await updateStaffActiveStatus(
                    teamId: team.id,
                    staffId: staff.id,
                    isActive: false,
                    leaveStartDate: selectedRange?.start,
                    leaveEndDate: selectedRange?.end,
                    leaveReason: reasonController.text.trim().isEmpty
                        ? null
                        : reasonController.text.trim(),
                  );
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('${staff.name} durumu "İzinli" olarak güncellendi.'),
                      backgroundColor: Colors.green[800],
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Durum güncellenemedi: $e')),
                  );
                }
              },
              child: const Text('İzinli Olarak Kaydet'),
            ),
          ],
        );
      },
    ),
  );
}

/// Ekip Amirini Düzenleme Modal Açıcı
void _showEditLeaderBottomSheet({
  required BuildContext context,
  required Team team,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _EditLeaderBottomSheetContent(team: team),
  );
}

/// Personel Ekleme ve Düzenleme Modal Form Açıcı
void _showStaffFormBottomSheet({
  required BuildContext context,
  required Team team,
  StaffMember? staff,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _StaffFormBottomSheetContent(team: team, staff: staff),
  );
}

/// Personel Silme Onay Diyaloğu
void _showDeleteConfirmationDialog({
  required BuildContext context,
  required Team team,
  required StaffMember staff,
}) {
  showDialog(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('Personel Silinsin mi?'),
        ],
      ),
      content: Text(
        '${staff.name} (${staff.title}) personeli "${team.name}" kadrosundan tamamen çıkarılacaktır. Bu işlem geri alınamaz.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            Navigator.of(dialogCtx).pop();
            final messenger = ScaffoldMessenger.of(context);
            try {
              await deleteStaffMember(teamId: team.id, staffId: staff.id);
              messenger.showSnackBar(
                SnackBar(
                  content: Text('${staff.name} kadrodan çıkarıldı.'),
                  backgroundColor: Colors.green[800],
                ),
              );
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(content: Text('Personel silinirken sorun oluştu: $e')),
              );
            }
          },
          child: const Text('Sil'),
        ),
      ],
    ),
  );
}

/// Ekip Amiri Düzenleme Bottom Sheet Form İçeriği
class _EditLeaderBottomSheetContent extends StatefulWidget {
  final Team team;

  const _EditLeaderBottomSheetContent({required this.team});

  @override
  State<_EditLeaderBottomSheetContent> createState() =>
      _EditLeaderBottomSheetContentState();
}

class _EditLeaderBottomSheetContentState
    extends State<_EditLeaderBottomSheetContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _leaderNameController;
  late final TextEditingController _leaderPhoneController;
  StaffMember? _selectedStaffForLeader;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _leaderNameController =
        TextEditingController(text: widget.team.leaderName);
    _leaderPhoneController =
        TextEditingController(text: widget.team.leaderPhone);
  }

  @override
  void dispose() {
    _leaderNameController.dispose();
    _leaderPhoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await updateTeamLeader(
        teamId: widget.team.id,
        leaderName: _leaderNameController.text.trim(),
        leaderPhone: _leaderPhoneController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${widget.team.name} ekip amiri "${_leaderNameController.text.trim()}" olarak güncellendi.',
            ),
            backgroundColor: Colors.green[800],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Güncelleme başarısız oldu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: widget.team.color.withValues(alpha: 0.15),
                    foregroundColor: widget.team.color,
                    child: const Icon(Icons.star_outline, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ekip Amirini Düzenle',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.team.name,
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
              const SizedBox(height: 20),

              // Kadrodan Seçme Opsiyonu
              if (widget.team.members.isNotEmpty) ...[
                DropdownButtonFormField<StaffMember?>(
                  initialValue: _selectedStaffForLeader,
                  decoration: const InputDecoration(
                    labelText: 'Mevcut Kadrodan Seç (İsteğe Bağlı)',
                    prefixIcon: Icon(Icons.people_outline),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Manuel / Yeni Giriş Yap'),
                    ),
                    ...widget.team.members.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text('${m.name} (${m.title})'),
                      );
                    }),
                  ],
                  onChanged: (selected) {
                    setState(() {
                      _selectedStaffForLeader = selected;
                      if (selected != null) {
                        _leaderNameController.text = selected.name;
                        _leaderPhoneController.text = selected.phone;
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),
              ],

              // Ekip Amiri Adı Soyadı
              TextFormField(
                controller: _leaderNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Ekip Amiri Adı Soyadı',
                  hintText: 'Örn: Murat Kara',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Lütfen ekip amirinin adını ve soyadını giriniz.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Ekip Amiri Telefonu
              TextFormField(
                controller: _leaderPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Ekip Amiri Telefonu',
                  hintText: 'Örn: 0462 300 00 01',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Lütfen telefon numarası giriniz.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Kaydet Butonu
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
                  _isSaving ? 'Kaydediliyor...' : 'Ekip Amirini Kaydet',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Personel Ekle / Düzenle Bottom Sheet Form İçeriği
class _StaffFormBottomSheetContent extends StatefulWidget {
  final Team team;
  final StaffMember? staff;

  const _StaffFormBottomSheetContent({
    required this.team,
    this.staff,
  });

  @override
  State<_StaffFormBottomSheetContent> createState() =>
      _StaffFormBottomSheetContentState();
}

class _StaffFormBottomSheetContentState
    extends State<_StaffFormBottomSheetContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _titleController;
  late final TextEditingController _phoneController;
  late final TextEditingController _leaveReasonController;
  late bool _isActive;

  DateTime? _leaveStartDate;
  DateTime? _leaveEndDate;
  bool _isSaving = false;

  bool get isEditing => widget.staff != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.staff?.name ?? '');
    _titleController = TextEditingController(text: widget.staff?.title ?? '');
    _phoneController = TextEditingController(text: widget.staff?.phone ?? '');
    _leaveReasonController =
        TextEditingController(text: widget.staff?.leaveReason ?? '');
    _isActive = widget.staff?.isActive ?? true;
    _leaveStartDate = widget.staff?.leaveStartDate;
    _leaveEndDate = widget.staff?.leaveEndDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _phoneController.dispose();
    _leaveReasonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (isEditing) {
        await updateStaffMember(
          teamId: widget.team.id,
          staffId: widget.staff!.id,
          name: _nameController.text.trim(),
          title: _titleController.text.trim(),
          phone: _phoneController.text.trim(),
          isActive: _isActive,
          leaveStartDate: _isActive ? null : _leaveStartDate,
          leaveEndDate: _isActive ? null : _leaveEndDate,
          leaveReason: _isActive ? null : _leaveReasonController.text.trim(),
        );
      } else {
        await addStaffMember(
          teamId: widget.team.id,
          name: _nameController.text.trim(),
          title: _titleController.text.trim(),
          phone: _phoneController.text.trim(),
          isActive: _isActive,
          leaveStartDate: _isActive ? null : _leaveStartDate,
          leaveEndDate: _isActive ? null : _leaveEndDate,
          leaveReason: _isActive ? null : _leaveReasonController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? '${_nameController.text.trim()} bilgileri güncellendi.'
                  : '${_nameController.text.trim()} ekibe eklendi.',
            ),
            backgroundColor: Colors.green[800],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('İşlem başarısız oldu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final startStr = _leaveStartDate != null
        ? DateFormat('dd.MM.yyyy').format(_leaveStartDate!)
        : null;
    final endStr = _leaveEndDate != null
        ? DateFormat('dd.MM.yyyy').format(_leaveEndDate!)
        : null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.primary,
                    child: Icon(
                      isEditing ? Icons.edit_outlined : Icons.person_add_outlined,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Personeli Düzenle' : 'Yeni Personel Ekle',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.team.name} Kadrosu',
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
              const SizedBox(height: 20),

              // Ad Soyad
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Ad Soyad',
                  hintText: 'Örn: Ahmet Yılmaz',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Lütfen ad soyad giriniz.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Unvan / Görev
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Unvan / Görev',
                  hintText: 'Örn: Tesisat Teknisyeni, Ekip Amiri vb.',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Lütfen görev/unvan giriniz.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Telefon Numarası
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefon Numarası',
                  hintText: 'Örn: 0532 111 22 33',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Lütfen telefon numarası giriniz.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Görev Durumu (Aktif / İzinli)
              Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  title: const Text(
                    'Personel Durumu',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _isActive
                        ? 'Görevde (Yeni arızalara atanabilir)'
                        : 'İzinli / Pasif (Geçici olarak sahada değil)',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isActive ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                ),
              ),

              // İzinli Yapıldığında Tarih ve Sebep Alanları
              if (!_isActive) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 2),
                      initialDateRange: _leaveStartDate != null && _leaveEndDate != null
                          ? DateTimeRange(start: _leaveStartDate!, end: _leaveEndDate!)
                          : DateTimeRange(
                              start: now,
                              end: now.add(const Duration(days: 7)),
                            ),
                      helpText: 'İzin Tarih Aralığı Seçin',
                      saveText: 'Seç',
                    );
                    if (picked != null) {
                      setState(() {
                        _leaveStartDate = picked.start;
                        _leaveEndDate = picked.end;
                      });
                    }
                  },
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    _leaveStartDate != null && _leaveEndDate != null
                        ? 'İzin Tarihi: $startStr - $endStr'
                        : 'İzin Tarih Aralığı Seç (İsteğe Bağlı)',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _leaveReasonController,
                  decoration: const InputDecoration(
                    labelText: 'İzin Sebebi (İsteğe Bağlı)',
                    hintText: 'Örn: Yıllık İzin, Raporlu, Mazeret İzni',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Kaydet / Ekle Butonu
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
                    : Icon(isEditing ? Icons.check : Icons.add),
                label: Text(
                  _isSaving
                      ? 'Kaydediliyor...'
                      : (isEditing ? 'Değişiklikleri Kaydet' : 'Personeli Ekle'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}