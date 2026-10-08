import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';

// Tüm kullanıcı rolleri için ortak PIN değiştirme ekranını açar
void showChangePinSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const ChangePinBottomSheetContent(),
  );
}

// PIN değiştirme formunu oluşturan widget
class ChangePinBottomSheetContent extends ConsumerStatefulWidget {
  const ChangePinBottomSheetContent({super.key});

  @override
  ConsumerState<ChangePinBottomSheetContent> createState() =>
      _ChangePinBottomSheetContentState();
}

// PIN değiştirme işlemlerini ve form durumunu yöneten sınıf
class _ChangePinBottomSheetContentState
    extends ConsumerState<ChangePinBottomSheetContent> {
  // Form alanlarının ve işlem durumunun bilgilerini tutar
  final _formKey = GlobalKey<FormState>();
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  @override
  void dispose() {
    // Form alanlarına ait controller nesnelerini bellekten temizler
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  // Mevcut PIN'i doğrulayarak yeni PIN'i kaydeder
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Auth provider üzerinden PIN değiştirme işlemini gerçekleştirir
      await ref.read(authControllerProvider.notifier).changePin(
        currentPin: _currentPinController.text.trim(),
        newPin: _newPinController.text.trim(),
      );

      // PIN değiştirme işlemi başarılı olduğunda pencereyi kapatıp mesaj gösterir
      if (mounted) {
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Şifreniz başarıyla güncellendi.'),
            backgroundColor: Colors.green[800],
          ),
        );
      }
    } catch (e) {
      // PIN değiştirme sırasında oluşan hatayı kullanıcıya gösterir
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    } finally {
      // PIN değiştirme işlemi tamamlandığında yükleme durumunu sonlandırır
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // PIN değiştirme formunun ana arayüzünü oluşturur
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // PIN değiştirme ekranının başlık bölümünü oluşturur
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.primary,
                    child: const Icon(
                      Icons.lock_reset,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Şifre Değiştir',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Yeni 4-6 haneli PIN şifrenizi girin',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Kullanıcının mevcut PIN bilgisini girmesini sağlar
              TextFormField(
                controller: _currentPinController,
                keyboardType: TextInputType.number,
                obscureText: _obscureCurrent,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Mevcut Şifre / PIN',
                  prefixIcon: const Icon(Icons.lock_outline),
                  counterText: '',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrent
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () => setState(
                          () => _obscureCurrent = !_obscureCurrent,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Mevcut şifrenizi giriniz.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Kullanıcının yeni PIN bilgisini belirlemesini sağlar
              TextFormField(
                controller: _newPinController,
                keyboardType: TextInputType.number,
                obscureText: _obscureNew,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Yeni Şifre / PIN',
                  hintText: 'En az 4 haneli sayı',
                  prefixIcon: const Icon(Icons.lock_reset),
                  counterText: '',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () => setState(
                          () => _obscureNew = !_obscureNew,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 4) {
                    return 'Yeni şifre en az 4 haneli olmalıdır.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Yeni PIN'in tekrar girilmesini ve eşleşmesini kontrol eder
              TextFormField(
                controller: _confirmPinController,
                keyboardType: TextInputType.number,
                obscureText: _obscureConfirm,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Yeni Şifre (Tekrar)',
                  prefixIcon: const Icon(Icons.lock_reset),
                  counterText: '',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () => setState(
                          () => _obscureConfirm = !_obscureConfirm,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val != _newPinController.text) {
                    return 'Girdiğiniz yeni şifreler eşleşmiyor.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // PIN değiştirme işlemini başlatan kaydetme butonunu oluşturur
              FilledButton.icon(
                onPressed: _isSaving ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _isSaving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.check),
                label: Text(
                  _isSaving
                      ? 'Güncelleniyor...'
                      : 'Şifreyi Güncelle',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}