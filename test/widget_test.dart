import 'package:flutter_test/flutter_test.dart';
import 'package:tbb/core/constants/neighborhoods_data.dart';
import 'package:tbb/core/models/app_user.dart';
import 'package:tbb/core/models/issues_model.dart';
import 'package:tbb/core/models/team_model.dart';
import 'package:tbb/core/utils/phone_formatter.dart';

void main() {
  test('NeighborhoodsData should contain Trabzon districts and neighborhoods', () {
    expect(NeighborhoodsData.districtNames.contains('Ortahisar'), isTrue);
    expect(NeighborhoodsData.districtNames.contains('Akçaabat'), isTrue);

    final ortahisarNeighborhoods = NeighborhoodsData.neighborhoodsOf('Ortahisar');
    expect(ortahisarNeighborhoods.isNotEmpty, isTrue);
    expect(ortahisarNeighborhoods.contains('Boztepe'), isTrue);
  });

  test('Issue model should parse from Map and serialize to Map correctly', () {
    final now = DateTime.now();
    final issue = Issue(
      id: 'test_123',
      reporterPhone: '5551234567',
      reporterName: 'Ahmet',
      category: IssueCategory.yol,
      description: 'Yolda çukur var',
      district: 'Ortahisar',
      neighborhood: 'Boztepe',
      status: IssueStatus.beklemede,
      createdAt: now,
      updatedAt: now,
    );

    final map = issue.toMap();
    expect(map['category'], equals('yol'));
    expect(map['status'], equals('beklemede'));

    final parsed = Issue.fromMap('test_123', map);
    expect(parsed.reporterPhone, equals('5551234567'));
    expect(parsed.category, equals(IssueCategory.yol));
    expect(parsed.status, equals(IssueStatus.beklemede));
  });

  test('Issue model should serialize and parse team assignment fields', () {
    final now = DateTime.now();
    final issue = Issue(
      id: 'test_assigned',
      reporterPhone: '5551112233',
      reporterName: 'Mehmet',
      category: IssueCategory.su,
      description: 'Su borusu patladı',
      district: 'Ortahisar',
      neighborhood: 'Meydan',
      status: IssueStatus.islemeAlindi,
      createdAt: now,
      updatedAt: now,
      assignedTeamId: 'tiski_su',
      assignedTeamName: 'TİSKİ Su & Kanalizasyon Ekibi',
      assignedStaffName: 'Murat Kara',
      assignedNote: 'Ekipler sevk edildi',
    );

    final map = issue.toMap();
    expect(map['assignedTeamId'], equals('tiski_su'));
    expect(map['assignedTeamName'], equals('TİSKİ Su & Kanalizasyon Ekibi'));
    expect(map['assignedStaffName'], equals('Murat Kara'));
    expect(map['assignedNote'], equals('Ekipler sevk edildi'));

    final parsed = Issue.fromMap('test_assigned', map);
    expect(parsed.assignedTeamId, equals('tiski_su'));
    expect(parsed.assignedTeamName, equals('TİSKİ Su & Kanalizasyon Ekibi'));
    expect(parsed.assignedStaffName, equals('Murat Kara'));
    expect(parsed.assignedNote, equals('Ekipler sevk edildi'));
  });

  test('TeamsData should contain municipal units and personnel', () {
    expect(TeamsData.teams.length, equals(5));

    final tiski = TeamsData.getTeamById('tiski_su');
    expect(tiski, isNotNull);
    expect(tiski!.name, contains('TİSKİ'));
    expect(tiski.members.isNotEmpty, isTrue);

    final recommendedTeam = TeamsData.getTeamForCategory(IssueCategory.su);
    expect(recommendedTeam?.id, equals('tiski_su'));

    final yolTeam = TeamsData.getTeamForCategory(IssueCategory.yol);
    expect(yolTeam?.id, equals('fen_yol'));
  });

  test('TurkishPhoneFormatter should format numbers to (5XX) - XXX - XX XX format', () {
    final formatter = TurkishPhoneFormatter();
    
    // Test 1: Typing full 10 digits
    final result = formatter.formatEditUpdate(
      const TextEditingValue(text: ''),
      const TextEditingValue(text: '5321234567'),
    );
    expect(result.text, equals('(532) - 123 - 45 67'));

    // Test 2: Typing with leading 0
    final resultWithZero = formatter.formatEditUpdate(
      const TextEditingValue(text: ''),
      const TextEditingValue(text: '05321234567'),
    );
    expect(resultWithZero.text, equals('(532) - 123 - 45 67'));

    // Test 3: Partial typing
    final partial = formatter.formatEditUpdate(
      const TextEditingValue(text: ''),
      const TextEditingValue(text: '532'),
    );
    expect(partial.text, equals('(532) - '));
  });

  test('Issues should filter correctly by date range and district', () {
    final t1 = DateTime(2024, 9, 1);
    final t2 = DateTime(2024, 9, 5);
    final t3 = DateTime(2024, 9, 10);

    final issues = [
      Issue(
        id: '1',
        reporterPhone: '5551112233',
        reporterName: 'Ahmet',
        category: IssueCategory.su,
        description: 'Su patlağı',
        district: 'Ortahisar',
        neighborhood: 'Boztepe',
        status: IssueStatus.beklemede,
        createdAt: t1,
        updatedAt: t1,
      ),
      Issue(
        id: '2',
        reporterPhone: '5552223344',
        reporterName: 'Mehmet',
        category: IssueCategory.yol,
        description: 'Çukur',
        district: 'Akçaabat',
        neighborhood: 'Söğütlü',
        status: IssueStatus.cozuldu,
        createdAt: t2,
        updatedAt: t2,
      ),
      Issue(
        id: '3',
        reporterPhone: '5553334455',
        reporterName: 'Can',
        category: IssueCategory.aydinlatma,
        description: 'Lamba yanmıyor',
        district: 'Ortahisar',
        neighborhood: 'Çukurçayır',
        status: IssueStatus.islemeAlindi,
        createdAt: t3,
        updatedAt: t3,
      ),
    ];

    // District filter test: only Ortahisar
    final ortahisarOnly = issues.where((i) => i.district == 'Ortahisar').toList();
    expect(ortahisarOnly.length, equals(2));

    // Date range filter test: 03.09.2024 to 07.09.2024 (should match only t2)
    final start = DateTime(2024, 9, 3);
    final end = DateTime(2024, 9, 7, 23, 59, 59);
    final inRange = issues.where((i) => !i.createdAt.isBefore(start) && !i.createdAt.isAfter(end)).toList();
    expect(inRange.length, equals(1));
    expect(inRange.first.id, equals('2'));
  });

  test('AppUser model should support personel role and team info', () {
    final now = DateTime.now();
    final staffUser = AppUser(
      id: '5559998877',
      phone: '5559998877',
      pinHash: 'hash123',
      name: 'Murat Kara',
      role: UserRole.personel,
      teamId: 'tiski_su',
      teamName: 'TİSKİ Su & Kanalizasyon Ekibi',
      createdAt: now,
    );

    final map = staffUser.toMap();
    expect(map['role'], equals('personel'));
    expect(map['teamId'], equals('tiski_su'));
    expect(map['teamName'], equals('TİSKİ Su & Kanalizasyon Ekibi'));

    final parsed = AppUser.fromMap('5559998877', map);
    expect(parsed.role, equals(UserRole.personel));
    expect(parsed.teamId, equals('tiski_su'));
    expect(parsed.teamName, equals('TİSKİ Su & Kanalizasyon Ekibi'));
  });

  test('AppUser model should serialize and parse email field', () {
    final now = DateTime.now();
    final user = AppUser(
      id: '5551234567',
      phone: '5551234567',
      pinHash: 'hash321',
      name: 'Ali Veli',
      email: 'ali.veli@trabzon.bel.tr',
      role: UserRole.vatandas,
      createdAt: now,
    );

    final map = user.toMap();
    expect(map['email'], equals('ali.veli@trabzon.bel.tr'));

    final parsed = AppUser.fromMap('5551234567', map);
    expect(parsed.email, equals('ali.veli@trabzon.bel.tr'));
  });
}


