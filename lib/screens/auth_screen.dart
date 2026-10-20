import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  bool _isSignUp = true;
  bool _sameAsPhone = true;
  bool _loading = false;
  String? _error;
  // Numéro déjà enregistré sur cet appareil (null = premier lancement)
  String? _registeredPhone;

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

  /// Charge le numéro enregistré sur cet appareil.
  /// S'il existe, on passe directement en mode connexion et on pré-remplit.
  Future<void> _loadRegisteredPhone() async {
    final phone = await _auth.getRegisteredPhone();
    if (!mounted) return;
    if (phone != null) {
      setState(() {
        _registeredPhone = phone;
        _isSignUp = false;
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

    // Bloquer la connexion ou l'inscription avec un numéro différent de celui enregistré.
    if (_registeredPhone != null) {
      final auth = AuthService();
      final normalized = auth.normalizePhonePublic(phone);
      final registeredNorm = auth.normalizePhonePublic(_registeredPhone!);
      if (normalized != registeredNorm) {
        setState(() => _error = t('err_numero_different', _lang));
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isSignUp) {
        await _auth.signUp(
          phone,
          pin,
          whatsapp: _sameAsPhone ? phone : _whatsappCtrl.text.trim(),
          country: _selectedCountry,
        );
        await widget.countryController.setCountry(_selectedCountry);
      } else {
        await _auth.signIn(phone, pin);
      }
      widget.onAuthenticated(_isSignUp);
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
        // Afficher le message brut pour aider à identifier les nouvelles erreurs
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
        // Inscription sans internet
        setState(() => _error = t('err_internet_inscription', _lang));
      } else if (isNetworkError && !_isSignUp) {
        // Connexion sans internet → vérifier identifiants locaux
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


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isSignUp,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_isSignUp) {
          setState(() {
            _isSignUp = true;
            _error = null;
          });
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: !_isSignUp
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                  tooltip: _lang == 'en' ? 'Back to sign up' : "Retour à l'inscription",
                  onPressed: () {
                    setState(() {
                      _isSignUp = true;
                      _error = null;
                    });
                  },
                ),
                title: Text(
                  _lang == 'en' ? 'Back to sign up' : "Créer un compte",
                  style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
                ),
              )
            : null,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
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
                  // Verrouillé en mode connexion si un numéro est déjà enregistré
                  readOnly: !_isSignUp && _registeredPhone != null,
                  decoration: InputDecoration(
                    hintText: (countryById(_selectedCountry)['placeholder'] as String?) ?? '+229 01 XX XX XX XX',
                    suffixIcon: (!_isSignUp && _registeredPhone != null)
                        ? const Tooltip(
                            message: 'Numéro lié à cet appareil',
                            child: Icon(Icons.lock_outline, size: 18, color: AppColors.inkMuted),
                          )
                        : null,
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
            ),
          ),
        ),
      ),
    ));
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
