import '../../../core/ui/maxvolt_theme.dart';
import '../application/auth_controller.dart';
import '../../../core/config/branding_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.errorText});
  final String? errorText;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  final confirmPass = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  final billingDocument = TextEditingController();
  final billingDocType = TextEditingController(text: 'CI');
  final billingRazonSocial = TextEditingController();
  final emailFocus = FocusNode();
  final billingDocumentFocus = FocusNode();
  bool registerMode = false;
  String? localError;
  bool isValidatingEmail = false;
  String? emailError;
  bool isValidatingNit = false;
  String? nitError;

  // New state variables for password visibility and validation errors
  bool _obscurePass = true;
  bool _obscureConfirmPass = true;
  String? nameError;
  String? passError;
  String? confirmPassError;
  String? billingRazonSocialError;
  String? phoneError;

  void _validateBillingRazonSocial(String value) {
    if (!registerMode) return;
    setState(() {
      final valueTrim = value.trim();
      if (valueTrim.isEmpty) {
        billingRazonSocialError = 'La razón social es obligatoria';
      } else {
        billingRazonSocialError = null;
      }
    });
  }

  void _validatePhone(String value) {
    if (!registerMode) return;
    setState(() {
      final valueTrim = value.trim();
      if (valueTrim.isEmpty) {
        phoneError = 'El teléfono es obligatorio';
      } else if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(valueTrim)) {
        phoneError = 'Número de teléfono inválido (debe tener entre 7 y 15 dígitos)';
      } else {
        phoneError = null;
      }
    });
  }

  void _validateName(String value) {
    if (!registerMode) return;
    setState(() {
      final nameTrim = value.trim();
      if (nameTrim.isEmpty) {
        nameError = 'El nombre o razón social es obligatorio';
      } else if (nameTrim.length < 2) {
        nameError = 'Debe tener al menos 2 caracteres';
      } else if (!RegExp(r"^[a-zA-Z0-9áéíóúÁÉÍÓÚñÑüÜ\s'\-\.&]+$").hasMatch(nameTrim)) {
        nameError = 'Contiene caracteres no permitidos';
      } else {
        nameError = null;
      }
    });
  }

  void _validateEmailFormat(String value) {
    setState(() {
      final emailTrim = value.trim();
      if (emailTrim.isEmpty) {
        emailError = 'El correo electrónico es obligatorio';
      } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailTrim)) {
        emailError = 'Formato de correo inválido';
      } else {
        emailError = null;
      }
    });
  }

  void _validatePassword(String value) {
    setState(() {
      if (value.isEmpty) {
        passError = 'La contraseña es obligatoria';
      } else if (value.length < 8) {
        passError = 'Debe tener al menos 8 caracteres';
      } else if (!RegExp(r'[A-Z]').hasMatch(value)) {
        passError = 'Debe incluir al menos una mayúscula';
      } else if (!RegExp(r'[a-z]').hasMatch(value)) {
        passError = 'Debe incluir al menos una minúscula';
      } else if (!RegExp(r'[0-9]').hasMatch(value)) {
        passError = 'Debe incluir al menos un número';
      } else {
        passError = null;
      }

      // Re-validate confirm pass if it's already filled
      if (registerMode && confirmPass.text.isNotEmpty) {
        _validateConfirmPassword(confirmPass.text);
      }
    });
  }

  void _validateConfirmPassword(String value) {
    if (!registerMode) return;
    setState(() {
      if (value.isEmpty) {
        confirmPassError = 'La confirmación es obligatoria';
      } else if (value != pass.text) {
        confirmPassError = 'Las contraseñas no coinciden';
      } else {
        confirmPassError = null;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    emailFocus.addListener(_onEmailFocusChange);
    billingDocumentFocus.addListener(_onBillingDocumentFocusChange);
  }

  @override
  void dispose() {
    emailFocus.removeListener(_onEmailFocusChange);
    emailFocus.dispose();
    billingDocumentFocus.removeListener(_onBillingDocumentFocusChange);
    billingDocumentFocus.dispose();
    super.dispose();
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(text: email.text);
    final codeController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    int step = 1; // 1: Enter email, 2: Enter PIN and new password
    bool isDialogLoading = false;
    String? dialogError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                step == 1 ? 'Recuperar Contraseña' : 'Establecer Nueva Contraseña',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (dialogError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                        child: Text(dialogError!, style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (step == 1) ...[
                      const Text(
                        'Ingresa tu correo registrado y te enviaremos un PIN de 6 dígitos para restablecer tu contraseña.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: const Icon(LucideIcons.mail, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Hemos enviado un PIN al correo:\n${emailController.text}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: 'PIN de 6 dígitos',
                          counterText: '',
                          prefixIcon: const Icon(LucideIcons.shieldAlert, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: newPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Nueva Contraseña',
                          prefixIcon: const Icon(LucideIcons.lock, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Confirmar Nueva Contraseña',
                          prefixIcon: const Icon(LucideIcons.lock, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDialogLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isDialogLoading
                      ? null
                      : () async {
                          setDialogState(() {
                            isDialogLoading = true;
                            dialogError = null;
                          });

                          try {
                            if (step == 1) {
                              if (emailController.text.trim().isEmpty) {
                                throw 'Ingresa un correo válido.';
                              }
                              await ref.read(authControllerProvider.notifier).sendResetPin(emailController.text.trim());
                              setDialogState(() {
                                step = 2;
                              });
                            } else {
                              if (codeController.text.trim().length != 6) {
                                throw 'El PIN debe tener 6 dígitos.';
                              }
                              if (newPasswordController.text.isEmpty) {
                                throw 'Ingresa una nueva contraseña.';
                              }
                              if (newPasswordController.text != confirmPasswordController.text) {
                                throw 'Las contraseñas no coinciden.';
                              }
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .resetPassword(
                                    email: emailController.text.trim(),
                                    code: codeController.text.trim(),
                                    password: newPasswordController.text,
                                    passwordConfirmation: confirmPasswordController.text,
                                  );

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Contraseña restablecida de forma exitosa.'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            setDialogState(() {
                              dialogError = e.toString();
                            });
                          } finally {
                            setDialogState(() {
                              isDialogLoading = false;
                            });
                          }
                        },
                  child: isDialogLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(step == 1 ? 'Enviar PIN' : 'Restablecer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onEmailFocusChange() {
    if (!emailFocus.hasFocus && email.text.isNotEmpty && registerMode) {
      _validateEmail();
    }
  }

  Future<void> _validateEmail() async {
    if (!email.text.contains('@')) return;

    setState(() {
      isValidatingEmail = true;
      emailError = null;
    });

    final isAvailable = await ref.read(authControllerProvider.notifier).validateField('email', email.text.trim());

    if (mounted) {
      setState(() {
        isValidatingEmail = false;
        if (!isAvailable) {
          emailError = 'Este correo ya está en uso';
        }
      });
    }
  }

  void _onBillingDocumentFocusChange() {
    if (!billingDocumentFocus.hasFocus && billingDocument.text.isNotEmpty) {
      _validateNit();
    }
  }

  Future<void> _validateNit() async {
    if (billingDocument.text.length < 5) return;

    setState(() {
      isValidatingNit = true;
      nitError = null;
    });

    final isAvailable = await ref
        .read(authControllerProvider.notifier)
        .validateField('billing_document', billingDocument.text);

    if (mounted) {
      setState(() {
        isValidatingNit = false;
        if (!isAvailable) {
          nitError = 'Este NIT/CI ya está en uso';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final loading = authState.isLoading;
    final backendError = authState.hasError ? authState.error.toString() : null;
    final branding = ref.watch(brandingProvider).value;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              branding?.branding.primaryColor ?? const Color(0xFF03624C),
              branding?.branding.secondaryColor ?? const Color(0xFF0E4A7B),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(offset: Offset(0, 30 * (1 - value)), child: child),
                  );
                },
                child: Card(
                  elevation: 0,
                  shadowColor: Colors.black.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Hero(
                            tag: 'app_logo',
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(color: MaxVolt.forest, borderRadius: BorderRadius.circular(20)),
                              child: const MaxVoltLogo(width: 200),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          registerMode ? 'Crear una cuenta' : 'Bienvenido a ${branding?.platformName ?? 'MaxVolt'}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          registerMode ? 'Completa tus datos para empezar' : 'Ingresa tus credenciales para continuar',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 24),
                        if (widget.errorText != null || localError != null || backendError != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              localError ?? backendError ?? widget.errorText!,
                              style: TextStyle(color: Colors.red.shade800, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        if (registerMode) ...[
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: name,
                            label: 'Nombre completo',
                            icon: LucideIcons.user,
                            errorText: nameError,
                            onChanged: _validateName,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: phone,
                            label: 'Teléfono',
                            icon: LucideIcons.phone,
                            keyboardType: TextInputType.phone,
                            errorText: phoneError,
                            onChanged: _validatePhone,
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: email,
                          label: 'Correo electrónico',
                          icon: LucideIcons.mail,
                          keyboardType: TextInputType.emailAddress,
                          focusNode: emailFocus,
                          errorText: emailError,
                          suffix: isValidatingEmail
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : (emailError == null && email.text.contains('@')
                                    ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                                    : null),
                          onChanged: _validateEmailFormat,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: pass,
                          label: 'Contraseña',
                          icon: LucideIcons.lock,
                          obscureText: _obscurePass,
                          isPassword: true,
                          errorText: passError,
                          onToggleObscure: () => setState(() => _obscurePass = !_obscurePass),
                          onChanged: _validatePassword,
                        ),
                        if (!registerMode) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: const Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                        if (registerMode) ...[
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: confirmPass,
                            label: 'Confirmar contraseña',
                            icon: LucideIcons.shieldCheck,
                            obscureText: _obscureConfirmPass,
                            isPassword: true,
                            errorText: confirmPassError,
                            onToggleObscure: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                            onChanged: _validateConfirmPassword,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              SizedBox(
                                width: 92,
                                child: _buildDropdownField(
                                  value: billingDocType.text,
                                  label: 'Tipo',
                                  items: ['CI', 'NIT'],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => billingDocType.text = val);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: _buildTextField(
                                  controller: billingDocument,
                                  label: 'Número de Documento',
                                  icon: LucideIcons.creditCard,
                                  keyboardType: TextInputType.number,
                                  focusNode: billingDocumentFocus,
                                  errorText: nitError,
                                  onChanged: (val) {
                                    if (nitError != null) {
                                      setState(() => nitError = null);
                                    }
                                  },
                                  suffix: isValidatingNit
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : (nitError == null && billingDocument.text.length >= 5
                                            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                                            : null),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: billingRazonSocial,
                            label: 'Razón Social / Nombre Factura',
                            icon: LucideIcons.fileText,
                            helperText: 'Ponga su nombre',
                            errorText: billingRazonSocialError,
                            onChanged: _validateBillingRazonSocial,
                          ),
                        ],
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 56,
                          child: FilledButton(
                            onPressed: (loading || isValidatingEmail || isValidatingNit)
                                ? null
                                : () async {
                                    setState(() => localError = null);
                                    if (registerMode) {
                                      _validateName(name.text);
                                      _validatePhone(phone.text);
                                      _validateEmailFormat(email.text);
                                      _validatePassword(pass.text);
                                      _validateConfirmPassword(confirmPass.text);
                                      _validateBillingRazonSocial(billingRazonSocial.text);

                                      final docText = billingDocument.text.trim();
                                      if (docText.isEmpty) {
                                        setState(() => nitError = 'El número de documento (CI/NIT) es obligatorio');
                                      } else {
                                        final docRegExp = RegExp(r'^\d{5,15}$');
                                        if (!docRegExp.hasMatch(docText)) {
                                          setState(() => nitError = 'Debe tener entre 5 y 15 dígitos y solo números');
                                        } else {
                                          setState(() => nitError = null);
                                        }
                                      }

                                      if (nameError != null ||
                                          phoneError != null ||
                                          emailError != null ||
                                          passError != null ||
                                          confirmPassError != null ||
                                          nitError != null ||
                                          billingRazonSocialError != null) {
                                        setState(() => localError = 'Por favor, corrige los errores en el formulario');
                                        return;
                                      }

                                      await ref
                                          .read(authControllerProvider.notifier)
                                          .register(
                                            name: name.text.trim(),
                                            email: email.text.trim(),
                                            password: pass.text,
                                            phone: phone.text.trim(),
                                            billingDocument: billingDocument.text.trim(),
                                            billingDocType: billingDocType.text,
                                            billingRazonSocial: billingRazonSocial.text.trim(),
                                          );
                                      // Welcome dialog is now handled in HomePage using the is_new_user flag
                                    } else {
                                      _validateEmailFormat(email.text);
                                      _validatePassword(pass.text);
                                      if (emailError != null || passError != null) {
                                        setState(() => localError = 'Por favor, ingresa credenciales válidas');
                                        return;
                                      }
                                      await ref
                                          .read(authControllerProvider.notifier)
                                          .login(email: email.text.trim(), password: pass.text);
                                    }
                                  },
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 4,
                            ),
                            child: loading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(registerMode ? LucideIcons.userPlus : LucideIcons.logIn, size: 20),
                                      const SizedBox(width: 12),
                                      Text(
                                        registerMode ? 'Registrarse' : 'Iniciar Sesión',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        if (!isIOS) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 56,
                            child: OutlinedButton(
                              onPressed: loading
                                  ? null
                                  : () => ref.read(authControllerProvider.notifier).loginWithGoogle(),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(
                                    'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                                    height: 24,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.language, size: 24);
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Continuar con Google',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () => setState(() {
                            registerMode = !registerMode;
                            localError = null;
                            emailError = null;
                            nameError = null;
                            phoneError = null;
                            billingRazonSocialError = null;
                            passError = null;
                            confirmPassError = null;
                            nitError = null;
                            pass.clear();
                            confirmPass.clear();
                            phone.clear();
                            billingRazonSocial.clear();
                          }),
                          child: Text(
                            registerMode
                                ? '¿Ya tienes una cuenta? Inicia sesión'
                                : '¿No tienes cuenta? Regístrate aquí',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (branding?.legal.isDisclaimerVisible ?? false) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () async {
                              final url = Uri.parse(branding!.legal.disclaimerUrl);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Text(
                              'Aviso Legal y Disclaimers',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool isPassword = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    FocusNode? focusNode,
    String? errorText,
    String? helperText,
    Widget? suffix,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      focusNode: focusNode,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(obscureText ? LucideIcons.eyeOff : LucideIcons.eye, size: 20, color: Colors.grey.shade600),
                onPressed: onToggleObscure,
              )
            : (suffix != null ? Padding(padding: const EdgeInsets.all(12), child: suffix) : null),
        errorText: errorText,
        errorMaxLines: 2,
        errorStyle: const TextStyle(fontSize: 11, height: 1.0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF03624C), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildDropdownField({
    required String value,
    required String label,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      iconSize: 18,
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}
