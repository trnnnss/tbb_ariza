class AppConstants {
  // Cloudinary ayarları
  static const String cloudinaryCloudName = 'o2guor5m';
  static const String cloudinaryUploadPreset = 'tbb_ariza';
  static const String cloudinaryUploadUrl =
      'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload';
  // Video yüklemeleri (öncesi/sonrası müdahale videosu) için ayrı Cloudinary
  // endpoint'i - aynı preset kullanılır, sadece resource_type değişir.
  static const String cloudinaryVideoUploadUrl =
      'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/video/upload';

  // Firestore koleksiyon isimleri
  static const String usersCollection = 'users';
  static const String issuesCollection = 'issues'; // arızalar
  static const String neighborhoodsCollection = 'neighborhoods'; // mahalleler
static const String teamsCollection = 'teams'; // saha ekipleri & personel
}