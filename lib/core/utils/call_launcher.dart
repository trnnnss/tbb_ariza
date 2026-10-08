import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Vatandaşı tek tıkla aramak için telefon uygulamasını açan yardımcı sınıf.
/// [MapLauncher] ile aynı desende yazıldı.
class CallLauncher {
  CallLauncher._();

  /// [phone] Firestore'da saklanan normalize edilmiş 10 haneli numara
  /// (örn. "5321112231", başında 0 veya +90 yok). Arama başlatılırken
  /// otomatik olarak +90 ile tamamlanır.
  static Future<void> call({
    required BuildContext context,
    required String phone,
  }) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Telefon numarası bulunamadı.')),
        );
      }
      return;
    }

    // Numara zaten 90 ile başlıyorsa tekrar eklemiyoruz.
    final dialNumber = digits.startsWith('90') ? digits : '90$digits';
    final url = Uri(scheme: 'tel', path: '+$dialNumber');

    try {
      final launched = await launchUrl(url);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arama başlatılamadı.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Arama başlatılamadı: $e'),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    }
  }
}