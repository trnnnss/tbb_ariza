import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/issues_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/issues_provider.dart';

/// Personelin kendi performansını görebileceği dönem filtresi.
enum _PerfPeriod { hafta, ay, tumu }

extension on _PerfPeriod {
  String get label {
    switch (this) {
      case _PerfPeriod.hafta:
        return 'Bu Hafta';
      case _PerfPeriod.ay:
        return 'Bu Ay';
      case _PerfPeriod.tumu:
        return 'Tüm Zamanlar';
    }
  }
}

/// Bu personel tarafından "çözüldü" olarak işaretlenmiş tek bir işin,
/// performans hesaplaması için gereken özet bilgisi.
class _CompletedByMe {
  final Issue issue;
  final DateTime completedAt;
  final Duration resolutionTime;

  _CompletedByMe({
    required this.issue,
    required this.completedAt,
    required this.resolutionTime,
  });
}

/// "Personel Portalı"ndaki 3. sekme: kendi tamamladığı iş sayısı, ortalama
/// çözüm süresi ve kategoriye göre dağılımı gösteren kişisel özet ekranı.
///
/// Ekstra bir Firestore sorgusu/index gerektirmez: zaten canlı olarak
/// dinlenen `allIssuesProvider` verisi üzerinden, her işin `history`
/// listesindeki "kim, ne zaman çözüldü yaptı" kayıtlarına bakarak
/// istemci tarafında (client-side) hesaplama yapar. Bu sayede bir iş
/// ekibe atanmış olsa bile, gerçekte "çözüldü" durumuna kimin geçirdiği
/// doğru şekilde bu personele atfedilir.
class StaffPerformanceTab extends ConsumerStatefulWidget {
  const StaffPerformanceTab({super.key});

  @override
  ConsumerState<StaffPerformanceTab> createState() => _StaffPerformanceTabState();
}

class _StaffPerformanceTabState extends ConsumerState<StaffPerformanceTab> {
  _PerfPeriod _period = _PerfPeriod.ay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider).asData?.value;
    final allIssuesAsync = ref.watch(allIssuesProvider);

    if (user == null) {
      return const SizedBox();
    }

    return allIssuesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('Veriler yüklenemedi: $err', style: TextStyle(color: colorScheme.error)),
      ),
      data: (issues) {
        final completed = _extractCompletedByMe(issues, user.name);
        final filtered = _filterByPeriod(completed, _period);

        final totalCount = filtered.length;
        final avgDuration = filtered.isEmpty
            ? null
            : Duration(
          milliseconds: (filtered
              .map((e) => e.resolutionTime.inMilliseconds)
              .reduce((a, b) => a + b) /
              filtered.length)
              .round(),
        );

        final categoryCounts = <IssueCategory, int>{};
        for (final c in filtered) {
          categoryCounts[c.issue.category] = (categoryCounts[c.issue.category] ?? 0) + 1;
        }
        final sortedCategories = categoryCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allIssuesProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Dönem seçimi
              SegmentedButton<_PerfPeriod>(
                segments: _PerfPeriod.values
                    .map((p) => ButtonSegment(value: p, label: Text(p.label)))
                    .toList(),
                selected: {_period},
                onSelectionChanged: (selection) => setState(() => _period = selection.first),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.task_alt,
                      label: 'Tamamlanan İş',
                      value: '$totalCount',
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.timer_outlined,
                      label: 'Ort. Çözüm Süresi',
                      value: avgDuration == null ? '—' : _formatDuration(avgDuration),
                      color: colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.bar_chart_outlined,
                          size: 56,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Bu dönemde tamamladığınız bir görev bulunmuyor.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                const Text(
                  'Kategoriye Göre Dağılım',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                ...sortedCategories.map(
                      (entry) => _CategoryBar(
                    label: entry.key.label,
                    count: entry.value,
                    total: totalCount,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Tüm işler içinden, bu personelin "çözüldü" durumuna geçirdiği (kendi
  /// adının history kaydında actorName olarak geçtiği) işleri süzer.
  List<_CompletedByMe> _extractCompletedByMe(List<Issue> issues, String staffName) {
    final result = <_CompletedByMe>[];
    for (final issue in issues) {
      IssueHistoryEntry? myCompletion;
      for (final entry in issue.history) {
        if (entry.status == IssueStatus.cozuldu && entry.actorName == staffName) {
          // Aynı iş birden fazla kez "çözüldü" yapılmışsa (nadir durum),
          // en son olan kaydı esas alıyoruz.
          if (myCompletion == null || entry.timestamp.isAfter(myCompletion.timestamp)) {
            myCompletion = entry;
          }
        }
      }
      if (myCompletion != null) {
        result.add(
          _CompletedByMe(
            issue: issue,
            completedAt: myCompletion.timestamp,
            resolutionTime: myCompletion.timestamp.difference(issue.createdAt),
          ),
        );
      }
    }
    return result;
  }

  List<_CompletedByMe> _filterByPeriod(List<_CompletedByMe> list, _PerfPeriod period) {
    if (period == _PerfPeriod.tumu) return list;
    final now = DateTime.now();
    late final DateTime start;
    if (period == _PerfPeriod.hafta) {
      final mondayOfThisWeek = now.subtract(Duration(days: now.weekday - 1));
      start = DateTime(mondayOfThisWeek.year, mondayOfThisWeek.month, mondayOfThisWeek.day);
    } else {
      start = DateTime(now.year, now.month, 1);
    }
    return list.where((e) => e.completedAt.isAfter(start)).toList();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '—';
    if (d.inDays >= 1) {
      final hours = d.inHours % 24;
      return hours > 0 ? '${d.inDays} gün $hours sa.' : '${d.inDays} gün';
    } else if (d.inHours >= 1) {
      final minutes = d.inMinutes % 60;
      return minutes > 0 ? '${d.inHours} sa. $minutes dk.' : '${d.inHours} saat';
    } else {
      return '${d.inMinutes} dk.';
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;

  const _CategoryBar({required this.label, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ratio = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13)),
              Text('$count', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}