import 'package:flutter/material.dart';
import 'issues_model.dart';

/// Saha personelini temsil eden model.
class StaffMember {
final String id;
final String name;
final String title;
final String phone;
final bool isActive;
final DateTime? leaveStartDate;
final DateTime? leaveEndDate;
final String? leaveReason;

const StaffMember({
required this.id,
required this.name,
required this.title,
required this.phone,
this.isActive = true,
this.leaveStartDate,
this.leaveEndDate,
this.leaveReason,
});

// Personel bilgilerini Firestore formatına dönüştürür.
Map<String, dynamic> toMap() => {
'id': id,
'name': name,
'title': title,
'phone': phone,
'isActive': isActive,
'leaveStartDate': leaveStartDate?.toIso8601String(),
'leaveEndDate': leaveEndDate?.toIso8601String(),
'leaveReason': leaveReason,
};

// Firestore verisini StaffMember modeline dönüştürür.
factory StaffMember.fromMap(Map<String, dynamic> map) => StaffMember(
id: map['id'] ?? '',
name: map['name'] ?? '',
title: map['title'] ?? '',
phone: map['phone'] ?? '',
isActive: map['isActive'] ?? true,
leaveStartDate: map['leaveStartDate'] != null
? DateTime.tryParse(map['leaveStartDate'] as String)
    : null,
leaveEndDate: map['leaveEndDate'] != null
? DateTime.tryParse(map['leaveEndDate'] as String)
    : null,
leaveReason: map['leaveReason'] as String?,
);
}

/// Arıza müdahale ekiplerini temsil eden model.
class Team {
final String id;
final String name;
final String department;
final IssueCategory category;
final String leaderName;
final String leaderPhone;
final Color color;
final IconData icon;
final List<StaffMember> members;

const Team({
required this.id,
required this.name,
required this.department,
required this.category,
required this.leaderName,
required this.leaderPhone,
required this.color,
required this.icon,
required this.members,
});

// Ekip bilgilerini Firestore formatına dönüştürür.
Map<String, dynamic> toMap() => {
'name': name,
'department': department,
'category': category.storageValue,
'leaderName': leaderName,
'leaderPhone': leaderPhone,
'color': color.toARGB32(),
'iconCodePoint': icon.codePoint,
'iconFontFamily': icon.fontFamily,
'members': members.map((m) => m.toMap()).toList(),
};

// Firestore verisini Team modeline dönüştürür.
factory Team.fromMap(String id, Map<String, dynamic> map) {
final cat = IssueCategoryX.fromStorage((map['category'] as String?) ?? '');

// Kategoriye göre ekip ikonu belirlenir.
IconData teamIcon;
switch (cat) {
case IssueCategory.su:
teamIcon = Icons.water_drop_outlined;
break;
case IssueCategory.yol:
teamIcon = Icons.add_road;
break;
case IssueCategory.aydinlatma:
teamIcon = Icons.lightbulb_outline;
break;
case IssueCategory.cop:
teamIcon = Icons.delete_outline;
break;
case IssueCategory.diger:
teamIcon = Icons.park_outlined;
break;
}

return Team(
id: id,
name: (map['name'] as String?) ?? '',
department: (map['department'] as String?) ?? '',
category: cat,
leaderName: (map['leaderName'] as String?) ?? '',
leaderPhone: (map['leaderPhone'] as String?) ?? '',
color: Color((map['color'] as int?) ?? 0xFF1976D2),
icon: teamIcon,
members: ((map['members'] as List<dynamic>?) ?? [])
    .map((m) => StaffMember.fromMap(Map<String, dynamic>.from(m as Map)))
    .toList(),
);
}
}

