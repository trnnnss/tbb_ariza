import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Arıza konumlarını Google Maps veya cihazın varsayılan harita uygulamasında
/// açarak saha ekiplerine ve vatandaşlara yol tarifi / navigasyon sağlayan yardımcı sınıf.
class MapLauncher {
  MapLauncher._();

  /// Arıza koordinatları (enlem/boylam) veya ilçe/mahalle bilgisiyle haritayı başlatır.
  static Future<void> openMap({
    required BuildContext context,
    double? latitude,
    double? longitude,
    String? title,
    String? district,
    String? neighborhood,
  }) async {
    Uri url;

    if (latitude != null &&
        longitude != null &&
        latitude != 0 &&
        longitude != 0) {
      // Google Maps doğrudan koordinat pin ve yol tarifi URL'si
      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      );
    } else {
      // Koordinat yoksa ilçe ve mahalle üzerinden akıllı arama URL'si
      final queryAddress =
          '${neighborhood != null ? '$neighborhood, ' : ''}'
          '${district != null ? '$district, ' : ''}Trabzon';
      final encodedQuery = Uri.encodeComponent(queryAddress);
      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encodedQuery',
      );
    }

    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        // Alternatif olarak varsayılan modda aç
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Harita açılamadı: $e'),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    }
  }
}
