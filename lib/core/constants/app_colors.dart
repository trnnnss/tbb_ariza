import 'package:flutter/material.dart';

/// Uygulama genelinde kullanılan sabit marka renkleri.
/// Ana tema (mavi) `main.dart` içinde `colorSchemeSeed: Colors.blue` ile
/// tanımlı; burada sadece TBB logosundaki kurumsal kırmızı gibi, temadan
/// bağımsız sabit vurgu renkleri tutulur.
class AppColors {
  AppColors._();

  /// TBB logosundaki gemi amblemiyle aynı bordo ton.
  /// "Arıza bildir" akışının tamamında (CTA, gönder butonu) vurgu rengi.
  static const tbbRed = Color(0xFFB0203A);
}