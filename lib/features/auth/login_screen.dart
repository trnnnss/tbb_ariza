import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/phone_formatter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import 'register_screen.dart';
import 'forgot_pin_screen.dart';

// Kullanıcı giriş ekranını oluşturan widget
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

// Giriş formunu ve giriş işlemlerini yöneten sınıf
class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Form ve giriş alanlarının durumlarını tutar
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePin = true;
  int _failedAttempts = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  // Formu doğrulayarak kullanıcı giriş işlemini gerçekleştirir
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // Auth provider üzerinden kullanıcı girişini gerçekleştirir
      await ref.read(authControllerProvider.notifier).login(
        phone: _phoneController.text,
        pin: _pinController.text,
      );
    } catch (e) {
      // Giriş hatasını kullanıcıya gösterir ve başarısız giriş sayısını artırır
      if (mounted) {
        setState(() => _failedAttempts++);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }
    } finally {
      // Giriş işlemi tamamlandığında yükleme durumunu sonlandırır
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Giriş ekranının ana arayüzünü oluşturur
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.location_city,
                    size: 64,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),

                  // Uygulama başlığını gösterir
                  Text(
                    'TBB Arıza Bildirim',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 32),

                  // Kullanıcının telefon numarasını girmesini sağlar
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

                  // Kullanıcının PIN bilgisini güvenli şekilde girmesini sağlar
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
                      labelText: 'PIN',
                      prefixIcon: const Icon(Icons.lock),
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
                        return 'En az 4 haneli PIN girin';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Kullanıcı giriş işlemini başlatan butonu oluşturur
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
                        : const Text('Giriş Yap'),
                  ),
                  const SizedBox(height: 16),

                  // PIN unutulduğunda şifre yenileme ekranına yönlendirir
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ForgotPinScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange[800],
                    ),
                    child: const Text('Şifrenizi mi unuttunuz?'),
                  ),

                  // Yeni kullanıcıların kayıt ekranına geçmesini sağlar
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text('Hesabın yok mu? Kayıt ol'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}