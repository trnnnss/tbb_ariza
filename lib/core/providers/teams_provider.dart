import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../models/issues_model.dart';
import '../models/team_model.dart';
import '../services/auth_service.dart';

/// Trabzon Büyükşehir Belediyesi'nin saha ekiplerini Firestore'daki "teams"
/// koleksiyonundan canlı olarak dinleyen provider.
///
/// Firestore'da bir ekip belgesi değişirse (yeni personel eklenir, izin
/// durumu güncellenir, ekip amiri değişir vb.) bu stream sayesinde tüm
/// ekranlar otomatik olarak güncellenir - sayfa yenilemeye gerek kalmaz.
final teamsProvider = StreamProvider<List<Team>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.teamsCollection)
      .snapshots()
      .map((snapshot) {
    final teams = snapshot.docs
        .map((doc) => Team.fromMap(doc.id, doc.data()))
        .toList();
    // İsimlere göre alfabetik sırala - liste ekranlarda kararlı/tutarlı görünsün.
    teams.sort((a, b) => a.name.compareTo(b.name));
    return teams;
  });
});

/// Verilen ekip listesinde id'ye göre arama yapar (TeamsData.getTeamById'nin
/// canlı Firestore listesiyle çalışan karşılığı).
Team? findTeamById(List<Team> teams, String? id) {
  if (id == null) return null;
  try {
    return teams.firstWhere((t) => t.id == id);
  } catch (_) {
    return null;
  }
}

/// Verilen ekip listesinde bir arıza kategorisine en uygun ekibi bulur;
/// tam eşleşme yoksa listedeki son ekibi döner (TeamsData.getTeamForCategory'nin
/// canlı Firestore listesiyle çalışan karşılığı).
Team? findTeamForCategory(List<Team> teams, IssueCategory category) {
  if (teams.isEmpty) return null;
  try {
    return teams.firstWhere((t) => t.category == category);
  } catch (_) {
    return teams.last;
  }
}

/// Tek bir personelin "users" koleksiyonundaki oturum/giriş hesabını oluşturur/günceller.
/// Varsayılan PIN / şifre: "1234"
Future<void> syncStaffUserAccount({
  required String phone,
  required String name,
  required String teamId,
  String? teamName,
  String defaultPin = '1234',
}) async {
  final authService = AuthService();
  final normalizedPhone = authService.normalizePhone(phone);
  if (normalizedPhone.length != 10) return;

  final pinBytes = utf8.encode(defaultPin);
  final pinHash = sha256.convert(pinBytes).toString();

  final userDocRef = FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .doc(normalizedPhone);

  final userMap = <String, dynamic>{
    'phone': normalizedPhone,
    'name': name,
    'role': 'personel',
    'teamId': teamId,
  };
  if (teamName != null) {
    userMap['teamName'] = teamName;
  }

  final snapshot = await userDocRef.get();
  if (!snapshot.exists) {
    userMap['pinHash'] = pinHash;
    userMap['mustChangePin'] = true;
    userMap['createdAt'] = DateTime.now().millisecondsSinceEpoch;
    await userDocRef.set(userMap);
  } else {
    userMap['pinHash'] = (snapshot.data()?['pinHash'] as String?) ?? pinHash;
    await userDocRef.set(userMap, SetOptions(merge: true));
  }
}

