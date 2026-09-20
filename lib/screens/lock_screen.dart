import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/translations.dart';
import '../theme/app_theme.dart';

/// Affiché à chaque relance de l'app tant qu'un compte est déjà connecté —
/// redemande le code PIN pour protéger l'accès si le téléphone tombe dans
/// d'autres mains. Fonctionne entièrement hors ligne (vérification locale).
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final VoidCallback onSignOut;
  final LanguageController languageController;
  const LockScreen({
    super.key,
    required this.onUnlocked,
    required this.onSignOut,
    required this.languageController,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _auth = AuthService();
  final _pinCtrl = TextEditingController();
  String? _error;
  bool _checking = false;

  String get _lang => widget.languageController.value;

  @override
  void initState() {
    super.initState();
    widget.languageController.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() => setState(() {});

  @override
  void dispose() {
    widget.languageController.removeListener(_onLanguageChanged);
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinCtrl.text.trim();
    if (pin.length < 4) return;

    setState(() {
      _checking = true;
      _error = null;
    });

    final ok = await _auth.verifyLocalPin(pin);

    if (!mounted) return;
    if (ok) {
      await _auth.resetFailedAttempts();
      widget.onUnlocked();
    } else {
      final attempts = await _auth.registerFailedAttempt();
      if (!mounted) return;
      if (attempts >= AuthService.maxFailedAttempts) {
        // Stocker un blocage de 30 minutes, déconnecter et renvoyer à la page de connexion
        await _auth.resetFailedAttempts();
        final until = DateTime.now().add(const Duration(minutes: 30));
        await _auth.setLockoutUntil(until);
        await _auth.signOut();
        if (!mounted) return;
        widget.onSignOut();
        return;
      }
      final remaining = AuthService.maxFailedAttempts - attempts;
      setState(() {
        _error = "${t('tentatives_restantes_1', _lang)}$remaining${t('tentatives_restantes_2', _lang)}";
        _checking = false;
        _pinCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔒', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 10),
                Text(
                  t('verrouille_titre', _lang),
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  t('entre_pin', _lang),
                  style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 26),
                TextField(
                  controller: _pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(fontSize: 22, letterSpacing: 8),
                  decoration: const InputDecoration(hintText: '••••', counterText: ''),
                  onChanged: (v) {
                    if (v.length == 4) _submit();
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(_error!, style: const TextStyle(color: AppColors.orange, fontSize: 13)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _checking ? null : _submit,
                    child: Text(_checking ? t('verification', _lang) : t('deverrouiller', _lang)),
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: widget.onSignOut,
                  child: Text(
                    t('pas_mon_numero', _lang),
                    style: const TextStyle(color: AppColors.inkMuted, fontSize: 12.5),
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
