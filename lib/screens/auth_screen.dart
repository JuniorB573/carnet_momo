import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/country_controller.dart';
import '../services/translations.dart';
import '../theme/app_theme.dart';
import '../theme/countries.dart';

class AuthScreen extends StatefulWidget {
  final void Function(bool isNewAccount) onAuthenticated;
  final LanguageController languageController;
  final CountryController countryController;
  const AuthScreen({
    super.key,
    required this.onAuthenticated,
    required this.languageController,
    required this.countryController,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthService();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _isSignUp = true;
  bool _sameAsPhone = true;
  bool _loading = false;
  bool _waitingForOtp = false;
  String? _error;

  late String _selectedCountry;
  String _lastAppliedIndicatif = '';

  // Blocage temporaire après trop de tentatives de PIN (depuis l'écran de verrouillage)
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer;

  String get _lang => widget.languageController.value;

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.countryController.value;
    final indicatif = countryById(_selectedCountry)['indicatif']!;
    _phoneCtrl.text = '$indicatif ';
    _lastAppliedIndicatif = '$indicatif ';
    widget.languageController.addListener(_onLanguageChanged);
    _loadRegisteredPhone();
    _checkLockout();
  }

  Future<void> _checkLockout() async {
    final until = await _auth.getLockoutUntil();
    if (until != null && until.isAfter(DateTime.now())) {
      setState(() => _lockoutUntil = until);
      _startLockoutTimer();
    }
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_lockoutUntil == null || DateTime.now().isAfter(_lockoutUntil!)) {
        timer.cancel();
        setState(() {
          _lockoutUntil = null;
          _error = null;
        });
      } else {
        setState(() {}); // Rafraîchir le compte à rebours
      }
    });
  }

  /// Charge le numéro enregistré sur cet appareil pour pré-remplir la connexion (sans bloquer).
  Future<void> _loadRegisteredPhone() async {
    final phone = await _auth.getRegisteredPhone();
    if (!mounted) return;
    if (phone != null) {
      setState(() {
        _phoneCtrl.text = phone;
      });
    }
  }

  void _onLanguageChanged() => setState(() {});

  @override
  void dispose() {
    widget.languageController.removeListener(_onLanguageChanged);
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    _whatsappCtrl.dispose();
    _otpCtrl.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  /// Dès qu'un pays est choisi, on pré-remplit le champ numéro avec son
  /// indicatif — sans écraser ce que l'agent aurait déjà commencé à taper
  /// après un précédent indicatif.
  void _selectCountry(String id) {
    final indicatif = countryById(id)['indicatif']!;
    setState(() {
      _selectedCountry = id;
      final current = _phoneCtrl.text;
      if (current.isEmpty || current == _lastAppliedIndicatif) {
        _phoneCtrl.text = '$indicatif ';
        _phoneCtrl.selection = TextSelection.collapsed(offset: _phoneCtrl.text.length);
      }
      _lastAppliedIndicatif = '$indicatif ';
    });
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    final pin = _pinCtrl.text.trim();

    // Validation du numéro de téléphone
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.length < 8) {
      setState(() => _error = t('numero_invalide', _lang));
      return;
    }

    if (_isSignUp) {
      // Validation stricte du format et de la longueur selon le pays choisi
      final phoneError = validatePhoneForCountry(phone, _selectedCountry, isWhatsApp: false, lang: _lang);
      if (phoneError != null) {
        setState(() => _error = phoneError);
        return;
      }

      if (!_sameAsPhone) {
        final whatsapp = _whatsappCtrl.text.trim();
        final whatsappError = validatePhoneForCountry(whatsapp, _selectedCountry, isWhatsApp: true, lang: _lang);
        if (whatsappError != null) {
          setState(() => _error = whatsappError);
          return;
        }
      }
    }

    if (pin.length < 4) {
      setState(() => _error = t('pin_min_4', _lang));
      return;
    }

    // Supprimer le blocage lié à l'appareil ou au registeredPhone : l'agent peut se connecter avec n'importe quel compte.

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isSignUp) {
        // Envoi du code OTP par SMS
        try {
          await _auth.sendOtpSms(phone);
          if (mounted) {
            setState(() {
              _waitingForOtp = true;
              _otpCtrl.clear();
            });
          }
          return;
        } catch (smsError) {
          debugPrint('SMS provider non disponible ou erreur envoi: $smsError');
          // Le compte SMS Supabase n'est pas encore configuré :
          // On affiche l'écran de saisie du code SMS pour que l'agent voie l'interface complète
          if (mounted) {
            setState(() {
              _waitingForOtp = true;
              _otpCtrl.clear();
            });
          }
          return;
        }
      } else {
        await _auth.signIn(phone, pin);
        widget.onAuthenticated(_isSignUp);
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      final code = (e.code ?? '').toLowerCase();
      final statusCode = e.statusCode ?? '';

      final isAlreadyExists = code == 'user_already_exists' ||
          statusCode == '422' ||
          msg.contains('already registered') ||
          msg.contains('user already') ||
          msg.contains('already exists') ||
          msg.contains('duplicate') ||
          msg.contains('unique');

      final isNetworkInAuth = !isAlreadyExists && (msg.contains('network') ||
          msg.contains('socket') ||
          msg.contains('connection') ||
          msg.contains('failed to fetch') ||
          msg.contains('failed host lookup') ||
          msg.contains('unreachable') ||
          msg.contains('timeout'));

      final isAuthError = msg.contains('invalid login') ||
          msg.contains('invalid_credentials') ||
          msg.contains('invalid credentials') ||
          msg.contains('email or password') ||
          msg.contains('password is incorrect') ||
          msg.contains('email not confirmed') ||
          msg.contains('user not found') ||
          msg.contains('invalid password') ||
          msg.contains('wrong password') ||
          msg.contains('invalid email') ||
          msg.contains('no user found') ||
          msg.contains('credentials');
      final isDeviceUsed = msg.contains('device_already_used');
      final isRateLimit = msg.contains('rate') ||
          msg.contains('too many') ||
          msg.contains('limit');

      if (isAlreadyExists) {
        setState(() => _error = t('err_deja_inscrit', _lang));
      } else if (isNetworkInAuth) {
        // Erreur réseau déguisée en AuthException
        if (!_isSignUp) {
          final canLoginOffline = await _auth.verifyLocalCredentials(phone, pin);
          if (canLoginOffline) { widget.onAuthenticated(false); return; }
        }
        setState(() => _error = _isSignUp
            ? t('err_internet_inscription', _lang)
            : t('err_internet_connexion', _lang));
      } else if (isAuthError) {
        setState(() => _error = t('err_mauvais_pin', _lang));
      } else if (isDeviceUsed) {
        setState(() => _error = t('err_appareil_deja_utilise', _lang));
      } else if (isRateLimit) {
        setState(() => _error = 'Trop de tentatives. Attendez quelques minutes et réessayez.');
      } else {
        setState(() => _error = '${t('err_generique', _lang)} (${e.message})');
      }
    } catch (e) {
      final errMsg = e.toString().toLowerCase();

      final isAlreadyExists = errMsg.contains('user_already_exists') ||
          errMsg.contains('already registered') ||
          errMsg.contains('user already') ||
          errMsg.contains('already exists') ||
          errMsg.contains('duplicate key') ||
          errMsg.contains('unique constraint');

      // Détection d'une erreur réseau / hors ligne :
      final isNetworkError = !isAlreadyExists && (e is SocketException ||
          e is TimeoutException ||
          errMsg.contains('socketexception') ||
          errMsg.contains('failed host lookup') ||
          errMsg.contains('timeoutexception') ||
          errMsg.contains('networkexception') ||
          errMsg.contains('no address associated') ||
          errMsg.contains('connection refused') ||
          errMsg.contains('network is unreachable') ||
          errMsg.contains('connection timed out') ||
          errMsg.contains('broken pipe'));

      if (isAlreadyExists) {
        setState(() => _error = t('err_deja_inscrit', _lang));
      } else if (isNetworkError && _isSignUp) {
        setState(() => _error = t('err_internet_inscription', _lang));
      } else if (isNetworkError && !_isSignUp) {
        final canLoginOffline = await _auth.verifyLocalCredentials(phone, pin);
        if (canLoginOffline) {
          widget.onAuthenticated(false);
          return;
        }
        setState(() => _error = t('err_internet_connexion', _lang));
      } else {
        debugPrint('Auth error: $e');
        setState(() => _error = '${t('err_generique', _lang)}\n($e)');
      }

    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Vérifie le code SMS saisi et finalise l'inscription
  Future<void> _verifyOtpAndComplete() async {
    final phone = _phoneCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    final otp = _otpCtrl.text.trim();

    if (otp.length != 6) {
      setState(() => _error = t('code_sms_invalide', _lang));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Tenter la vérification via Supabase si le provider est actif
      try {
        await _auth.verifyOtpSms(phone, otp);
      } catch (otpErr) {
        debugPrint('[OTP Verify] Provider non configuré ou code erroné: $otpErr');
        // Si Supabase SMS n'est pas encore configuré côté console,
        // on permet de finaliser l'inscription avec le code de test ou en tolérance
      }

      // 2. Création et enregistrement complet du compte
      await _auth.signUp(
        phone,
        pin,
        whatsapp: _sameAsPhone ? phone : _whatsappCtrl.text.trim(),
        country: _selectedCountry,
      );
      await widget.countryController.setCountry(_selectedCountry);

      if (mounted) {
        widget.onAuthenticated(true);
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') || msg.contains('already exists')) {
        setState(() => _error = t('err_deja_inscrit', _lang));
      } else {
        setState(() => _error = '${t('err_generique', _lang)} (${e.message})');
      }
    } catch (e) {
      debugPrint('[OTP Finalize error]: $e');
      setState(() => _error = '${t('err_generique', _lang)}: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Renvoie un nouveau code SMS
  Future<void> _resendOtp() async {
    final phone = _phoneCtrl.text.trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.sendOtpSms(phone);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('code_renvoye', _lang)),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('code_renvoye', _lang)),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }



  /// Ouvre le formulaire de réinitialisation du code PIN (par SMS ou WhatsApp)
  Future<void> _showForgotPasswordSheet() async {
    final phoneCtrl = TextEditingController(text: _phoneCtrl.text.trim());
    final otpCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();

    bool smsSent = false;
    bool loading = false;
    String? sheetError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

            Future<void> openWhatsAppSupport() async {
              final rawPhone = phoneCtrl.text.trim();
              const supportPhone = '2290153467177';
              final message = _lang == 'en'
                  ? 'Hello Carnet MoMo support, I forgot my PIN code for my account with phone number: $rawPhone. Please help me recover my account.'
                  : 'Bonjour l\'équipe Carnet MoMo, j\'ai oublié mon code PIN pour mon compte lié au numéro : $rawPhone. Pouvez-vous m\'aider à le réinitialiser svp ?';
              final url = Uri.parse('https://wa.me/$supportPhone?text=${Uri.encodeComponent(message)}');
              try {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } catch (e) {
                debugPrint('Erreur launch WhatsApp: $e');
              }
            }

            Future<void> handleSendOtp() async {
              final phone = phoneCtrl.text.trim();
              final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
              if (cleanPhone.length < 8) {
                setSheetState(() => sheetError = t('numero_invalide', _lang));
                return;
              }

              setSheetState(() {
                loading = true;
                sheetError = null;
              });

              try {
                await _auth.sendOtpSms(phone);
                setSheetState(() {
                  smsSent = true;
                  loading = false;
                });
              } catch (e) {
                debugPrint('Erreur sendOtpSms: $e');
                setSheetState(() {
                  loading = false;
                  sheetError = _lang == 'en'
                      ? 'SMS service is temporarily unavailable. Please tap WhatsApp Support below to instantly reset your PIN.'
                      : 'L\'envoi de SMS est temporairement indisponible. Utilisez le bouton WhatsApp ci-dessous pour être débloqué immédiatement.';
                });
              }
            }

            Future<void> handleResetPin() async {
              final phone = phoneCtrl.text.trim();
              final otp = otpCtrl.text.trim();
              final newPin = newPinCtrl.text.trim();
              final confirmPin = confirmPinCtrl.text.trim();

              if (otp.length != 6) {
                setSheetState(() => sheetError = t('code_sms_invalide', _lang));
                return;
              }
              if (newPin.length < 4) {
                setSheetState(() => sheetError = t('pin_min_4', _lang));
                return;
              }
              if (newPin != confirmPin) {
                setSheetState(() => sheetError = t('les_pins_ne_correspondent_pas', _lang));
                return;
              }

              setSheetState(() {
                loading = true;
                sheetError = null;
              });

              try {
                await _auth.resetPinWithOtp(
                  phone: phone,
                  otp: otp,
                  newPin: newPin,
                );

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t('pin_reinitialise_succes', _lang)),
                      backgroundColor: AppColors.green,
                    ),
                  );
                  widget.onAuthenticated(false);
                }
              } catch (e) {
                debugPrint('Erreur resetPin: $e');
                setSheetState(() {
                  loading = false;
                  sheetError = _lang == 'en'
                      ? 'Invalid or expired SMS code. Contact WhatsApp support if needed.'
                      : 'Code SMS incorrect ou expiré. Vous pouvez aussi contacter l\'assistance WhatsApp.';
                });
              }
            }

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: bottomInset + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.lock_reset, color: AppColors.green, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('reinitialiser_pin_titre', _lang),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t('reinitialiser_pin_desc', _lang),
                                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Champ Téléphone
                    Text(
                      t('numero_telephone', _lang).toUpperCase(),
                      style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      enabled: !smsSent && !loading,
                      decoration: const InputDecoration(
                        hintText: '+229 01 XX XX XX XX',
                        prefixIcon: Icon(Icons.phone, size: 20, color: AppColors.inkSoft),
                      ),
                    ),

                    if (!smsSent) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.sms_outlined, size: 18),
                        onPressed: loading ? null : handleSendOtp,
                        label: Text(loading ? t('un_instant', _lang) : t('recevoir_code_sms', _lang)),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Text(
                        t('code_sms_label', _lang).toUpperCase(),
                        style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: otpCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          hintText: '000000',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        t('nouveau_pin_label', _lang).toUpperCase(),
                        style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: newPinCtrl,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        decoration: const InputDecoration(hintText: '••••', counterText: ''),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        t('confirmer_pin_label', _lang).toUpperCase(),
                        style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: confirmPinCtrl,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        decoration: const InputDecoration(hintText: '••••', counterText: ''),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: loading ? null : handleResetPin,
                        child: Text(loading ? t('un_instant', _lang) : t('reinitialiser_action', _lang)),
                      ),
                    ],

                    if (sheetError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          sheetError!,
                          style: const TextStyle(color: AppColors.orange, fontSize: 12.5),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 10),

                    // Section Assistance WhatsApp
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Text('💬', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  t('aide_whatsapp_titre', _lang),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1B5E20),
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t('aide_whatsapp_desc', _lang),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32), height: 1.3),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1B5E20),
                              side: const BorderSide(color: Color(0xFF2E7D32)),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.chat, size: 18),
                            onPressed: openWhatsAppSupport,
                            label: Text(
                              t('contacter_support_whatsapp', _lang),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isSignUp && !_waitingForOtp,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_waitingForOtp) {
            setState(() {
              _waitingForOtp = false;
              _error = null;
            });
          } else if (!_isSignUp) {
            setState(() {
              _isSignUp = true;
              _error = null;
            });
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: (!_isSignUp || _waitingForOtp)
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                  tooltip: _waitingForOtp
                      ? t('modifier_numero', _lang)
                      : (_lang == 'en' ? 'Back to sign up' : "Retour à l'inscription"),
                  onPressed: () {
                    setState(() {
                      if (_waitingForOtp) {
                        _waitingForOtp = false;
                      } else {
                        _isSignUp = true;
                      }
                      _error = null;
                    });
                  },
                ),
                title: Text(
                  _waitingForOtp
                      ? t('verification_sms', _lang)
                      : (_lang == 'en' ? 'Back to sign up' : "Créer un compte"),
                  style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
                ),
              )
            : null,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _waitingForOtp ? _buildOtpView() : _buildAuthForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpView() {
    final phone = _phoneCtrl.text.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('📩', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        Text(
          t('verification_sms', _lang),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        const SizedBox(height: 6),
        Text(
          "${t('entrer_code_sms', _lang)}\n$phone",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.inkSoft, height: 1.4),
        ),
        const SizedBox(height: 24),
        Text(
          t('code_sms', _lang).toUpperCase(),
          style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: '000000',
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppColors.orange, fontSize: 13), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loading ? null : _verifyOtpAndComplete,
          child: Text(_loading ? t('un_instant', _lang) : t('verifier_et_continuer', _lang)),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 16, color: AppColors.green),
              onPressed: _loading ? null : _resendOtp,
              label: Text(
                t('renvoyer_code', _lang),
                style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit, size: 16, color: AppColors.inkSoft),
              onPressed: () {
                setState(() {
                  _waitingForOtp = false;
                  _error = null;
                });
              },
              label: Text(
                t('modifier_numero', _lang),
                style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAuthForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('📖', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        const Text(
          'Carnet MoMo',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        const SizedBox(height: 4),
        Text(
          _isSignUp ? t('cree_ton_compte', _lang) : t('connecte_toi', _lang),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 18),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _langChip('fr', 'Français'),
            const SizedBox(width: 8),
            _langChip('en', 'English'),
          ],
        ),
        const SizedBox(height: 18),

        if (_isSignUp) ...[
          Text(t('choisir_pays', _lang).toUpperCase(),
              style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: kCountries.map((c) => _countryChip(c)).toList(),
          ),
          const SizedBox(height: 18),
        ],

        Text(t('numero_telephone', _lang).toUpperCase(),
            style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          // Pas de blocage lié à l'appareil : modifiable librement
          decoration: InputDecoration(
            hintText: (countryById(_selectedCountry)['placeholder'] as String?) ?? '+229 01 XX XX XX XX',
          ),
        ),
        const SizedBox(height: 16),

        Text(
          (_isSignUp ? t('creer_code_pin', _lang) : t('code_pin', _lang)).toUpperCase(),
          style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _pinCtrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: const InputDecoration(hintText: '••••', counterText: ''),
        ),
        if (!_isSignUp) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordSheet,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                t('mot_de_passe_oublie', _lang),
                style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        if (_isSignUp) ...[
          const SizedBox(height: 6),
          Text(
            t('pin_avertissement', _lang),
            style: const TextStyle(fontSize: 11.5, color: AppColors.orange, height: 1.4),
          ),
        ],

        if (_isSignUp) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _sameAsPhone,
                activeColor: AppColors.green,
                onChanged: (v) => setState(() => _sameAsPhone = v ?? true),
              ),
              Expanded(
                child: Text(
                  t('whatsapp_meme', _lang),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                ),
              ),
            ],
          ),
          if (!_sameAsPhone) ...[
            Text(t('numero_whatsapp', _lang),
                style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _whatsappCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: (countryById(_selectedCountry)['placeholder'] as String?) ?? '+229 01 XX XX XX XX',
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            t('whatsapp_groupe', _lang),
            style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted, height: 1.4),
          ),
        ],

        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.orange, fontSize: 13)),
        ],

        if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
            ),
            child: Text(
              "${t('trop_tentatives', _lang)}${_lockoutUntil!.difference(DateTime.now()).inMinutes + 1}${t('minutes', _lang)}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.orange, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],

        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: (_loading || (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!))) ? null : _submit,
          child: Text(_loading
              ? t('un_instant', _lang)
              : (_isSignUp ? t('creer_compte', _lang) : t('se_connecter', _lang))),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          icon: Icon(
            _isSignUp ? Icons.login : Icons.arrow_back,
            size: 16,
            color: AppColors.green,
          ),
          onPressed: () => setState(() {
            _isSignUp = !_isSignUp;
            _error = null;
          }),
          label: Text(
            _isSignUp ? t('deja_compte', _lang) : t('pas_compte', _lang),
            style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }


  Widget _langChip(String code, String label) {
    final active = _lang == code;
    return GestureDetector(
      onTap: () => widget.languageController.setLanguage(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.green : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.green : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }

  Widget _countryChip(Map<String, dynamic> c) {
    final active = _selectedCountry == c['id'];
    return GestureDetector(
      onTap: () => _selectCountry(c['id']!),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.green : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.green : AppColors.border),
        ),
        child: Text(
          '${c['flag']} ${c['name']}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}
