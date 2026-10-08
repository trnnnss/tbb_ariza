import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { vatandas, yonetici, personel }

class AppUser {
  final String id; // Firestore doküman id'si (telefon numarası)
  final String phone;
  final String pinHash;
  final String name;
  final String? email;        // Şifre sıfırlama ve iletişim için e-posta
  final String? neighborhood; // sadece vatandaşlar için
  final String? teamId;       // personel için ekip id'si (örn: tiski_su)
  final String? teamName;     // personel için ekip adı (örn: TİSKİ Su Ekibi)
  final UserRole role;
  final DateTime createdAt;
  final bool mustChangePin;   // İlk giriş / varsayılan şifre uyarısı için

  AppUser({
    required this.id,
    required this.phone,
    required this.pinHash,
    required this.name,
    this.email,
    this.neighborhood,
    this.teamId,
    this.teamName,
    required this.role,
    required this.createdAt,
    this.mustChangePin = false,
  });

  AppUser copyWith({
    String? pinHash,
    bool? mustChangePin,
    String? name,
    String? email,
  }) {
    return AppUser(
      id: id,
      phone: phone,
      pinHash: pinHash ?? this.pinHash,
      name: name ?? this.name,
      email: email ?? this.email,
      neighborhood: neighborhood,
      teamId: teamId,
      teamName: teamName,
      role: role,
      createdAt: createdAt,
      mustChangePin: mustChangePin ?? this.mustChangePin,
    );
  }

  // Firestore'dan okurken:
  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    DateTime parsedCreatedAt;
    final rawCreated = map['createdAt'];
    if (rawCreated is Timestamp) {
      parsedCreatedAt = rawCreated.toDate();
    } else if (rawCreated is int) {
      parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(rawCreated);
    } else if (rawCreated is num) {
      parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(rawCreated.toInt());
    } else {
      parsedCreatedAt = DateTime.now();
    }

    final roleStr = map['role'] as String?;
    final role = roleStr == 'yonetici'
        ? UserRole.yonetici
        : roleStr == 'personel'
        ? UserRole.personel
        : UserRole.vatandas;

    return AppUser(
      id: id,
      phone: (map['phone'] as String?) ?? id,
      pinHash: (map['pinHash'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      email: map['email'] as String?,
      neighborhood: map['neighborhood'] as String?,
      teamId: map['teamId'] as String?,
      teamName: map['teamName'] as String?,
      role: role,
      createdAt: parsedCreatedAt,
      mustChangePin: (map['mustChangePin'] as bool?) ?? false,
    );
  }

  // Firestore'a yazarken:
  Map<String, dynamic> toMap() {
    return {
      'phone': phone,
      'pinHash': pinHash,
      'name': name,
      if (email != null) 'email': email,
      'neighborhood': neighborhood,
      'teamId': teamId,
      'teamName': teamName,
      'role': role == UserRole.yonetici
          ? 'yonetici'
          : role == UserRole.personel
          ? 'personel'
          : 'vatandas',
      'createdAt': createdAt.millisecondsSinceEpoch,
      'mustChangePin': mustChangePin,
    };
  }
}