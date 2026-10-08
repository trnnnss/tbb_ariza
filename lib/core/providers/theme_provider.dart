import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Uygulama tema modunu tutan provider (Koyu / Açık / Sistem).
/// Varsayılan olarak kullanıcının isteği doğrultusunda ThemeMode.dark (koyu tema).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);
