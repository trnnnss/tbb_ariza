import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/neighborhoods_data.dart';
import '../../core/models/issues_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/services/notification_service.dart';
import '../home/issue_ui_helpers.dart';

class ReportIssueScreen extends ConsumerStatefulWidget {
  /// Ana ekranda bir kategori kartına dokunularak gelindiyse o kategori
  /// önceden seçili gösterilir; kullanıcı yine de değiştirebilir.
  final IssueCategory? initialCategory;
  const ReportIssueScreen({super.key, this.initialCategory});

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _addressDetailController = TextEditingController();

  IssueCategory? _selectedCategory;
  String? _selectedDistrict;
  String? _selectedNeighborhood;
  double? _latitude;
  double? _longitude;
  XFile? _pickedImage;

  bool _isLocating = false;
  bool _isSubmitting = false;
  String? _locationHint;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    final user = ref.read(authControllerProvider).asData?.value;
    if (user?.neighborhood != null && user!.neighborhood!.contains(' / ')) {
      final parts = user.neighborhood!.split(' / ');
      if (parts.length == 2 && NeighborhoodsData.districtNames.contains(parts[0])) {
        _selectedDistrict = parts[0];
        if (NeighborhoodsData.neighborhoodsOf(parts[0]).contains(parts[1])) {
          _selectedNeighborhood = parts[1];
        }
      }
    }
    _detectLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressDetailController.dispose();
    super.dispose();
  }

  // --- Konum: GPS'ten otomatik bul, bulamazsa/kullanıcı isterse elle seçilir ---

  String? _matchDistrict(String? candidate) {
    if (candidate == null || candidate.trim().isEmpty) return null;
    final normalized = candidate.trim().toLowerCase();
    for (final district in NeighborhoodsData.districtNames) {
      final d = district.toLowerCase();
      if (d == normalized || d.contains(normalized) || normalized.contains(d)) {
        return district;
      }
    }
    return null;
  }

  String? _matchNeighborhood(String district, String? candidate) {
    if (candidate == null || candidate.trim().isEmpty) return null;
    final normalized = candidate.trim().toLowerCase();
    for (final n in NeighborhoodsData.neighborhoodsOf(district)) {
      final lower = n.toLowerCase();
      if (lower == normalized || lower.contains(normalized) || normalized.contains(lower)) {
        return n;
      }
    }
    return null;
  }

  Future<void> _detectLocation() async {
    setState(() {
      _isLocating = true;
      _locationHint = null;
    });

    try {
      // 1. Cihazın konum servisi (GPS) açık mı kontrol et
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.location_off, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Konum Servisi Kapalı'),
                ],
              ),
              content: const Text(
                'Cihazınızın GPS / Konum servisi kapalı durumda. Konumunuzun otomatik algılanabilmesi için lütfen konum servisini açınız.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await Geolocator.openLocationSettings();
                  },
                  child: const Text('Konumu Aç'),
                ),
              ],
            ),
          );
        }
        throw Exception('Cihazın konum servisi (GPS) kapalı.');
      }

      // 2. Uygulamanın konum izni kontrolü
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Konum izni reddedildi. Lütfen listeden ilçe ve mahallenizi elle seçiniz.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        throw Exception('Konum izni verilmedi.');
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.security, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Konum İzni Gerekli'),
                ],
              ),
              content: const Text(
                'Uygulamanın konum izni kalıcı olarak engellenmiş. Otomatik konum alabilmek için uygulama ayarlarından konum iznini etkinleştirmeniz gerekmektedir.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await Geolocator.openAppSettings();
                  },
                  child: const Text('Ayarları Aç'),
                ),
              ],
            ),
          );
        }
        throw Exception('Konum izni kalıcı olarak engellendi.');
      }

      // 3. Konumu al
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final placemarks =
          await Geocoding().placemarkFromCoordinates(position.latitude, position.longitude);
      final place = placemarks.isNotEmpty ? placemarks.first : null;

      final matchedDistrict =
          _matchDistrict(place?.subAdministrativeArea) ?? _matchDistrict(place?.locality);
      String? matchedNeighborhood;
      if (matchedDistrict != null) {
        matchedNeighborhood = _matchNeighborhood(matchedDistrict, place?.subLocality) ??
            _matchNeighborhood(matchedDistrict, place?.thoroughfare);
      }

      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        if (matchedDistrict != null) _selectedDistrict = matchedDistrict;
        if (matchedNeighborhood != null) _selectedNeighborhood = matchedNeighborhood;
        _locationHint = matchedNeighborhood != null
            ? 'Konumunuz otomatik bulundu.'
            : 'Konumunuz alındı, lütfen ilçe/mahalleyi kontrol edin.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            matchedNeighborhood != null
                ? 'Konum başarıyla tespit edildi: $_selectedDistrict / $_selectedNeighborhood'
                : 'GPS koordinatları alındı. Lütfen ilçe ve mahallenizi teyit edin.',
          ),
          backgroundColor: Colors.green[800],
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationHint = 'Konum otomatik alınamadı, lütfen aşağıdan elle seçin.';
      });
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // --- Fotoğraf: isteğe bağlı, kamera veya galeriden ---

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera ile çek'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker()
        .pickImage(source: source, imageQuality: 80, maxWidth: 1600);
    if (picked != null && mounted) {
      setState(() => _pickedImage = picked);
    }
  }

  // --- Gönderim ---

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lütfen bir kategori seçin.')));
      return;
    }
    if (_selectedDistrict == null || _selectedNeighborhood == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lütfen ilçe ve mahalle seçin.')));
      return;
    }

    final user = ref.read(authControllerProvider).asData?.value;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    try {
      String? photoUrl;
      if (_pickedImage != null) {
        photoUrl = await CloudinaryService().uploadImage(File(_pickedImage!.path));
      }

      final now = DateTime.now();
      final issue = Issue(
        id: '',
        reporterPhone: user.phone,
        reporterName: user.name,
        category: _selectedCategory!,
        description: _descriptionController.text.trim(),
        district: _selectedDistrict!,
        neighborhood: _selectedNeighborhood!,
        addressDetail: _addressDetailController.text.trim().isEmpty
            ? null
            : _addressDetailController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        photoUrl: photoUrl,
        status: IssueStatus.beklemede,
        createdAt: now,
        updatedAt: now,
      );

      final docRef = await FirebaseFirestore.instance
          .collection(AppConstants.issuesCollection)
          .add(issue.toMap());

      // Yöneticilere anlık bildirim oluştur
      try {
        await NotificationService().notifyAdminsNewIssue(
          district: _selectedDistrict!,
          neighborhood: _selectedNeighborhood!,
          categoryName: _selectedCategory!.label,
          issueId: docRef.id,
        );
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bildiriminiz alındı, teşekkür ederiz.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bir sorun oluştu: ${e.toString().replaceFirst('Exception: ', '')}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Arıza Bildir')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Kategori', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: IssueCategory.values.map((category) {
                    final selected = _selectedCategory == category;
                    return ChoiceChip(
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedCategory = category),
                      avatar: Icon(
                        iconForCategory(category),
                        size: 18,
                        color: selected ? colorScheme.onPrimary : colorScheme.primary,
                      ),
                      label: Text(category.label),
                      selectedColor: colorScheme.primary,
                      labelStyle: TextStyle(
                        color: selected ? colorScheme.onPrimary : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    hintText: 'Arızayı kısaca anlatın',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().length < 5)
                      ? 'Lütfen kısa bir açıklama girin'
                      : null,
                ),
                const SizedBox(height: 20),
                Text('Fotoğraf (opsiyonel)', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _pickedImage == null
                    ? OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Fotoğraf Ekle'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                )
                    : Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_pickedImage!.path),
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    IconButton.filled(
                      onPressed: () => setState(() => _pickedImage = null),
                      icon: const Icon(Icons.close, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Konum', style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _isLocating ? null : _detectLocation,
                      icon: _isLocating
                          ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.my_location, size: 16),
                      label: const Text('Otomatik Algıla'),
                    ),
                  ],
                ),
                if (_locationHint != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _locationHint!,
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  key: ValueKey('district_$_selectedDistrict'),
                  initialValue: (NeighborhoodsData.districtNames.contains(_selectedDistrict))
                      ? _selectedDistrict
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'İlçe',
                    prefixIcon: Icon(Icons.map_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: NeighborhoodsData.districtNames
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedDistrict = value;
                    _selectedNeighborhood = null;
                  }),
                  validator: (value) => value == null ? 'İlçe seçin' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey('neighborhood_${_selectedDistrict}_$_selectedNeighborhood'),
                  initialValue: (_selectedDistrict != null &&
                          NeighborhoodsData.neighborhoodsOf(_selectedDistrict!)
                              .contains(_selectedNeighborhood))
                      ? _selectedNeighborhood
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Mahalle',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _selectedDistrict == null
                      ? const []
                      : NeighborhoodsData.neighborhoodsOf(_selectedDistrict!)
                          .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                          .toList(),
                  onChanged: (value) => setState(() => _selectedNeighborhood = value),
                  validator: (value) => value == null ? 'Mahalle seçin' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressDetailController,
                  decoration: const InputDecoration(
                    labelText: 'Adres Detayı (opsiyonel)',
                    hintText: 'Sokak, kapı no vb.',
                    prefixIcon: Icon(Icons.edit_location_alt_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.tbbRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Bildirimi Gönder',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}