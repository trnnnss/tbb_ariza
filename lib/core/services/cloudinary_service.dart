import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';

/// Arıza fotoğraflarını Cloudinary'ye yükleyip erişim adresini döndürür.
class CloudinaryService {
  /// [imageFile] Cloudinary'ye "unsigned upload" olarak gönderilir
  /// (bkz. `AppConstants.cloudinaryUploadPreset`). Başarılı olursa
  /// fotoğrafın herkese açık URL'sini döndürür.
  Future<String> uploadImage(File imageFile) {
    return _upload(
      file: imageFile,
      uploadUrl: AppConstants.cloudinaryUploadUrl,
      failureLabel: 'Fotoğraf',
    );
  }

  /// [videoFile] saha personelinin müdahale sırasında (isteğe bağlı olarak)
  /// çektiği videoyu Cloudinary'nin video endpoint'ine "unsigned upload"
  /// olarak gönderir ve herkese açık URL'sini döndürür.
  Future<String> uploadVideo(File videoFile) {
    return _upload(
      file: videoFile,
      uploadUrl: AppConstants.cloudinaryVideoUploadUrl,
      failureLabel: 'Video',
    );
  }

  Future<String> _upload({
    required File file,
    required String uploadUrl,
    required String failureLabel,
  }) async {
    final uri = Uri.parse(uploadUrl);
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = AppConstants.cloudinaryUploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      String errorMessage = 'HTTP ${response.statusCode}';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['error'] != null && data['error']['message'] != null) {
          errorMessage = data['error']['message'] as String;
        }
      } catch (_) {
        errorMessage = response.body;
      }
      throw Exception('$failureLabel yüklenemedi ($errorMessage).');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final url = data['secure_url'] as String?;
    if (url == null) {
      throw Exception('$failureLabel yüklendi ancak bağlantısı alınamadı.');
    }
    return url;
  }
}