import 'package:cloud_firestore/cloud_firestore.dart';

/// Vatandaşın bildirebileceği arıza kategorileri.
enum IssueCategory { yol, aydinlatma, su, cop, diger }

/// Arızanın işlem durumlarını temsil eder.
enum IssueStatus {
  beklemede,
  islemeAlindi,
  yolda,
  basladi,
  cozuldu,
  ertelendi,
  iptal,
}

/// Arızanın öncelik seviyelerini temsil eder.
enum IssuePriority { dusuk, normal, yuksek, acil }

extension IssuePriorityX on IssuePriority {
  String get label {
    switch (this) {
      case IssuePriority.dusuk:
        return 'Düşük';
      case IssuePriority.normal:
        return 'Normal';
      case IssuePriority.yuksek:
        return 'Yüksek';
      case IssuePriority.acil:
        return 'Acil';
    }
  }

  /// Öncelik sıralamasında kullanılan ağırlık.
  int get weight {
    switch (this) {
      case IssuePriority.dusuk:
        return 0;
      case IssuePriority.normal:
        return 1;
      case IssuePriority.yuksek:
        return 2;
      case IssuePriority.acil:
        return 3;
    }
  }

  String get storageValue => name;

// Firestore verisini öncelik enumuna dönüştürür.
  static IssuePriority fromStorage(String? value) {
    return IssuePriority.values.firstWhere(
          (e) => e.name == value,
      orElse: () => IssuePriority.normal,
    );
  }
}

/// Arızanın durum geçmişindeki tek bir kaydı temsil eder.
class IssueHistoryEntry {
  final IssueStatus status;
  final String? note;
  final String? actorName;
  final DateTime timestamp;

  const IssueHistoryEntry({
    required this.status,
    this.note,
    this.actorName,
    required this.timestamp,
  });

// Firestore verisini geçmiş kaydına dönüştürür.
  factory IssueHistoryEntry.fromMap(Map<String, dynamic> map) {
    final rawTs = map['timestamp'];
    DateTime ts;

    if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else if (rawTs is num) {
      ts = DateTime.fromMillisecondsSinceEpoch(rawTs.toInt());
    } else {
      ts = DateTime.now();
    }

    return IssueHistoryEntry(
      status: IssueStatusX.fromStorage((map['status'] as String?) ?? ''),
      note: map['note'] as String?,
      actorName: map['actorName'] as String?,
      timestamp: ts,
    );
  }

// Geçmiş kaydını Firestore formatına dönüştürür.
  Map<String, dynamic> toMap() => {
    'status': status.storageValue,
    'note': note,
    'actorName': actorName,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };
}

/// Kategori enumu ile Firestore metin değerleri arasındaki dönüşümleri sağlar.
extension IssueCategoryX on IssueCategory {
  String get label {
    switch (this) {
      case IssueCategory.yol:
        return 'Yol';
      case IssueCategory.aydinlatma:
        return 'Aydınlatma';
      case IssueCategory.su:
        return 'Su';
      case IssueCategory.cop:
        return 'Çöp';
      case IssueCategory.diger:
        return 'Diğer';
    }
  }

  String get storageValue => name;

// Firestore verisini kategori enumuna dönüştürür.
  static IssueCategory fromStorage(String value) {
    return IssueCategory.values.firstWhere(
          (e) => e.name == value,
      orElse: () => IssueCategory.diger,
    );
  }
}

/// Durum enumu ile Firestore metin değerleri arasındaki dönüşümleri sağlar.
extension IssueStatusX on IssueStatus {
  String get label {
    switch (this) {
      case IssueStatus.beklemede:
        return 'Beklemede';
      case IssueStatus.islemeAlindi:
        return 'İşleme Alındı';
      case IssueStatus.yolda:
        return 'Yolda';
      case IssueStatus.basladi:
        return 'Başladı';
      case IssueStatus.cozuldu:
        return 'Tamamlandı';
      case IssueStatus.ertelendi:
        return 'Ertelendi';
      case IssueStatus.iptal:
        return 'İptal Edildi';
    }
  }

  /// Arızanın aktif görevlerden çıkarılıp çıkarılmayacağını belirtir.
  bool get isClosed => this == IssueStatus.cozuldu || this == IssueStatus.iptal;

  String get storageValue => name;

// Firestore verisini durum enumuna dönüştürür.
  static IssueStatus fromStorage(String value) {
    return IssueStatus.values.firstWhere(
          (e) => e.name == value,
      orElse: () => IssueStatus.beklemede,
    );
  }
}