/// Firestore'a başlangıç verisi sağlayan ekip ve personel listesi.
///
/// Uygulamada canlı veri kaynağı olarak kullanılmaz.
/// Firestore'daki teams koleksiyonunu ilk kez doldurmak için kullanılır.
class TeamsData {
static const List<Team> teams = [
Team(
id: 'tiski_su',
name: 'TİSKİ Su & Kanalizasyon Ekibi',
department: 'Trabzon İçmesuyu ve Kanalizasyon İdaresi',
category: IssueCategory.su,
leaderName: 'Murat Kara',
leaderPhone: '0462 300 00 01',
color: Color(0xFF0288D1),
icon: Icons.water_drop_outlined,
members: [
StaffMember(id: 'staff_su_1', name: 'Murat Kara', title: 'Ekip Amiri', phone: '0532 111 22 31'),
StaffMember(id: 'staff_su_2', name: 'Hakan Yılmaz', title: 'Tesisat Teknisyeni', phone: '0532 111 22 32'),
StaffMember(id: 'staff_su_3', name: 'Mustafa Çelik', title: 'Kanal Arıza Personeli', phone: '0532 111 22 33'),
StaffMember(id: 'staff_su_4', name: 'Ali Şahin', title: 'Saha Operatörü', phone: '0532 111 22 34'),
],
),
Team(
id: 'fen_yol',
name: 'Fen İşleri Asfalt & Yol Ekibi',
department: 'Fen İşleri Daire Başkanlığı',
category: IssueCategory.yol,
leaderName: 'Serkan Aydın',
leaderPhone: '0462 300 00 02',
color: Color(0xFFE65100),
icon: Icons.add_road,
members: [
StaffMember(id: 'staff_yol_1', name: 'Serkan Aydın', title: 'Yol Bakım Şefi', phone: '0533 222 33 41'),
StaffMember(id: 'staff_yol_2', name: 'Emre Öztürk', title: 'Asfalt Yama Operatörü', phone: '0533 222 33 42'),
StaffMember(id: 'staff_yol_3', name: 'Gökhan Yavuz', title: 'Kaldırım Ustası', phone: '0533 222 33 43'),
StaffMember(id: 'staff_yol_4', name: 'Fatih Demir', title: 'İş Makinesi Operatörü', phone: '0533 222 33 44'),
],
),
Team(
id: 'enerji_aydinlatma',
name: 'Enerji & Cadde Aydınlatma Ekibi',
department: 'Ulaşım ve Enerji Dairesi',
category: IssueCategory.aydinlatma,
leaderName: 'Okan Arslan',
leaderPhone: '0462 300 00 03',
color: Color(0xFFF57F17),
icon: Icons.lightbulb_outline,
members: [
StaffMember(id: 'staff_ayd_1', name: 'Okan Arslan', title: 'Elektrik Mühendisi', phone: '0534 333 44 51'),
StaffMember(id: 'staff_ayd_2', name: 'Selim Kurt', title: 'Yüksek Gerilim Teknisyeni', phone: '0534 333 44 52'),
StaffMember(id: 'staff_ayd_3', name: 'Burak Koç', title: 'Aydınlatma Saha Personeli', phone: '0534 333 44 53'),
],
),
Team(
id: 'temizlik_cop',
name: 'Temizlik İşleri & Çevre Koruma',
department: 'Çevre Koruma ve Kontrol Dairesi',
category: IssueCategory.cop,
leaderName: 'Kemal Aksoy',
leaderPhone: '0462 300 00 04',
color: Color(0xFF388E3C),
icon: Icons.delete_outline,
members: [
StaffMember(id: 'staff_cop_1', name: 'Kemal Aksoy', title: 'Temizlik Denetim Şefi', phone: '0535 444 55 61'),
StaffMember(id: 'staff_cop_2', name: 'Yusuf Yıldız', title: 'Saha Denetmeni', phone: '0535 444 55 62'),
StaffMember(id: 'staff_cop_3', name: 'Hasan Erdoğan', title: 'Konteyner ve Geri Dönüşüm Ekibi', phone: '0535 444 55 63'),
],
),
Team(
id: 'park_bahceler',
name: 'Park, Bahçeler & Kent Estetiği',
department: 'Park ve Bahçeler Dairesi',
category: IssueCategory.diger,
leaderName: 'Levent Bektaş',
leaderPhone: '0462 300 00 05',
color: Color(0xFF6A1B9A),
icon: Icons.park_outlined,
members: [
StaffMember(id: 'staff_diger_1', name: 'Levent Bektaş', title: 'Peyzaj ve Donatı Şefi', phone: '0536 555 66 71'),
StaffMember(id: 'staff_diger_2', name: 'İsmail Kaya', title: 'Ağaç Budama ve Saha Ustası', phone: '0536 555 66 72'),
StaffMember(id: 'staff_diger_3', name: 'Eren Tunç', title: 'Kentsel Donatı Bakım Personeli', phone: '0536 555 66 73'),
],
),
];

// ID'ye göre ekip bulur.
static Team? getTeamById(String? id) {
if (id == null) return null;

try {
return teams.firstWhere((t) => t.id == id);
} catch (_) {
return null;
}
}

// Arıza kategorisine göre ilgili ekibi bulur.
static Team? getTeamForCategory(IssueCategory category) {
try {
return teams.firstWhere((t) => t.category == category);
} catch (_) {
return teams.last;
}
}
}

