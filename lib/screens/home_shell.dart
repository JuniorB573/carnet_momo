import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../services/local_notification_service.dart';
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
import 'abonnement_screen.dart';

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

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tabIndex = 0;
  final NetworkController networkController = NetworkController();
  final SubscriptionService subscriptionService = SubscriptionService();

  SubscriptionStatus? _status;
  bool _loading = true;
  RealtimeChannel? _realtimeChannel;
  Timer? _periodicTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
    _restoreFromBackup();
    _setupRealtimeSubscription();
    LocalNotificationService.requestPermission();
    widget.languageController.addListener(_onLanguageChanged);
    widget.countryController.addListener(_onCountryChanged);
    // Aligne le réseau sélectionné sur le pays déjà enregistré au
    // lancement (ex: après une relance de l'app).
    networkController.value = networksForCountry(widget.countryController.value).first['id'] as String;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStatus();
    }
  }

  void _setupRealtimeSubscription() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Écoute en temps réel de la table 'subscriptions' pour cet agent
    _realtimeChannel = Supabase.instance.client
        .channel('agent_subscription_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'subscriptions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'agent_id',
            value: user.id,
          ),
          callback: (_) {
            if (mounted) _loadStatus();
          },
        )
        .subscribe();

    // Polling de sécurité toutes les 30 secondes
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadStatus();
    });
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
    WidgetsBinding.instance.removeObserver(this);
    _realtimeChannel?.unsubscribe();
    _periodicTimer?.cancel();
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

    // Alerte notification si l'abonnement expire bientôt ou est expiré.
    final isExpired = status.state == SubscriptionState.expire;
    final expiringSoon = (status.state == SubscriptionState.essai || status.state == SubscriptionState.actif)
        && status.daysLeft <= 3;
    if (isExpired || expiringSoon) {
      await LocalNotificationService.showSubscriptionAlert(
        isExpired: isExpired,
        daysLeft: status.daysLeft,
        lang: widget.languageController.value,
      );
    }
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
    // l'abonnement est expiré — c'est là que vit la gestion de
    // l'abonnement (voir ReglagesScreen._abonnementCard).
    final currentTab = (isExpired && _tabIndex != 4)
        ? _ExpiredGate(
            status: _status!,
            onStatusChanged: () async {
              await _loadStatus();
              if (_status?.state == SubscriptionState.actif && mounted) {
                setState(() => _tabIndex = 0); // Retour à la saisie dès que l'abonnement est actif
              }
            },
            languageController: widget.languageController,
          )
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
              isLabelVisible: isExpired ||
                  (_status!.state == SubscriptionState.essai && _status!.daysLeft <= 3) ||
                  (_status!.state == SubscriptionState.actif && _status!.daysLeft <= 3),
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
  final SubscriptionStatus status;
  final VoidCallback onStatusChanged;
  final LanguageController languageController;

  const _ExpiredGate({
    required this.status,
    required this.onStatusChanged,
    required this.languageController,
  });

  @override
  Widget build(BuildContext context) {
    final lang = languageController.value;
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
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AbonnementScreen(
                        status: status,
                        onStatusChanged: onStatusChanged,
                        languageController: languageController,
                      ),
                    ));
                    onStatusChanged();
                  },
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
