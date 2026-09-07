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

  late String _selectedCountry;
  String _lastAppliedIndicatif = '';

  String get _lang => widget.languageController.value;

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.countryController.value;
    widget.languageController.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() => setState(() {});

  @override
  void dispose() {
    widget.languageController.removeListener(_onLanguageChanged);
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    _whatsappCtrl.dispose();
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

    if (phone.length < 8) {
      setState(() => _error = t('numero_invalide', _lang));
      return;
    }
    if (pin.length < 4) {
      setState(() => _error = t('pin_min_4', _lang));
      return;
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
      // Erreur Supabase explicite (auth) — jamais une erreur réseau.
      final msg = e.message.toLowerCase();
      final isAlreadyExists = msg.contains('already registered') ||
          msg.contains('user already') ||
          msg.contains('already exists');
      final isAuthError = msg.contains('invalid login') ||
          msg.contains('invalid_credentials') ||
          msg.contains('email not confirmed') ||
          msg.contains('user not found') ||
          msg.contains('invalid password');

      if (isAlreadyExists) {
        setState(() => _error = t('err_deja_inscrit', _lang));
      } else if (isAuthError) {
        setState(() => _error = t('err_mauvais_pin', _lang));
      } else {
        setState(() => _error = t('err_generique', _lang));
      }
    } catch (e) {
      final errMsg = e.toString().toLowerCase();

      // Détection d'une erreur réseau / hors ligne :
      // On vérifie d'abord le type exact de l'exception (plus fiable),
      // puis on complète avec des mots-clés dans le message d'erreur.
      // Note : 'clientexception' est volontairement exclu car Supabase
      // l'utilise aussi pour des erreurs non-réseau (ex: validation).
      final isNetworkError = e is SocketException ||
          e is TimeoutException ||
          errMsg.contains('socketexception') ||
          errMsg.contains('failed host lookup') ||
          errMsg.contains('timeoutexception') ||
          errMsg.contains('networkexception') ||
          errMsg.contains('no address associated') ||
          errMsg.contains('connection refused') ||
          errMsg.contains('network is unreachable') ||
          errMsg.contains('connection timed out') ||
          errMsg.contains('broken pipe');

      if (isNetworkError && _isSignUp) {
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
        setState(() => _error = t('err_generique', _lang));
      }

    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                  decoration: const InputDecoration(hintText: '+229 01 XX XX XX XX'),
                ),
                const SizedBox(height: 16),

                Text(t('code_pin', _lang).toUpperCase(),
                    style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  decoration: const InputDecoration(hintText: '••••', counterText: ''),
                ),

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
                      decoration: const InputDecoration(hintText: '+229 01 XX XX XX XX'),
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

                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: Text(_loading
                      ? t('un_instant', _lang)
                      : (_isSignUp ? t('creer_compte', _lang) : t('se_connecter', _lang))),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() {
                    _isSignUp = !_isSignUp;
                    _error = null;
                  }),
                  child: Text(
                    _isSignUp ? t('deja_compte', _lang) : t('pas_compte', _lang),
                    style: const TextStyle(color: AppColors.green),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

  Widget _countryChip(Map<String, String> c) {
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
