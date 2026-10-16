import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/subscription_service.dart';
import '../services/translations.dart';
import '../theme/app_theme.dart';

/// Écran d'abonnement : paiement exclusivement via SasPay (Mobile Money
/// ou carte). L'activation se fait automatiquement dès que SasPay
/// confirme le paiement (via webhook côté serveur) — aucun virement
/// manuel, aucun code à saisir par l'agent.
class AbonnementScreen extends StatefulWidget {
  final SubscriptionStatus status;
  final VoidCallback onStatusChanged;
  final LanguageController languageController;

  const AbonnementScreen({
    super.key,
    required this.status,
    required this.onStatusChanged,
    required this.languageController,
  });

  @override
  State<AbonnementScreen> createState() => _AbonnementScreenState();
}

class _AbonnementScreenState extends State<AbonnementScreen> {
  final _service = SubscriptionService();
  String? _error;
  bool _loading = false;
  Timer? _pollTimer;

  String get _lang => widget.languageController.value;

  @override
  void initState() {
    super.initState();
    widget.languageController.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() => setState(() {});

  @override
  void dispose() {
    _pollTimer?.cancel();
    widget.languageController.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _startPaymentPolling() {
    _pollTimer?.cancel();
    int count = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      count++;
      if (count > 20 || !mounted) {
        timer.cancel();
        return;
      }
      final s = await _service.getStatus();
      if (!mounted) return;
      if (s.state == SubscriptionState.actif) {
        timer.cancel();
        widget.onStatusChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('abonnement_active_msg', _lang)),
            backgroundColor: AppColors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  Future<void> _payWithSasPay() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await _service.startSasPayCheckout();
      final uri = Uri.parse(url);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('launch_failed');
      // L'écran repassera automatiquement en "actif" dès que le webhook
      // SasPay aura mis à jour le statut côté serveur ; l'agent peut
      // revenir sur cet écran pour voir la mise à jour.
      widget.onStatusChanged();
      _startPaymentPolling();
    } catch (_) {
      setState(() => _error = t('echec_paiement', _lang));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(t('abonnement', _lang),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 14),
        _statusCard(s),
        const SizedBox(height: 20),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_user_outlined, color: AppColors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SasPay',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  t('paiement_securise_saspay', _lang),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft, height: 1.5),
                ),
                const SizedBox(height: 6),
                Text(
                  t('activation_immediate', _lang),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft, height: 1.5),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: AppColors.orange, fontSize: 12.5)),
                ],
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _payWithSasPay,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.lock_outline, size: 18),
                  label: Text(
                    _loading
                        ? t('redirection_saspay', _lang)
                        : '${t('payer_avec_saspay', _lang)} — ${SubscriptionService.monthlyFeeFcfa} F CFA',
                  ),
                ),
              ],
            ),
          ),
        ),


      ],
    );
  }

  Widget _statusCard(SubscriptionStatus s) {
    late String badge;
    late Color badgeColor;
    late String big;
    String? sub;

    final jourWord = s.daysLeft > 1 ? t('jour_restant_pl', _lang) : t('jour_restant_sg', _lang);

    switch (s.state) {
      case SubscriptionState.essai:
        badge = t('essai_gratuit', _lang);
        badgeColor = AppColors.inkMuted;
        big = '${s.daysLeft} $jourWord';
        sub = "${t('apres_essai_1', _lang)}${SubscriptionService.monthlyFeeFcfa}${t('apres_essai_2', _lang)}";
        break;
      case SubscriptionState.actif:
        badge = t('abonnement_actif_badge', _lang);
        badgeColor = AppColors.green;
        big = '${s.daysLeft} $jourWord';
        sub = s.renewalDate != null
            ? '${t('renouvellement_1', _lang)}${DateFormat('dd/MM/yyyy').format(s.renewalDate!)}.'
            : null;
        break;
      case SubscriptionState.expire:
        badge = t('essai_termine_badge', _lang);
        badgeColor = AppColors.orange;
        big = '${SubscriptionService.monthlyFeeFcfa} F CFA / mois';
        sub = t('active_pour_continuer', _lang);
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(20)),
              child: Text(badge,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 10),
            Text(big, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink)),
            if (sub != null) ...[
              const SizedBox(height: 6),
              Text(sub, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
            ],
          ],
        ),
      ),
    );
  }
}
