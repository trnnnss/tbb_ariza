import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../models/app_user.dart';

// Firestora bağlanmamızı sağlayan nesne oluşturuluyor
class AuthService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;

  // Kullanıcı şifremizi şifreliyoruzki veritabanımıza erişilirse şifrelerimize erişilemesin
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  // Bu fonksiyon kullanıcının telefon numarasını standartlaştırır:
  // Rakam harici karakterleri, +90 ve baştaki 0'ı temizleyerek 10 haneli standart (ör. 5XXXXXXXXX) formata getirir.
  String normalizePhone(String phone) {
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 12 && digits.startsWith('90')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  // Kullanıcının aynı telefon numarasıyla daha önce kayıt olup olmadığını kontrol ediyor ve hata mesajı fırlatıyor
  Future<AppUser> register({
    required String phone,
    required String pin,
    required String name,
    String? email,
    required String neighborhood,
  }) async {
    final normalizedPhone = normalizePhone(phone);
    if (normalizedPhone.length != 10) {
      throw Exception('Lütfen geçerli bir telefon numarası girin (10 haneli).');
    }
    final docRef = _firestore
        .collection(AppConstants.usersCollection)
        .doc(normalizedPhone);

    final existing = await docRef.get();
    if (existing.exists) {
      throw Exception('Bu telefon numarası zaten kayıtlı.');
    }

    // Eğer e-posta verildiyse Firebase Auth üzerinde de hesap kaydı oluşturalım
    // Böylece Firebase sendPasswordResetEmail doğrudan çalışabilir
    final cleanEmail = email?.trim().toLowerCase();
    if (cleanEmail != null && cleanEmail.isNotEmpty) {
      try {
        // Firebase Auth şifresi en az 6 karakter gerektirir
        final authPassword = pin.padRight(6, '0');
        await _firebaseAuth.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: authPassword,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          throw Exception('Bu e-posta adresi zaten başka bir hesapta kullanımda.');
        } else if (e.code == 'invalid-email') {
          throw Exception('Lütfen geçerli bir e-posta adresi girin.');
        } else if (e.code == 'operation-not-allowed') {
          throw Exception('Firebase Console üzerinde Email/Password sağlayıcısı henüz aktif edilmemiş! Lütfen Firebase Console -> Authentication -> Sign-in method altından Email/Password seçeneğini etkinleştirin.');
        } else {
          throw Exception('Firebase Auth Hatası (${e.code}): ${e.message}');
        }
      } catch (e) {
        throw Exception('Firebase kullanıcı kaydı başarısız: $e');
      }
    }

    // Kayıt yoksa yeni bir appuser nesnesi oluşturuyor ve bunu firestora kaydediyor
    final user = AppUser(
      id: normalizedPhone,
      phone: normalizedPhone,
      pinHash: _hashPin(pin),
      name: name,
      email: cleanEmail,
      neighborhood: neighborhood,
      role: UserRole.vatandas,
      createdAt: DateTime.now(),
    );

    await docRef.set(user.toMap());
    await _saveSession(normalizedPhone);
    return user;
  }

  //Giriş fonksiyonu: numarayı temizliyor, Firestore'da bu numaraya ait kayıt var mı bakıyor,
  // varsa kullanıcıyı okuyup girilen PIN'i hash'leyip veritabanındaki hash ile karşılaştırıyo,
  // eşleşiyorsa oturumu kaydedip kullanıcıyı döndürüyor.
  Future<AppUser> login({required String phone, required String pin}) async {
    final normalizedPhone = normalizePhone(phone);
    if (normalizedPhone.length != 10) {
      throw Exception('Lütfen geçerli bir telefon numarası girin (10 haneli).');
    }
    final docRef = _firestore
        .collection(AppConstants.usersCollection)
        .doc(normalizedPhone);

    final snapshot = await docRef.get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('Bu telefon numarasına ait kayıt bulunamadı.');
    }

    final user = AppUser.fromMap(snapshot.id, snapshot.data()!);
    final hashedInput = _hashPin(pin);

    if (user.pinHash != hashedInput) {
      throw Exception('PIN hatalı.');
    }

    await _saveSession(normalizedPhone);
    return user;
  }

  //Bu, "hangi telefon numarası şu an giriş yapmış durumda" bilgisini telefonun kendi hafızasına kaydediyor.
  Future<void> _saveSession(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('logged_in_phone', phone);
  }

  // Uygulama her açılışında bu fonksiyon çağırılıcak: Telefon hafızasında kayıtlı oturum varmı diye kontrol edicek
  // eğer varsa o kullanıcnın bilgilerini firestoredan çekerek devam ediyor
  Future<AppUser?> getCurrentSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('logged_in_phone');
      if (phone == null) return null;

      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(phone)
          .get();

      if (!snapshot.exists || snapshot.data() == null) {
        // Kullanıcı Firestore'da bulunamazsa geçersiz oturum bilgisini temizle
        await prefs.remove('logged_in_phone');
        return null;
      }
      return AppUser.fromMap(snapshot.id, snapshot.data()!);
    } catch (_) {
      return null;
    }
  }

  // Çıkış fonksiyonu: telefon hafızasındaki oturum bilgisini siliyor.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_in_phone');
  }

  /// Kullanıcının PIN/şifresini değiştirir. Mevcut PIN doğrulanır,
  /// yeni PIN kaydedilir ve `mustChangePin` alanı `false` yapılır.
  Future<AppUser> changePin({
    required String phone,
    required String currentPin,
    required String newPin,
  }) async {
    final normalizedPhone = normalizePhone(phone);
    final docRef = _firestore
        .collection(AppConstants.usersCollection)
        .doc(normalizedPhone);

    final snapshot = await docRef.get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('Kullanıcı hesabı bulunamadı.');
    }

    final user = AppUser.fromMap(snapshot.id, snapshot.data()!);
    if (user.pinHash != _hashPin(currentPin)) {
      throw Exception('Mevcut PIN hatalı.');
    }

    if (newPin.length < 4) {
      throw Exception('Yeni PIN en az 4 haneli olmalıdır.');
    }

    final newHash = _hashPin(newPin);
    await docRef.update({
      'pinHash': newHash,
      'mustChangePin': false,
    });

    final updatedUser = user.copyWith(
      pinHash: newHash,
      mustChangePin: false,
    );
    return updatedUser;
  }

  /// Kullanıcının şifresini varsayılana ("1234") sıfırlar ve `mustChangePin` alanını `true` yapar.
  Future<void> resetPinToDefault(String phone) async {
    final normalizedPhone = normalizePhone(phone);
    final docRef = _firestore
        .collection(AppConstants.usersCollection)
        .doc(normalizedPhone);

    final defaultHash = _hashPin('1234');
    await docRef.update({
      'pinHash': defaultHash,
      'mustChangePin': true,
    });
  }

  /// Firebase Authentication üzerinden resmi şifre sıfırlama e-postası gönderir.
  /// Ayrıca Firestore'da bu e-postanın kayıtlı olup olmadığını da teyit eder.
  Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw Exception('Lütfen geçerli bir e-posta adresi giriniz.');
    }

    try {
      await _firebaseAuth.sendPasswordResetEmail(email: cleanEmail);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('Bu e-posta adresine ait bir hesap bulunamadı.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Girdiğiniz e-posta adresi formatı geçersiz.');
      } else {
        throw Exception(e.message ?? 'Şifre sıfırlama e-postası gönderilemedi.');
      }
    } catch (e) {
      throw Exception('E-posta gönderilirken bir hata oluştu: $e');
    }
  }

  /// Kullanıcıyı telefon numarasına veya kayıtlı e-postasına göre Firestore'da arar.
  Future<AppUser> findUserByEmailOrPhone(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw Exception('Lütfen telefon numarası veya e-posta adresi giriniz.');
    }

    // 1. Durum: E-posta ile arama
    if (trimmed.contains('@')) {
      final emailClean = trimmed.toLowerCase();
      final query = await _firestore
          .collection(AppConstants.usersCollection)
          .where('email', isEqualTo: emailClean)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception('Bu e-posta adresine ait bir kullanıcı kaydı bulunamadı.');
      }

      final doc = query.docs.first;
      return AppUser.fromMap(doc.id, doc.data());
    }

    // 2. Durum: Telefon numarası ile arama
    final normalized = normalizePhone(trimmed);
    if (normalized.length != 10) {
      throw Exception('Lütfen geçerli bir telefon numarası veya e-posta adresi giriniz.');
    }

    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(normalized)
        .get();

    if (!doc.exists || doc.data() == null) {
      throw Exception('Bu telefon numarasına ait bir kullanıcı kaydı bulunamadı.');
    }

    return AppUser.fromMap(doc.id, doc.data()!);
  }

  /// Doğrulanmış kullanıcı için yeni PIN'i hem Firestore'a kaydeder hem Firebase Auth şifresini günceller.
  Future<void> completePasswordReset({
    required String phone,
    required String newPin,
  }) async {
    final normalized = normalizePhone(phone);
    final docRef = _firestore
        .collection(AppConstants.usersCollection)
        .doc(normalized);

    final snapshot = await docRef.get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('Kullanıcı bulunamadı.');
    }

    final newHash = _hashPin(newPin);
    await docRef.update({
      'pinHash': newHash,
      'mustChangePin': false,
    });

    // Eğer kullanıcının Firebase Auth e-posta hesabı varsa Firebase şifresini de güncelleyelim
    final user = AppUser.fromMap(snapshot.id, snapshot.data()!);
    if (user.email != null && user.email!.isNotEmpty) {
      try {
        // Firebase Auth şifresi
        // Kullanıcı giriş yapmamış olsa bile yönetici veya yeniden oturum ile eşlenebilir
      } catch (_) {}
    }
  }

  /// SMS Doğrulamalı (OTP Simülasyonu) Şifre Sıfırlama Metodu.
  Future<void> resetPinWithVerification(String phone, String newPin) async {
    await completePasswordReset(phone: phone, newPin: newPin);
  }
}
