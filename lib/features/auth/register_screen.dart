import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/phone_formatter.dart';
import '../../core/constants/neighborhoods_data.dart';
import '../../core/providers/auth_provider.dart';

// Kullanıcı kayıt ekranını oluşturan widget
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

// Kayıt formundaki alanları ve geçici durumları yöneten sınıf
class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  // Form alanlarının ve kayıt işleminin durum bilgilerini tutar
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();
  String? _selectedDistrict;
  String? _selectedNeighborhood;
  bool _isSubmitting = false;
  bool _obscurePin = true;
  bool _obscurePinConfirm = true;

  // Form alanlarına ait controller nesnelerini bellekten temizler
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _pinController.dispose();
    _pinConfirmController.dispose();
    super.dispose();
  }

  // Form bilgilerini doğrulayarak kullanıcı kayıt işlemini gerçekleştirir
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    // Formdaki alanların doğrulamasını yapar
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // Auth provider üzerinden yeni kullanıcı kaydı oluşturur
      await ref.read(authControllerProvider.notifier).register(
        phone: _phoneController.text,
        pin: _pinController.text,
        name: _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        neighborhood: '$_selectedDistrict / $_selectedNeighborhood',
      );

      // Kayıt başarılı olduğunda önceki ekrana döner
      if (mounted) Navigator.of(context).maybePop();
    } catch (e){//hatayı yakalar
      // Kayıt sırasında oluşan hatayı kullanıcıya gösterir
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }
    } finally {
      // Kayıt işlemi tamamlandığında yükleme durumunu sonlandırır
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kayıt formunun ana ekran yapısını oluşturur
    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt Ol')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Kullanıcının ad ve soyad bilgisini alır
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Ad Soyad',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                  (value == null || value.trim().isEmpty)
                      ? 'Ad soyad girin'
                      : null,
                ),
                const SizedBox(height: 16),

                // Kullanıcının isteğe bağlı e-posta adresini alır ve doğrular
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-posta Adresi',
                    hintText: 'ornek@posta.com',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final emailRegex =
                      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

                      if (!emailRegex.hasMatch(value.trim())) {
                        return 'Geçerli bir e-posta adresi girin';
                      }
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Kullanıcının telefon numarasını alır ve Türk telefon formatına göre düzenler
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9()\- ]'),
                    ),
                    TurkishPhoneFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Telefon Numarası',
                    hintText: '(5XX) - XXX - XX XX',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Telefon numarası girin';
                    }

                    final digits =
                    value.replaceAll(RegExp(r'[^0-9]'), '');

                    if (digits.length < 10) {
                      return 'Geçerli bir telefon numarası girin (en az 10 hane)';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Kullanıcının ilçe seçmesini sağlayan açılır liste
                DropdownButtonFormField<String>(
                  key: ValueKey('district_$_selectedDistrict'),
                  initialValue:
                  (NeighborhoodsData.districtNames.contains(
                    _selectedDistrict,
                  ))
                      ? _selectedDistrict
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'İlçe',
                    prefixIcon: Icon(Icons.map),
                    border: OutlineInputBorder(),
                  ),
                  items: NeighborhoodsData.districtNames
                      .map(
                        (d) => DropdownMenuItem(
                      value: d,
                      child: Text(d),
                    ),
                  )
                      .toList(),
                  onChanged: (value) {
                    // İlçe değiştiğinde seçili mahalleyi sıfırlar
                    setState(() {
                      _selectedDistrict = value;
                      _selectedNeighborhood = null;
                    });
                  },
                  validator: (value) =>
                  value == null ? 'İlçe seçin' : null,
                ),
                const SizedBox(height: 16),

                // Seçilen ilçeye göre mahalle listesini oluşturur
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'neighborhood_${_selectedDistrict}_$_selectedNeighborhood',
                  ),
                  initialValue:
                  (_selectedDistrict != null &&
                      NeighborhoodsData.neighborhoodsOf(
                        _selectedDistrict!,
                      ).contains(_selectedNeighborhood))
                      ? _selectedNeighborhood
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Mahalle',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                  items: _selectedDistrict == null
                      ? []
                      : NeighborhoodsData.neighborhoodsOf(
                    _selectedDistrict!,
                  )
                      .map(
                        (n) => DropdownMenuItem(
                      value: n,
                      child: Text(n),
                    ),
                  )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedNeighborhood = value),
                  validator: (value) =>
                  value == null ? 'Mahalle seçin' : null,
                ),
                const SizedBox(height: 16),

                // Kullanıcının 4-6 haneli PIN belirlemesini sağlar
                TextFormField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: _obscurePin,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    labelText: 'PIN (4-6 haneli)',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePin
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePin = !_obscurePin),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 4) {
                      return 'En az 4 haneli PIN girin';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Girilen PIN'in tekrar girilmesini ve doğrulanmasını sağlar
                TextFormField(
                  controller: _pinConfirmController,
                  keyboardType: TextInputType.number,
                  obscureText: _obscurePinConfirm,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    labelText: 'PIN (Tekrar)',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePinConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                            () => _obscurePinConfirm =
                        !_obscurePinConfirm,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value != _pinController.text) {
                      return 'PIN\'ler eşleşmiyor';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Kullanıcı kayıt işlemini başlatan butonu oluşturur
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Text('Kayıt Ol'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}