import 'package:flutter/material.dart';
import '../../core/models/issues_model.dart';

/// Arıza kategorisine göre ikon döndürür. Kategori seçim kartlarında ve
/// bildirim listelerinde aynı ikon kullanılarak görsel tutarlılık sağlanır.
IconData iconForCategory(IssueCategory category) {
  switch (category) {
    case IssueCategory.yol:
      return Icons.add_road;
    case IssueCategory.aydinlatma:
      return Icons.lightbulb_outline;
    case IssueCategory.su:
      return Icons.water_drop_outlined;
    case IssueCategory.cop:
      return Icons.delete_outline;
    case IssueCategory.diger:
      return Icons.more_horiz;
  }
}

/// Arıza durumuna göre rozet rengi döndürür (metin/arka plan çifti).
/// Login ekranındaki Material 3 mavi temayla uyumlu, semantik renkler
/// kullanılır: bekleyen turuncu, işlemde mavi, çözülen yeşil.
class IssueStatusStyle {
  final Color background;
  final Color foreground;
  const IssueStatusStyle(this.background, this.foreground);
}

IssueStatusStyle styleForStatus(IssueStatus status, [Brightness? brightness]) {
  final isDark = brightness == Brightness.dark;
  switch (status) {
    case IssueStatus.beklemede:
      return isDark
          ? const IssueStatusStyle(Color(0xFF4A2E00), Color(0xFFFFC46B))
          : const IssueStatusStyle(Color(0xFFFAEEDA), Color(0xFF854F0B));
    case IssueStatus.islemeAlindi:
      return isDark
          ? const IssueStatusStyle(Color(0xFF002E5C), Color(0xFF8FCAFF))
          : const IssueStatusStyle(Color(0xFFE6F1FB), Color(0xFF0C447C));
    case IssueStatus.yolda:
      return isDark
          ? const IssueStatusStyle(Color(0xFF3A2A00), Color(0xFFFFD98F))
          : const IssueStatusStyle(Color(0xFFFFF3D9), Color(0xFF8A5D00));
    case IssueStatus.basladi:
      return isDark
          ? const IssueStatusStyle(Color(0xFF002E5C), Color(0xFF8FCAFF))
          : const IssueStatusStyle(Color(0xFFE6F1FB), Color(0xFF0C447C));
    case IssueStatus.cozuldu:
      return isDark
          ? const IssueStatusStyle(Color(0xFF1A3A00), Color(0xFF8EDB5E))
          : const IssueStatusStyle(Color(0xFFEAF3DE), Color(0xFF27500A));
    case IssueStatus.ertelendi:
      return isDark
          ? const IssueStatusStyle(Color(0xFF3A2A1A), Color(0xFFFFB784))
          : const IssueStatusStyle(Color(0xFFFBE8DA), Color(0xFF8A4A0B));
    case IssueStatus.iptal:
      return isDark
          ? const IssueStatusStyle(Color(0xFF4A1414), Color(0xFFFF9B9B))
          : const IssueStatusStyle(Color(0xFFFBE1E1), Color(0xFF8A1F1F));
  }
}

/// Öncelik rozeti için renk/ikon çifti.
class IssuePriorityStyle {
  final Color background;
  final Color foreground;
  final IconData icon;
  const IssuePriorityStyle(this.background, this.foreground, this.icon);
}

IssuePriorityStyle styleForPriority(IssuePriority priority, [Brightness? brightness]) {
  final isDark = brightness == Brightness.dark;
  switch (priority) {
    case IssuePriority.dusuk:
      return isDark
          ? const IssuePriorityStyle(Color(0xFF1A3A00), Color(0xFF8EDB5E), Icons.south_outlined)
          : const IssuePriorityStyle(Color(0xFFEAF3DE), Color(0xFF27500A), Icons.south_outlined);
    case IssuePriority.normal:
      return isDark
          ? const IssuePriorityStyle(Color(0xFF2A2A2A), Color(0xFFD0D0D0), Icons.remove)
          : const IssuePriorityStyle(Color(0xFFEDEDED), Color(0xFF4A4A4A), Icons.remove);
    case IssuePriority.yuksek:
      return isDark
          ? const IssuePriorityStyle(Color(0xFF3A2A00), Color(0xFFFFD98F), Icons.north_outlined)
          : const IssuePriorityStyle(Color(0xFFFFF3D9), Color(0xFF8A5D00), Icons.north_outlined);
    case IssuePriority.acil:
      return isDark
          ? const IssuePriorityStyle(Color(0xFF4A1414), Color(0xFFFF9B9B), Icons.priority_high)
          : const IssuePriorityStyle(Color(0xFFFBE1E1), Color(0xFF8A1F1F), Icons.priority_high);
  }
}