import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme/app_theme.dart';
import 'screens/role_gate.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/update_banner.dart';
import 'services/auth_service.dart';
import 'services/local_notification_service.dart';
import 'services/country_controller.dart';
import 'services/supabase_config.dart';
import 'services/translations.dart';
import 'services/version_check_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  await LocalNotificationService.init();
  // Nécessaire pour afficher les noms de mois en français (ex: "Août 2026")
  // dans l'historique et l'export — sans ça, l'app plante dès qu'elle
  // essaie de formater une date en français.
  await initializeDateFormatting('fr_FR', null);
  runApp(const CarnetMomoApp());
}

enum _AppStage { auth, onboarding, locked, home }

class CarnetMomoApp extends StatefulWidget {
  const CarnetMomoApp({super.key});

  @override
  State<CarnetMomoApp> createState() => _CarnetMomoAppState();
}

class _CarnetMomoAppState extends State<CarnetMomoApp> {
  final _auth = AuthService();
  // Créé ici, au niveau racine, pour que le choix de langue fait dès
  // l'inscription reste le même partout ensuite dans l'app.
  final _languageController = LanguageController();
  // Même principe que la langue : le pays choisi à l'inscription
  // détermine l'indicatif proposé et les réseaux Mobile Money affichés
  // partout ensuite dans l'app.
  final _countryController = CountryController();
  final _versionCheck = VersionCheckService();
  _AppStage _stage = _AppStage.auth;
  UpdateInfo? _updateInfo;
  bool _updateDismissed = false;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _decideInitialStage();
    _checkForUpdate();
    
    // Détecte si le compte a été supprimé côté serveur (le jeton devient invalide).
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        if (mounted && _stage != _AppStage.auth) {
          _auth.signOut(); // S'assure que le cache local est bien vidé
          setState(() => _stage = _AppStage.auth);
        }
      }
    });
  }

  /// Vérifié une seule fois au lancement, sans bloquer l'affichage de
  /// l'app : l'agent voit son écran normalement, et le bandeau de mise à
  /// jour apparaît en haut dès que la réponse arrive (silencieusement
  /// ignoré en cas d'échec réseau — voir VersionCheckService).
  Future<void> _checkForUpdate() async {
    final info = await _versionCheck.checkForUpdate();
    if (!mounted || info == null) return;
    setState(() => _updateInfo = info);
  }

  /// Un agent déjà connecté (relance de l'app) doit d'abord retaper son
  /// code PIN avant d'accéder à ses données — protection en cas de perte
  /// ou de vol du téléphone. Cette vérification se fait entièrement en
  /// local, sans besoin de connexion.
  Future<void> _decideInitialStage() async {
    if (!_auth.isLoggedIn) {
      setState(() => _stage = _AppStage.auth);
      return;
    }
    final hasPin = await _auth.hasLocalPin();
    setState(() => _stage = hasPin ? _AppStage.locked : _AppStage.home);
  }

  @override
  Widget build(BuildContext context) {
    Widget screen;
    switch (_stage) {
      case _AppStage.auth:
        screen = AuthScreen(
          languageController: _languageController,
          countryController: _countryController,
          onAuthenticated: (isNewAccount) => setState(() {
            _stage = isNewAccount ? _AppStage.onboarding : _AppStage.home;
          }),
        );
        break;
      case _AppStage.onboarding:
        screen = OnboardingScreen(
          languageController: _languageController,
          countryController: _countryController,
          onDone: () => setState(() => _stage = _AppStage.home),
        );
        break;
      case _AppStage.locked:
        screen = LockScreen(
          languageController: _languageController,
          onUnlocked: () => setState(() => _stage = _AppStage.home),
          onSignOut: () async {
            await _auth.signOut();
            setState(() => _stage = _AppStage.auth);
          },
        );
        break;
      case _AppStage.home:
        screen = RoleGate(
          languageController: _languageController,
          countryController: _countryController,
          onSignOut: () async {
            await _auth.signOut();
            setState(() => _stage = _AppStage.auth);
          },
        );
        break;
    }

    return MaterialApp(
      title: 'Carnet MoMo',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Column(
        children: [
          if (_updateInfo != null && !_updateDismissed)
            UpdateBanner(
              info: _updateInfo!,
              languageController: _languageController,
              onDismiss: () => setState(() => _updateDismissed = true),
            ),
          Expanded(child: screen),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
