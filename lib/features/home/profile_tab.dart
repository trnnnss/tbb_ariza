import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../auth/change_pin_sheet.dart';

// Profil ekranını ve kullanıcı bilgilerini oluşturan ana widget
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Oturum açmış kullanıcının bilgilerini ve tema renklerini alır
    final user = ref.watch(authControllerProvider).asData?.value;
    final colorScheme = Theme.of(context).colorScheme;

    // Profil ekranının kaydırılabilir ana içerik alanını oluşturur
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Kullanıcının ad, telefon ve profil ikonunu gösteren üst kart
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.15),
                child: Icon(Icons.person, size: 32, color: colorScheme.onPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                user?.name ?? '',
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.phone ?? '',
                style: TextStyle(
                  color: colorScheme.onPrimary.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Kullanıcının mahalle bilgisini gösteren bilgi alanı
        _InfoTile(
          icon: Icons.place_outlined,
          label: 'Mahalle',
          value: user?.neighborhood ?? '-',
        ),
        const SizedBox(height: 12),

        // Uygulamanın koyu ve açık tema arasında değiştirilmesini sağlar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.dark_mode_outlined, color: colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              const Text('Koyu Tema', style: TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              Switch(
                value: ref.watch(themeModeProvider) == ThemeMode.dark,
                onChanged: (isDark) {
                  ref.read(themeModeProvider.notifier).state =
                  isDark ? ThemeMode.dark : ThemeMode.light;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Kullanıcının şifresini değiştirebilmesi için şifre değiştirme ekranını açar
        InkWell(
          onTap: () => showChangePinSheet(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_reset_outlined, color: colorScheme.primary, size: 20),
                const SizedBox(width: 10),
                const Text('Şifre Değiştir', style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Kullanıcının mevcut oturumunu kapatmasını sağlar
        OutlinedButton.icon(
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.error,
            side: BorderSide(color: colorScheme.error),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Çıkış Yap'),
        ),
      ],
    );
  }
}

// Profil içerisindeki etiket ve değer bilgilerini tekrar kullanılabilir şekilde gösterir
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    // Bilgi alanında kullanılacak tema renklerini alır
    final colorScheme = Theme.of(context).colorScheme;

    // İkon, etiket ve değer bilgisinden oluşan bilgi kartını oluşturur
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}