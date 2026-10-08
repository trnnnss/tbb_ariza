import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../models/issues_model.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

/// Giriş yapan kullanıcının arızalarını canlı olarak dinler.
final userIssuesProvider = StreamProvider<List<Issue>>((ref) {
// Oturumdaki kullanıcıyı alıyoruz.
final authState = ref.watch(authControllerProvider);
final user = authState.asData?.value;

// Kullanıcı giriş yapmamışsa boş liste döner.
if (user == null) {
return Stream.value(<Issue>[]);
}

// Kullanıcıya ait arızaları Firestore'dan canlı olarak dinler.
return FirebaseFirestore.instance
    .collection(AppConstants.issuesCollection)
    .where('reporterPhone', isEqualTo: user.phone)
    .snapshots()
    .map(
(snapshot) {
// Firestore verilerini Issue modeline dönüştürüyoruz.
final issues = snapshot.docs
    .map((doc) => Issue.fromMap(doc.id, doc.data()))
    .toList();

// En yeni arızayı üstte gösteriyoruz.
issues.sort((a, b) => b.createdAt.compareTo(a.createdAt));
return issues;
},
);
});

/// Ana ekranda kullanıcının son 3 arızasını gösterir.
final recentUserIssuesProvider = Provider<AsyncValue<List<Issue>>>((ref) {
final issues = ref.watch(userIssuesProvider);

return issues.whenData(
(list) => list.take(3).toList(),
);
});

/// Sistemdeki tüm arızaları yönetici için canlı olarak dinler.
final allIssuesProvider = StreamProvider<List<Issue>>((ref) {
return FirebaseFirestore.instance
    .collection(AppConstants.issuesCollection)
    .snapshots()
    .map((snapshot) {
final issues = snapshot.docs
    .map((doc) => Issue.fromMap(doc.id, doc.data()))
    .toList();

// En yeni arızayı üstte gösteriyoruz.
issues.sort((a, b) => b.createdAt.compareTo(a.createdAt));
return issues;
});
});

/// Arızanın durum, atama ve saha bilgilerini günceller.
Future<void> updateIssueStatus({
required String issueId,
required IssueStatus status,
String? assignedNote,
String? assignedTeamId,
String? assignedTeamName,
String? assignedStaffName,
IssuePriority? priority,
String? actorName,
String? beforePhotoUrl,
String? afterPhotoUrl,
String? videoUrl,
}) async {
final now = DateTime.now();

// Güncellenecek verileri hazırlıyoruz.
final updateData = <String, dynamic>{
'status': status.storageValue,
'assignedNote': assignedNote,
'updatedAt': now.millisecondsSinceEpoch,
'history': FieldValue.arrayUnion([
IssueHistoryEntry(
status: status,
note: assignedNote,
actorName: actorName,
timestamp: now,
).toMap(),
]),
};

// Atanan ekip bilgilerini ekliyoruz.
if (assignedTeamId != null) {
updateData['assignedTeamId'] = assignedTeamId;
updateData['assignedTeamName'] = assignedTeamName;
}

// Atanan personeli ekliyoruz.
if (assignedStaffName != null) {
updateData['assignedStaffName'] = assignedStaffName;
}

// Öncelik bilgisini ekliyoruz.
if (priority != null) {
updateData['priority'] = priority.storageValue;
}

// Saha fotoğraflarını ekliyoruz.
if (beforePhotoUrl != null) {
updateData['beforePhotoUrl'] = beforePhotoUrl;
}

if (afterPhotoUrl != null) {
updateData['afterPhotoUrl'] = afterPhotoUrl;
}

// Video bağlantısını ekliyoruz.
if (videoUrl != null) {
updateData['videoUrl'] = videoUrl;
}

// Arıza kaydını Firestore'da güncelliyoruz.
await FirebaseFirestore.instance
    .collection(AppConstants.issuesCollection)
    .doc(issueId)
    .update(updateData);

// Güncelleme sonrası bildirimleri gönderiyoruz.
try {
final issueDoc = await FirebaseFirestore.instance
    .collection(AppConstants.issuesCollection)
    .doc(issueId)
    .get();

if (issueDoc.exists && issueDoc.data() != null) {
final updatedIssue = Issue.fromMap(issueDoc.id, issueDoc.data()!);
final notifService = NotificationService();

// Arıza ekibe atandığında bildirim gönderiyoruz.
if (assignedTeamId != null) {
await notifService.notifyAssignment(
teamId: assignedTeamId,
teamName: assignedTeamName ?? 'Saha Ekibi',
reporterPhone: updatedIssue.reporterPhone,
categoryName: updatedIssue.category.label,
district: updatedIssue.district,
issueId: issueId,
);
}

// Arıza çözüldüğünde vatandaşa bildirim gönderiyoruz.
if (status == IssueStatus.cozuldu) {
await notifService.notifyIssueResolved(
reporterPhone: updatedIssue.reporterPhone,
teamName: updatedIssue.assignedTeamName ?? 'Belediye Ekipleri',
categoryName: updatedIssue.category.label,
district: updatedIssue.district,
solutionNote: assignedNote ?? 'Arıza başarıyla giderildi.',
issueId: issueId,
);
}
}
} catch (_) {}
}

/// Belirli bir ekibe atanmış arızaları filtreler.
final teamIssuesProvider = Provider.family<List<Issue>, String>((ref, teamId) {
final allAsync = ref.watch(allIssuesProvider);

return allAsync.maybeWhen(
data: (issues) =>
issues.where((i) => i.assignedTeamId == teamId).toList(),
orElse: () => <Issue>[],
);
});

/// Personel ve ekip atamalarına göre görevleri filtreler.
final staffIssuesProvider = Provider<AsyncValue<List<Issue>>>((ref) {
final authUser = ref.watch(authControllerProvider).asData?.value;
final allIssuesAsync = ref.watch(allIssuesProvider);

if (authUser == null) return const AsyncValue.data([]);

return allIssuesAsync.whenData((issues) {
// Personele veya personelin ekibine atanmış arızaları filtreliyoruz.
final filtered = issues.where((issue) {
final isAssignedToMe = issue.assignedStaffName != null &&
issue.assignedStaffName == authUser.name;

final isAssignedToMyTeam = authUser.teamId != null &&
issue.assignedTeamId == authUser.teamId;

return isAssignedToMe || isAssignedToMyTeam;
}).toList();

// Önceliğe, ardından oluşturulma tarihine göre sıralıyoruz.
filtered.sort((a, b) {
final priorityCompare = b.priority.weight.compareTo(a.priority.weight);

if (priorityCompare != 0) return priorityCompare;

return a.createdAt.compareTo(b.createdAt);
});

return filtered;
});
});