/// Firestore'daki tüm ekiplerin personellerini tarar ve "users" koleksiyonunda
/// şifresi "1234" olan personel giriş hesaplarını oluşturur / günceller.
Future<int> syncAllStaffAccountsToUsersCollection() async {
  final teamsSnapshot = await FirebaseFirestore.instance
      .collection(AppConstants.teamsCollection)
      .get();

  int syncedCount = 0;
  final authService = AuthService();
  final pinBytes = utf8.encode('1234');
  final defaultPinHash = sha256.convert(pinBytes).toString();

  for (final doc in teamsSnapshot.docs) {
    final team = Team.fromMap(doc.id, doc.data());
    for (final member in team.members) {
      final normalizedPhone = authService.normalizePhone(member.phone);
      if (normalizedPhone.length != 10) continue;

      final userDocRef = FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(normalizedPhone);

      final existing = await userDocRef.get();
      if (!existing.exists) {
        await userDocRef.set({
          'phone': normalizedPhone,
          'pinHash': defaultPinHash,
          'name': member.name,
          'role': 'personel',
          'teamId': team.id,
          'teamName': team.name,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        await userDocRef.set({
          'phone': normalizedPhone,
          'pinHash': (existing.data()?['pinHash'] as String?) ?? defaultPinHash,
          'name': member.name,
          'role': 'personel',
          'teamId': team.id,
          'teamName': team.name,
          'createdAt': existing.data()?['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        }, SetOptions(merge: true));
      }
      syncedCount++;
    }
  }
  return syncedCount;
}

/// Bir personelin görevde/izinli durumunu Firestore'a kalıcı olarak yazar.
Future<void> updateStaffActiveStatus({
  required String teamId,
  required String staffId,
  required bool isActive,
  DateTime? leaveStartDate,
  DateTime? leaveEndDate,
  String? leaveReason,
}) async {
  final docRef = FirebaseFirestore.instance
      .collection(AppConstants.teamsCollection)
      .doc(teamId);

  await FirebaseFirestore.instance.runTransaction((transaction) async {
    final snapshot = await transaction.get(docRef);
    final data = snapshot.data();
    if (data == null) return;

    final membersRaw = (data['members'] as List<dynamic>?) ?? [];
    final updatedMembers = membersRaw.map((m) {
      final memberMap = Map<String, dynamic>.from(m as Map);
      if (memberMap['id'] == staffId) {
        memberMap['isActive'] = isActive;
        if (isActive) {
          memberMap['leaveStartDate'] = null;
          memberMap['leaveEndDate'] = null;
          memberMap['leaveReason'] = null;
        } else {
          memberMap['leaveStartDate'] = leaveStartDate?.toIso8601String();
          memberMap['leaveEndDate'] = leaveEndDate?.toIso8601String();
          memberMap['leaveReason'] = leaveReason;
        }
      }
      return memberMap;
    }).toList();

    transaction.update(docRef, {'members': updatedMembers});
  });
}

/// Bir ekibe yeni bir personel ekler ve giriş hesabını oluşturur.
Future<void> addStaffMember({
  required String teamId,
  required String name,
  required String title,
  required String phone,
  bool isActive = true,
  DateTime? leaveStartDate,
  DateTime? leaveEndDate,
  String? leaveReason,
}) async {
  final docRef = FirebaseFirestore.instance
      .collection(AppConstants.teamsCollection)
      .doc(teamId);

  await FirebaseFirestore.instance.runTransaction((transaction) async {
    final snapshot = await transaction.get(docRef);
    final data = snapshot.data();
    if (data == null) return;

    final membersRaw = (data['members'] as List<dynamic>?) ?? [];
    final newStaffId = 'staff_${DateTime.now().millisecondsSinceEpoch}';

    final newMember = StaffMember(
      id: newStaffId,
      name: name,
      title: title,
      phone: phone,
      isActive: isActive,
      leaveStartDate: isActive ? null : leaveStartDate,
      leaveEndDate: isActive ? null : leaveEndDate,
      leaveReason: isActive ? null : leaveReason,
    );

    final updatedMembers = [
      ...membersRaw.map((m) => Map<String, dynamic>.from(m as Map)),
      newMember.toMap(),
    ];

    transaction.update(docRef, {'members': updatedMembers});
  });

  // Giriş hesabını "users" koleksiyonuna senkronize et (varsayılan şifre: 1234)
  await syncStaffUserAccount(
    phone: phone,
    name: name,
    teamId: teamId,
  );
}

/// Var olan bir personelin bilgilerini günceller ve giriş hesabını senkronize eder.
Future<void> updateStaffMember({
  required String teamId,
  required String staffId,
  required String name,
  required String title,
  required String phone,
  required bool isActive,
  DateTime? leaveStartDate,
  DateTime? leaveEndDate,
  String? leaveReason,
}) async {
  final docRef = FirebaseFirestore.instance
      .collection(AppConstants.teamsCollection)
      .doc(teamId);

  await FirebaseFirestore.instance.runTransaction((transaction) async {
    final snapshot = await transaction.get(docRef);
    final data = snapshot.data();
    if (data == null) return;

    final membersRaw = (data['members'] as List<dynamic>?) ?? [];
    final updatedMembers = membersRaw.map((m) {
      final memberMap = Map<String, dynamic>.from(m as Map);
      if (memberMap['id'] == staffId) {
        memberMap['name'] = name;
        memberMap['title'] = title;
        memberMap['phone'] = phone;
        memberMap['isActive'] = isActive;
        if (isActive) {
          memberMap['leaveStartDate'] = null;
          memberMap['leaveEndDate'] = null;
          memberMap['leaveReason'] = null;
        } else {
          memberMap['leaveStartDate'] = leaveStartDate?.toIso8601String();
          memberMap['leaveEndDate'] = leaveEndDate?.toIso8601String();
          memberMap['leaveReason'] = leaveReason;
        }
      }
      return memberMap;
    }).toList();

    transaction.update(docRef, {'members': updatedMembers});
  });

  // Giriş hesabını "users" koleksiyonunda güncelle
  await syncStaffUserAccount(
    phone: phone,
    name: name,
    teamId: teamId,
  );
}

/// Bir personeli ekipten siler/çıkarır.
Future<void> deleteStaffMember({
  required String teamId,
  required String staffId,
}) async {
  final docRef = FirebaseFirestore.instance
      .collection(AppConstants.teamsCollection)
      .doc(teamId);

  await FirebaseFirestore.instance.runTransaction((transaction) async {
    final snapshot = await transaction.get(docRef);
    final data = snapshot.data();
    if (data == null) return;

    final membersRaw = (data['members'] as List<dynamic>?) ?? [];
    final updatedMembers = membersRaw.where((m) {
      final memberMap = Map<String, dynamic>.from(m as Map);
      return memberMap['id'] != staffId;
    }).toList();

    transaction.update(docRef, {'members': updatedMembers});
  });
}

/// Ekip amirinin bilgilerini (ad soyad ve telefon numarası) Firestore'a kaydeder.
Future<void> updateTeamLeader({
  required String teamId,
  required String leaderName,
  required String leaderPhone,
}) async {
  final docRef = FirebaseFirestore.instance
      .collection(AppConstants.teamsCollection)
      .doc(teamId);

  await docRef.update({
    'leaderName': leaderName,
    'leaderPhone': leaderPhone,
  });
}

/// TeamsData'daki sabit demo/başlangıç verisini Firestore'a tek seferlik
/// aktaran migrasyon fonksiyonu.
Future<int> seedTeamsToFirestoreIfEmpty() async {
  final collection =
  FirebaseFirestore.instance.collection(AppConstants.teamsCollection);

  final existing = await collection.limit(1).get();
  if (existing.docs.isNotEmpty) {
    // Ekipler varsa bile personel hesaplarını senkronize et
    await syncAllStaffAccountsToUsersCollection();
    return 0;
  }

  final batch = FirebaseFirestore.instance.batch();
  for (final team in TeamsData.teams) {
    batch.set(collection.doc(team.id), team.toMap());
  }
  await batch.commit();

  // Personel hesaplarını da users koleksiyonuna ekle (varsayılan PIN: 1234)
  await syncAllStaffAccountsToUsersCollection();
  return TeamsData.teams.length;
}