import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/issues_model.dart';

/// Arızanın yaşam döngüsünü (Bildirildi -> Ekibe Sevk Edildi -> Saha Müdahalesi -> Çözüldü)
/// kargo takip mantığıyla adım adım gösteren zaman çizelgesi (Timeline) bileşeni.
class IssueTimelineWidget extends StatelessWidget {
  final Issue issue;

  const IssueTimelineWidget({super.key, required this.issue});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final createdDate = DateFormat('dd.MM.yyyy HH:mm').format(issue.createdAt);
    final updatedDate = DateFormat('dd.MM.yyyy HH:mm').format(issue.updatedAt);

    // Adım 1: Bildirim Alındı (Her zaman tamamlanmış)
    final step1Done = true;

    // Adım 2: Ekibe Atandı (Ekip bilgisi varsa veya durum beklemede değilse)
    final hasTeam = issue.assignedTeamName != null && issue.assignedTeamName!.isNotEmpty;
    final step2Done = hasTeam || issue.status != IssueStatus.beklemede;

    // Adım 3: Saha Müdahalesi (yolda/başladı/işleme alındı veya tamamlandı ise)
    final step3Done = issue.status.isClosed;
    final step3Active = issue.status == IssueStatus.islemeAlindi ||
        issue.status == IssueStatus.yolda ||
        issue.status == IssueStatus.basladi;

    // Adım 4: Tamamlandı & Kapatıldı (iptal edilen kayıtlar da kapanmış sayılır)
    final step4Done = issue.status.isClosed;
    final isCancelled = issue.status == IssueStatus.iptal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Arıza Takip Süreç Çizelgesi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. ADIM: Bildirim Alındı
          _TimelineItem(
            isDone: step1Done,
            isActive: false,
            isLast: false,
            icon: Icons.check,
            title: 'Bildirim Kaydedildi',
            subtitle: 'Sistem kaydı açıldı, belediye havuzuna iletildi.',
            time: createdDate,
          ),

          // 2. ADIM: İnceleme & Ekip Sevk
          _TimelineItem(
            isDone: step2Done,
            isActive: !step2Done && issue.status == IssueStatus.beklemede,
            isLast: false,
            icon: step2Done ? Icons.check : Icons.hourglass_top,
            title: hasTeam ? 'Ekibe Sevk Edildi' : 'İnceleme & Ekip Atama',
            subtitle: hasTeam
                ? '${issue.assignedTeamName}${issue.assignedStaffName != null ? ' (${issue.assignedStaffName})' : ''}'
                : 'Yetkili birim görevlendirmesi bekleniyor.',
            time: hasTeam ? updatedDate : null,
          ),

          // 3. ADIM: Saha Müdahalesi
          _TimelineItem(
            isDone: step3Done,
            isActive: step3Active,
            isLast: false,
            icon: step3Done
                ? Icons.check
                : (step3Active ? Icons.handyman : Icons.engineering_outlined),
            title: 'Saha Müdahalesi & Onarım',
            subtitle: step3Done
                ? 'Saha ekipleri onarım çalışmasını tamamladı.'
                : (step3Active
                ? 'Ekipler adreste inceleme ve onarım çalışmasına başladı.'
                : 'Ekip olay yerine intikal edecek.'),
            time: step3Active ? updatedDate : null,
          ),

          // 4. ADIM: Tamamlandı & Kapatıldı
          _TimelineItem(
            isDone: step4Done,
            isActive: false,
            isLast: true,
            icon: isCancelled
                ? Icons.cancel_outlined
                : (step4Done ? Icons.verified : Icons.flag_outlined),
            title: isCancelled
                ? 'Kayıt İptal Edildi'
                : (step4Done ? 'Arıza Giderildi & Kapatıldı' : 'Sonuçlandırma'),
            subtitle: step4Done
                ? (issue.assignedNote != null && issue.assignedNote!.isNotEmpty
                ? '${isCancelled ? 'İptal Notu' : 'Çözüm Notu'}: ${issue.assignedNote}'
                : (isCancelled ? 'Kayıt iptal edildi.' : 'Kayıt başarıyla çözümlendi.'))
                : 'Onarım tamamlandıktan sonra sonuç bildirilecek.',
            time: step4Done ? updatedDate : null,
            issue: issue, // Medya gösterimi için ekliyoruz
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final bool isDone;
  final bool isActive;
  final bool isLast;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? time;
  final Issue? issue;

  const _TimelineItem({
    required this.isDone,
    required this.isActive,
    required this.isLast,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.time,
    this.issue,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color nodeColor;
    Color iconColor;
    if (isDone) {
      nodeColor = Colors.green;
      iconColor = Colors.white;
    } else if (isActive) {
      nodeColor = colorScheme.primary;
      iconColor = Colors.white;
    } else {
      nodeColor = colorScheme.outlineVariant;
      iconColor = colorScheme.onSurfaceVariant;
    }

    final hasMedia = issue != null &&
        ((issue!.beforePhotoUrl != null && issue!.beforePhotoUrl!.isNotEmpty) ||
         (issue!.afterPhotoUrl != null && issue!.afterPhotoUrl!.isNotEmpty));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sol: Yuvarlak Düğüm ve Dikey Çizgi
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: nodeColor,
                  shape: BoxShape.circle,
                  boxShadow: isActive
                      ? [
                    BoxShadow(
                      color: nodeColor.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ]
                      : null,
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDone ? Colors.green : colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Sağ: Açıklama ve Tarih
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDone || isActive
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (time != null)
                        Text(
                          time!,
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                  if (isLast && isDone && hasMedia) ...[
                    const SizedBox(height: 8),
                    _VatandasMediaPreview(issue: issue!),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vatandaşın göreceği "Öncesi / Sonrası" medya bileşeni
class _VatandasMediaPreview extends StatelessWidget {
  final Issue issue;

  const _VatandasMediaPreview({required this.issue});

  Widget _thumb(BuildContext context, {required String label, required String url}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              // Tam ekran resmi göstermek için modal
              showDialog(
                context: context,
                builder: (_) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(10),
                  child: InteractiveViewer(
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasBefore = issue.beforePhotoUrl != null && issue.beforePhotoUrl!.isNotEmpty;
    final hasAfter = issue.afterPhotoUrl != null && issue.afterPhotoUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasBefore) _thumb(context, label: 'ÖNCESİ', url: issue.beforePhotoUrl!),
          if (hasBefore && hasAfter) const SizedBox(width: 8),
          if (hasAfter) _thumb(context, label: 'SONRASI', url: issue.afterPhotoUrl!),
        ],
      ),
    );
  }
}