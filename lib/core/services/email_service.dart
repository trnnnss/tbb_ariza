import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class SendEmailResult {
  final bool isSuccess;
  final String? errorMessage;

  SendEmailResult({required this.isSuccess, this.errorMessage});
}

/// E-posta Gönderim Servisi (EmailJS REST API)
/// Kullanıcıların şifre sıfırlama doğrulama kodlarını (OTP) doğrudan
/// Outlook, Gmail, Hotmail veya herhangi bir e-posta adresine ulaştırır.
class EmailService {
  static const String serviceId = 'service_csht9nj';
  static const String templateId = 'template_xr1bz2q';
  static const String publicKey = 'UWJUYHpsyLzs6GAOb';

  /// 6 Haneli Doğrulama Kodunu E-posta ile gönderir
  static Future<SendEmailResult> sendOtpEmail({
    required String recipientEmail,
    required String recipientName,
    required String otpCode,
  }) async {
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    // 15 dakika sonrasının zaman damgası (örn: 23 Eylül 2026 11:00)
    final expireTime = DateTime.now().add(const Duration(minutes: 15));
    final formattedTime = DateFormat('dd.MM.yyyy HH:mm').format(expireTime);

    try {
      final response = await http.post(
        url,
        headers: {
          'origin': 'http://localhost',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': publicKey,
          'template_params': {
            'email': recipientEmail,
            'to_email': recipientEmail,
            'to_name': recipientName,
            'name': recipientName,
            'passcode': otpCode,
            'otp_code': otpCode,
            'time': formattedTime,
            'company_name': 'Trabzon Büyükşehir Belediyesi',
          },
        }),
      );

      if (response.statusCode == 200) {
        return SendEmailResult(isSuccess: true);
      } else {
        return SendEmailResult(
          isSuccess: false,
          errorMessage: 'EmailJS Hatası (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      return SendEmailResult(
        isSuccess: false,
        errorMessage: 'Bağlantı hatası: $e',
      );
    }
  }
}
