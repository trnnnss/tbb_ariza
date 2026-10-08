import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../../firebase_options.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

// Bu satır, AuthService sınıfından tek bir örnek oluşturup, uygulamanın her ekranından erişilebilir hale getiriyor
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Bu uygulamanın "şu an giriş yapmış kullanıcı kim?" sorusunu cevaplayan asıl mekanizma.
final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AppUser?>>((ref) {
      return AuthController(ref.watch(authServiceProvider));
    });

// Bu sınıf oluşturulduğu an otomatik olarak _checkSession()
// fonksiyonunu çalıştırıyor — "cihazda kayıtlı bir oturum var mı?" kontrolü hemen başlıyor. Başlangıç durumu loading (yükleniyor) olarak ayarlanıyor
class AuthController extends StateNotifier<AsyncValue<AppUser?>> {
  final AuthService _authService;

  AuthController(this._authService) : super(const AsyncValue.loading()) {
    _checkSession();
  }

  // Bu metod, auth_service.dart içindeki getCurrentSession() fonksiyonunu çağırıp sonucu state'e yazıyor.
  Future<void> _checkSession() async {
    state = const AsyncValue.loading();
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final user = await _authService.getCurrentSession();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      // Oturum ve Firebase hazır olduğunda yerel splash ekranını kaldırıyoruz
      FlutterNativeSplash.remove();
    }
  }

  // Giriş ekranında "Giriş Yap" butonuna basılınca bu fonksiyon çağrılıyor.
  Future<void> login({required String phone, required String pin}) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.login(phone: phone, pin: pin);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Kayıt ekranında "Kayıt Ol" butonuna basılınca bu fonksiyon çağrılıyor.
  Future<void> register({
    required String phone,
    required String pin,
    required String name,
    String? email,
    required String neighborhood,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.register(
        phone: phone,
        pin: pin,
        name: name,
        email: email,
        neighborhood: neighborhood,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Firebase üzerinden şifre sıfırlama e-postası gönderir.
  Future<void> sendPasswordResetEmail(String email) async {
    await _authService.sendPasswordResetEmail(email);
  }

  // Çıkış yaptığında telefon hafızasındaki oturum bilgilerini siliyor
  Future<void> logout() async {
    await _authService.logout();
    state = const AsyncValue.data(null);
  }

  /// Oturum açmış kullanıcının PIN'ini değiştirir.
  Future<void> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final currentUser = state.value;
    if (currentUser == null) throw Exception('Oturum bulunamadı.');

    final updatedUser = await _authService.changePin(
      phone: currentUser.phone,
      currentPin: currentPin,
      newPin: newPin,
    );

    state = AsyncValue.data(updatedUser);
  }

  /// Verilen telefon numaralı kullanıcının şifresini "1234" yapar.
  Future<void> resetPinToDefault(String phone) async {
    await _authService.resetPinToDefault(phone);
  }

  /// Kullanıcıyı e-posta veya telefon ile bulur.
  Future<AppUser> findUserByEmailOrPhone(String input) async {
    return await _authService.findUserByEmailOrPhone(input);
  }

  /// Doğrulanmış kullanıcı için yeni PIN belirler.
  Future<void> completePasswordReset({
    required String phone,
    required String newPin,
  }) async {
    await _authService.completePasswordReset(phone: phone, newPin: newPin);
  }

  /// SMS Doğrulamalı (OTP Simülasyonu) ile şifreyi dışarıdan sıfırlar.
  Future<void> resetPinWithVerification({
    required String phone,
    required String newPin,
  }) async {
    await _authService.resetPinWithVerification(phone, newPin);
  }
}
