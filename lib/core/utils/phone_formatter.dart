import 'package:flutter/services.dart';

/// Türk telefon numarası giriş formatı: (5XX) - XXX - XX XX
/// Kullanıcı rakam girdikçe otomatik olarak parantez, tire ve boşlukları
/// doğru yerlere ekler. Sadece 5 ile başlayan 10 haneli numaraları kabul eder.
class TurkishPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var oldDigits = oldValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    var newDigits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Kullanıcı baştaki 0'a basarsa otomatik temizle (örn. 05XX -> 5XX)
    if (newDigits.startsWith('0')) {
      newDigits = newDigits.substring(1);
    }

    // Silme (Backspace) durumunda: Eğer format karakteri (parantez, boşluk, tire)
    // silinmeye çalışılmışsa ve rakam sayısı değişmemişse, önceki rakamı sil
    if (oldValue.text.length > newValue.text.length &&
        oldDigits == newDigits &&
        newDigits.isNotEmpty) {
      newDigits = newDigits.substring(0, newDigits.length - 1);
    }

    // Maksimum 10 hane (5XXXXXXXXX)
    final trimmed = newDigits.length > 10 ? newDigits.substring(0, 10) : newDigits;

    final buffer = StringBuffer();
    for (int i = 0; i < trimmed.length; i++) {
      if (i == 0) buffer.write('(');
      buffer.write(trimmed[i]);
      if (i == 2) buffer.write(') - ');
      if (i == 5) buffer.write(' - ');
      if (i == 7) buffer.write(' ');
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