/// Bir arıza kaydını temsil eden model.
class Issue {
  final String id;
  final String reporterPhone;
  final String reporterName;
  final IssueCategory category;
  final String description;
  final String district;
  final String neighborhood;
  final String? addressDetail;
  final double? latitude;
  final double? longitude;
  final String? photoUrl;
  final String? beforePhotoUrl;
  final String? afterPhotoUrl;
  final String? videoUrl;
  final IssueStatus status;
  final String? assignedNote;
  final String? assignedTeamId;
  final String? assignedTeamName;
  final String? assignedStaffName;
  final IssuePriority priority;
  final List<IssueHistoryEntry> history;
  final DateTime createdAt;
  final DateTime updatedAt;

  Issue({
    required this.id,
    required this.reporterPhone,
    required this.reporterName,
    required this.category,
    required this.description,
    required this.district,
    required this.neighborhood,
    this.addressDetail,
    this.latitude,
    this.longitude,
    this.photoUrl,
    this.beforePhotoUrl,
    this.afterPhotoUrl,
    this.videoUrl,
    required this.status,
    this.assignedNote,
    this.assignedTeamId,
    this.assignedTeamName,
    this.assignedStaffName,
    this.priority = IssuePriority.normal,
    this.history = const [],
    required this.createdAt,
    required this.updatedAt,
  });

// Farklı tarih formatlarını DateTime'a dönüştürür.
  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    } else if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  }

// Firestore verisini Issue modeline dönüştürür.
  factory Issue.fromMap(String id, Map<String, dynamic> map) {
    return Issue(
      id: id,
      reporterPhone: (map['reporterPhone'] as String?) ?? '',
      reporterName: (map['reporterName'] as String?) ?? '',
      category: IssueCategoryX.fromStorage((map['category'] as String?) ?? ''),
      description: (map['description'] as String?) ?? '',
      district: (map['district'] as String?) ?? '',
      neighborhood: (map['neighborhood'] as String?) ?? '',
      addressDetail: map['addressDetail'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      photoUrl: map['photoUrl'] as String?,
      beforePhotoUrl: map['beforePhotoUrl'] as String?,
      afterPhotoUrl: map['afterPhotoUrl'] as String?,
      videoUrl: map['videoUrl'] as String?,
      status: IssueStatusX.fromStorage((map['status'] as String?) ?? ''),
      assignedNote: map['assignedNote'] as String?,
      assignedTeamId: map['assignedTeamId'] as String?,
      assignedTeamName: map['assignedTeamName'] as String?,
      assignedStaffName: map['assignedStaffName'] as String?,
      priority: IssuePriorityX.fromStorage(map['priority'] as String?),
      history: ((map['history'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (e) => IssueHistoryEntry.fromMap(
          Map<String, dynamic>.from(e),
        ),
      )
          .toList(),
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

// Issue modelini Firestore formatına dönüştürür.
  Map<String, dynamic> toMap() {
    return {
      'reporterPhone': reporterPhone,
      'reporterName': reporterName,
      'category': category.storageValue,
      'description': description,
      'district': district,
      'neighborhood': neighborhood,
      'addressDetail': addressDetail,
      'latitude': latitude,
      'longitude': longitude,
      'photoUrl': photoUrl,
      'beforePhotoUrl': beforePhotoUrl,
      'afterPhotoUrl': afterPhotoUrl,
      'videoUrl': videoUrl,
      'status': status.storageValue,
      'assignedNote': assignedNote,
      'assignedTeamId': assignedTeamId,
      'assignedTeamName': assignedTeamName,
      'assignedStaffName': assignedStaffName,
      'priority': priority.storageValue,
      'history': history.map((e) => e.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Değişen alanları güncelleyerek yeni bir Issue kopyası oluşturur.
  Issue copyWith({
    IssueStatus? status,
    String? assignedNote,
    String? assignedTeamId,
    String? assignedTeamName,
    String? assignedStaffName,
    IssuePriority? priority,
    List<IssueHistoryEntry>? history,
    String? beforePhotoUrl,
    String? afterPhotoUrl,
    String? videoUrl,
    DateTime? updatedAt,
  }) {
    return Issue(
      id: id,
      reporterPhone: reporterPhone,
      reporterName: reporterName,
      category: category,
      description: description,
      district: district,
      neighborhood: neighborhood,
      addressDetail: addressDetail,
      latitude: latitude,
      longitude: longitude,
      photoUrl: photoUrl,
      beforePhotoUrl: beforePhotoUrl ?? this.beforePhotoUrl,
      afterPhotoUrl: afterPhotoUrl ?? this.afterPhotoUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      status: status ?? this.status,
      assignedNote: assignedNote ?? this.assignedNote,
      assignedTeamId: assignedTeamId ?? this.assignedTeamId,
      assignedTeamName: assignedTeamName ?? this.assignedTeamName,
      assignedStaffName: assignedStaffName ?? this.assignedStaffName,
      priority: priority ?? this.priority,
      history: history ?? this.history,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
