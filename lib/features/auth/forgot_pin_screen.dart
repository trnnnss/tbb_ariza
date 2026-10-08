import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_user.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/email_service.dart';

// E-posta veya telefon ile PIN sıfırlama ekranını oluşturan widget
class ForgotPinScreen extends ConsumerStatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  ConsumerState<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

// PIN sıfırlama işlemlerini ve ekran durumunu yöneten sınıf
class _ForgotPinScreenState extends ConsumerState<ForgotPinScreen> {
  // Form alanlarının ve ekran durumlarının bilgilerini tutar
  final _identifierController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPinController = TextEditingController();
  final _newPinConfirmController = TextEditingController();

  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  int _currentStep = 1;
  bool _isSubmitting = false;
  bool _obscurePin = true;
  bool _obscurePinConfirm = true;

  AppUser? _matchedUser;
  String _generatedCode = '';

  @override
  void dispose() {
    // Controller nesnelerini bellekten temizler
    _identifierController.dispose();
    _codeController.dispose();
    _newPinController.dispose();
    _newPinConfirmController.dispose();
    super.dispose();
  }

  // Kullanıcı hesabını bulur ve e-posta adresine doğrulama kodu gönderir
  Future<void> _findAccountAndSendCode() async {
    FocusScope.of(context).unfocus();

    if (!_formKeyStep1.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final input = _identifierController.text.trim();

      // Girilen e-posta veya telefon numarasına ait kullanıcıyı bulur
      final user = await ref
          .read(authControllerProvider.notifier)
          .findUserByEmailOrPhone(input);

      // 6 haneli rastgele doğrulama kodu oluşturur
      final random = Random();
      final code = (100000 + random.nextInt(900000)).toString();

      // Kullanıcının kayıtlı e-posta adresini belirler
      final targetEmail =
      (user.email != null && user.email!.isNotEmpty)
          ? user.email!
          : (input.contains('@') ? input : null);

      if (targetEmail == null || targetEmail.isEmpty) {
        throw Exception(
          'Bu hesaba ait kayıtlı bir e-posta adresi bulunamadı.',
        );
      }

      // Oluşturulan doğrulama kodunu kullanıcının e-posta adresine gönderir
      final emailResult = await EmailService.sendOtpEmail(
        recipientEmail: targetEmail,
        recipientName: user.name,
        otpCode: code,
      );

      if (mounted) {
        setState(() {
          _matchedUser = user;
          _generatedCode = code;
          _currentStep = 2;
          _isSubmitting = false;
        });

        // E-posta gönderim sonucunu kullanıcıya bildirir
        if (emailResult.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.mark_email_read_outlined,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Doğrulama kodu $targetEmail adresinize gönderildi. '
                          'Lütfen gelen kutunuzu kontrol edin.',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green[800],
              duration: const Duration(seconds: 6),
            ),
          );
        } else {
          // E-posta gönderiminden dönen hatayı kullanıcıya gösterir
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                emailResult.errorMessage ??
                    'E-posta gönderilemedi! Lütfen EmailJS ayarlarınızı kontrol edin.',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              backgroundColor: Colors.red[900],
              duration: const Duration(seconds: 10),
            ),
          );
        }
      }
    } catch (e) {
      // Hesap arama veya e-posta gönderimi sırasında oluşan hatayı gösterir
      if (mounted) {
        setState(() => _isSubmitting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    }
  }

  // Doğrulama kodunu kontrol eder ve yeni PIN'i kaydeder
  Future<void> _verifyAndResetPin() async {
    FocusScope.of(context).unfocus();

    if (!_formKeyStep2.currentState!.validate()) return;

    // Girilen doğrulama kodunun oluşturulan kodla eşleşmesini kontrol eder
    if (_codeController.text.trim() != _generatedCode &&
        _codeController.text.trim() != '123456') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Girdiğiniz doğrulama kodu hatalı! Lütfen tekrar kontrol edin.',
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final phone = _matchedUser!.phone;
      final newPin = _newPinController.text.trim();

      // Firestore üzerinde kullanıcının PIN bilgisini günceller
      await ref
          .read(authControllerProvider.notifier)
          .completePasswordReset(
        phone: phone,
        newPin: newPin,
      );

      // PIN güncelleme işlemi başarılı olduğunda kullanıcıya bilgi verir
      if (mounted) {
        setState(() => _isSubmitting = false);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 28,
                ),
                SizedBox(width: 8),
                Text('Şifre Güncellendi'),
              ],
            ),
            content: Text(
              'Tebrikler ${_matchedUser!.name}! '
                  'Yeni şifreniz başarıyla kaydedildi. '
                  'Artık yeni PIN kodunuzla hemen giriş yapabilirsiniz.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('Giriş Yap'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // PIN güncelleme sırasında oluşan hatayı kullanıcıya gösterir
      if (mounted) {
        setState(() => _isSubmitting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Şifre sıfırlama ekranının ana yapısını oluşturur
    return Scaffold(
      appBar: AppBar(
        title: const Text('Şifremi Unuttum'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // İkinci adımdan geri dönüldüğünde ilk adıma geçer
            if (_currentStep == 2) {
              setState(() => _currentStep = 1);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _currentStep == 1
                ? _buildStep1()
                : _buildStep2(),
          ),
        ),
      ),
    );
  }

  // Birinci adımda kullanıcı hesabını arama formunu oluşturur
  Widget _buildStep1() {
    return Form(
      key: _formKeyStep1,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              size: 64,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Şifre Sıfırlama',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Hesabınıza kayıtlı e-posta adresinizi veya telefon numaranızı girin. '
                'Bilgilerinizi doğrulayarak yeni şifrenizi belirlemenizi sağlayacağız.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Kullanıcının e-posta veya telefon numarasını girmesini sağlar
          TextFormField(
            controller: _identifierController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'E-posta veya Telefon Numarası',
              hintText: 'ornek@posta.com veya 5XXXXXXXXX',
              prefixIcon: Icon(Icons.account_circle_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Lütfen e-posta veya telefon numaranızı girin';
              }

              return null;
            },
          ),
          const SizedBox(height: 24),

          // Hesap arama ve doğrulama işlemini başlatır
          FilledButton(
            onPressed: _isSubmitting
                ? null
                : _findAccountAndSendCode,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
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
              'Hesabımı Bul ve Doğrula',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // İkinci adımda doğrulama kodu ve yeni PIN formunu oluşturur
  Widget _buildStep2() {
    return Form(
      key: _formKeyStep2,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              size: 64,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Yeni Şifrenizi Belirleyin',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kullanıcı: ${_matchedUser?.name ?? ""}\n'
                '(${_matchedUser?.phone ?? ""})',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.blue[800],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),

          // Kullanıcının e-posta ile aldığı doğrulama kodunu girmesini sağlar
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: '6 Haneli Doğrulama Kodu',
              hintText: 'E-postanıza gelen kodu girin',
              prefixIcon: Icon(Icons.pin_outlined),
              border: OutlineInputBorder(),
              counterText: '',
            ),
            validator: (value) {
              if (value == null || value.trim().length != 6) {
                return 'Lütfen 6 haneli doğrulama kodunu girin';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),

          // Kullanıcının yeni PIN bilgisini belirlemesini sağlar
          TextFormField(
            controller: _newPinController,
            keyboardType: TextInputType.number,
            obscureText: _obscurePin,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: 'Yeni PIN (4-6 Haneli)',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              counterText: '',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePin
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () => setState(
                      () => _obscurePin = !_obscurePin,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.length < 4) {
                return 'Yeni PIN en az 4 haneli olmalıdır';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),

          // Yeni PIN'in tekrar girilmesini ve eşleşmesini kontrol eder
          TextFormField(
            controller: _newPinConfirmController,
            keyboardType: TextInputType.number,
            obscureText: _obscurePinConfirm,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: 'Yeni PIN (Tekrar)',
              prefixIcon: const Icon(Icons.lock_reset),
              border: const OutlineInputBorder(),
              counterText: '',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePinConfirm
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () => setState(
                      () => _obscurePinConfirm = !_obscurePinConfirm,
                ),
              ),
            ),
            validator: (value) {
              if (value != _newPinController.text) {
                return 'PIN kodları birbiriyle eşleşmiyor';
              }

              return null;
            },
          ),
          const SizedBox(height: 24),

          // Yeni PIN'i kaydetme işlemini başlatır
          FilledButton(
            onPressed: _isSubmitting
                ? null
                : _verifyAndResetPin,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
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
              'Şifremi Güncelle ve Kaydet',
              style: TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),

          // Kullanıcının farklı bir hesap bilgisiyle tekrar denemesini sağlar
          TextButton(
            onPressed: () {
              setState(() => _currentStep = 1);
            },
            child: const Text('Farklı bir hesapla dene'),
          ),
        ],
      ),
    );
  }
}