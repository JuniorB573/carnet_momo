import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/subscription_service.dart';
import '../services/sync_service.dart';
import '../services/translations.dart';
import '../services/country_controller.dart';
import '../theme/app_theme.dart';
import '../theme/networks.dart';
import 'saisie_screen.dart';
import 'historique_screen.dart';
import 'synthese_screen.dart';
import 'archive_screen.dart';
import 'reglages_screen.dart';

/// Réseau mobile money actuellement sélectionné. Partagé entre les écrans
/// via un simple InheritedNotifier-like pattern (ValueNotifier) pour rester
/// simple sans introduire de gestion d'état plus lourde pour l'instant.
class NetworkController extends ValueNotifier<String> {
  NetworkController() : super('mtn');
}

class HomeShell extends StatefulWidget {
  final LanguageController languageController;
  final CountryController countryController;
  const HomeShell({super.key, required this.languageController, required this.countryController});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tabIndex = 0;
  final NetworkController networkController = NetworkController();
  final SubscriptionService subscriptionService = SubscriptionService();

  SubscriptionStatus? _status;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _restoreFromBackup();
    widget.languageController.addListener(_onLanguageChanged);
    widget.countryController.addListener(_onCountryChanged);
    // Aligne le réseau sélectionné sur le pays déjà enregistré au
    // lancement (ex: après une relance de l'app).
    networkController.value = networksForCountry(widget.countryController.value).first['id'] as String;
  }

  /// Si l'agent change de pays depuis les Réglages, on rebascule
  /// automatiquement sur le premier réseau du nouveau pays — l'ancien
  /// réseau sélectionné n'aurait sinon plus de sens (ex: passer du Bénin
  /// où 'mtn' existe à un pays qui ne le propose pas).
  void _onCountryChanged() {
    networkController.value = networksForCountry(widget.countryController.value).first['id'] as String;
  }

  /// Rapatrie les transactions et grilles de commission déjà sauvegardées
  /// sur Supabase — utile juste après une réinstallation, quand la base
  /// locale est vide. Se fait discrètement en arrière-plan, sans bloquer
  /// l'affichage de l'app.
  Future<void> _restoreFromBackup() async {
    await SyncService().pullAndMergeAll(DatabaseService.instance);
  }

  @override
  void dispose() {
    widget.languageController.removeListener(_onLanguageChanged);
    widget.countryController.removeListener(_onCountryChanged);
    super.dispose();
  }

  void _onLanguageChanged() => setState(() {});

  Future<void> _loadStatus() async {
    final status = await subscriptionService.getStatus();
    if (!mounted) return;
    setState(() {
      _status = status;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final lang = widget.languageController.value;
    final isExpired = _status!.state == SubscriptionState.expire;
    final tabs = [
      SaisieScreen(
        networkController: networkController,
        languageController: widget.languageController,
        countryController: widget.countryController,
      ),
      HistoriqueScreen(languageController: widget.languageController, countryController: widget.countryController),
      SyntheseScreen(languageController: widget.languageController, countryController: widget.countryController),
      ArchiveScreen(languageController: widget.languageController, countryController: widget.countryController),
      ReglagesScreen(
        languageController: widget.languageController,
        countryController: widget.countryController,
        status: _status!,
        onStatusChanged: _loadStatus,
      ),
    ];

    // L'onglet Réglages (index 4) reste toujours accessible, même quand
    // l'abonnement est expiré — c'est là que vit maintenant la gestion de
    // l'abonnement (voir ReglagesScreen._abonnementCard).
    final currentTab = (isExpired && _tabIndex != 4)
        ? _ExpiredGate(onSeeAbonnement: () => setState(() => _tabIndex = 4), lang: lang)
        : tabs[_tabIndex];

    return Scaffold(
      body: SafeArea(child: currentTab),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.green.withValues(alpha: 0.12),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.menu_book_outlined), label: t('saisie', lang)),
          NavigationDestination(icon: const Icon(Icons.history), label: t('historique', lang)),
          NavigationDestination(icon: const Icon(Icons.pie_chart_outline), label: t('synthese', lang)),
          NavigationDestination(icon: const Icon(Icons.folder_outlined), label: t('archive', lang)),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: isExpired || (_status!.state == SubscriptionState.essai && _status!.daysLeft <= 1),
              child: const Icon(Icons.settings_outlined),
            ),
            label: t('reglages', lang),
          ),
        ],
      ),
    );
  }
}

class _ExpiredGate extends StatelessWidget {
  final VoidCallback onSeeAbonnement;
  final String lang;
  const _ExpiredGate({required this.onSeeAbonnement, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔒', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 10),
                Text(
                  t('essai_termine_titre', lang),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  "${t('essai_termine_desc_1', lang)}${SubscriptionService.trialDays}${t('essai_termine_desc_2', lang)}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: onSeeAbonnement,
                  child: Text("${t('voir_abonnement', lang)}${SubscriptionService.monthlyFeeFcfa} F CFA / mois"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
