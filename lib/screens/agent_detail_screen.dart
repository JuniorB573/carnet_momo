import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/momo_transaction.dart';
import '../services/admin_dashboard_service.dart';
import '../services/local_notification_service.dart';
import '../services/formatters.dart';
import '../services/translations.dart';
import '../theme/app_theme.dart';
import '../theme/countries.dart';
import '../theme/networks.dart';

/// Détail d'un agent depuis le tableau de bord admin : abonnement (avec
/// prolongation exceptionnelle), puis le même type de récapitulatif que
/// l'agent voit dans son propre Historique — dépôt à part, retrait à
/// part, total de commission par réseau — mais ici sur "Ce mois" et sur
/// tout l'historique de l'agent, plus le journal détaillé des opérations.
class AgentDetailScreen extends StatefulWidget {
  final AgentSummary agent;
  final LanguageController languageController;
  const AgentDetailScreen({
    super.key,
    required this.agent,
    required this.languageController,
  });

  @override
  State<AgentDetailScreen> createState() => _AgentDetailScreenState();
}

class _AgentDetailScreenState extends State<AgentDetailScreen> {
  final _service = AdminDashboardService();
  List<MomoTransaction> _txs = [];
  bool _loading = true;
  bool _extending = false;
  bool _deleting = false;
  String? _error;
  late AgentSummary _agent;

  String get _lang => widget.languageController.value;

  @override
  void initState() {
    super.initState();
    _agent = widget.agent;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final txs = await _service.fetchAgentTransactions(_agent.id);
      if (!mounted) return;
      setState(() {
        _txs = txs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '${t('erreur_prefix', _lang)}$e';
        _loading = false;
      });
    }
  }

  Future<void> _extend(int days) async {
    setState(() => _extending = true);
    try {
      final newDate = await _service.extendSubscription(_agent.id, days);
      if (!mounted) return;
      
      // Mettre à jour l'agent localement pour que l'interface affiche la modification
      setState(() {
        _agent = AgentSummary(
          id: _agent.id,
          phoneNumber: _agent.phoneNumber,
          country: _agent.country,
          role: _agent.role,
          subStatus: AgentSubStatus.actif,
          renewalDate: newDate,
          daysLeft: newDate.difference(DateTime.now()).inDays + 1,
          transactionCount: _agent.transactionCount,
          totalMontant: _agent.totalMontant,
          totalCommission: _agent.totalCommission,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('prolongation_confirmee', _lang))),
      );

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (_agent.id == currentUserId) {
        final prefs = await SharedPreferences.getInstance();
        final iso = newDate.toUtc().toIso8601String();
        await prefs.setString('paid_until', iso);
        await prefs.setString('last_notified_paid_until', iso);
        await LocalNotificationService.showSubscriptionActivatedNotification(
          renewalDate: newDate,
          lang: _lang,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t('erreur_prefix', _lang)}$e')),
      );
    } finally {
      if (mounted) setState(() => _extending = false);
    }
  }

  Future<void> _deleteAgent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('confirmer_suppression_titre', _lang)),
        content: Text(t('confirmer_suppression_texte', _lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('annuler', _lang)),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('supprimer', _lang)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await _service.deleteAgent(_agent.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('agent_supprime', _lang))),
      );
      Navigator.of(context).pop(); // retour au tableau de bord
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t('erreur_prefix', _lang)}$e')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showExtendSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(t('jours_7', _lang)),
                onTap: () {
                  Navigator.pop(context);
                  _extend(7);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(t('jours_15', _lang)),
                onTap: () {
                  Navigator.pop(context);
                  _extend(15);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(t('jours_30', _lang)),
                onTap: () {
                  Navigator.pop(context);
                  _extend(30);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanPhone = _agent.phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    final resolvedCountryId = (cleanPhone.startsWith('01') || cleanPhone.startsWith('229'))
        ? 'bj'
        : (_agent.country ?? detectCountryIdFromPhone(_agent.phoneNumber));
    final country = countryById(resolvedCountryId);
    final now = DateTime.now();
    final thisMonth = _txs.where((tx) => tx.date.toLocal().year == now.year && tx.date.toLocal().month == now.month).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(t('detail_agent', _lang)),
        actions: [
          if (_deleting)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.orange),
              tooltip: t('supprimer_agent', _lang),
              onPressed: _deleteAgent,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(_agent.phoneNumber,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${country['flag']} ${country['name']}',
                    style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              t('prolonger_exception', _lang),
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                            ),
                          ),
                          _extending
                              ? const SizedBox(
                                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : TextButton(
                                  onPressed: _showExtendSheet,
                                  child: Text(t('prolonger_court', _lang)),
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_error!, style: const TextStyle(color: AppColors.orange)),
                    )
                  else ...[
                    _summaryTable(t('ce_mois', _lang), thisMonth),
                    const SizedBox(height: 14),
                    _summaryTable(t('tout_lhistorique', _lang), _txs),
                    const SizedBox(height: 18),
                    Text(t('tout_lhistorique', _lang).toUpperCase(),
                        style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    if (_txs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(t('aucune_transaction_agent', _lang),
                            style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
                      )
                    else
                      ..._txs.take(100).map(_txRow),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _summaryTable(String title, List<MomoTransaction> txs) {
    if (txs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.toUpperCase(),
                  style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(t('aucune_operation_periode', _lang),
                  style: const TextStyle(fontSize: 13, color: AppColors.inkMuted)),
            ],
          ),
        ),
      );
    }

    final countryNetworks = _agent.country != null ? networksForCountry(_agent.country!) : <Map<String, dynamic>>[];
    final presentIds = txs.map((tx) => tx.network).toSet();
    final orderedNetworks = [
      ...countryNetworks.where((n) => presentIds.contains(n['id'])),
      ...kAllNetworks.where(
          (n) => presentIds.contains(n['id']) && !countryNetworks.any((cn) => cn['id'] == n['id'])),
    ];

    int grandMontant = 0;
    int grandCommission = 0;
    final blocks = <Widget>[];

    for (final network in orderedNetworks) {
      final netTxs = txs.where((tx) => tx.network == network['id']).toList();
      if (netTxs.isEmpty) continue;

      final depots = netTxs.where((tx) => tx.type == 'depot');
      final retraits = netTxs.where((tx) => tx.type == 'retrait');

      final depotMontant = depots.fold<int>(0, (a, tx) => a + tx.montant);
      final depotCommission = depots.fold<int>(0, (a, tx) => a + tx.commission);
      final retraitMontant = retraits.fold<int>(0, (a, tx) => a + tx.montant);
      final retraitCommission = retraits.fold<int>(0, (a, tx) => a + tx.commission);

      grandMontant += depotMontant + retraitMontant;
      grandCommission += depotCommission + retraitCommission;

      blocks.add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: network['color'] as Color, shape: BoxShape.circle),
              ),
              Text((network['label'] as String).toUpperCase(),
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 8),
          _summaryRow(t('depot', _lang), depotMontant, depotCommission, AppColors.green),
          const SizedBox(height: 8),
          _summaryRow(t('retrait', _lang), retraitMontant, retraitCommission, AppColors.orange),
          const SizedBox(height: 8),
          _summaryRow(t('total_commission_reseau', _lang), depotMontant + retraitMontant,
              depotCommission + retraitCommission, AppColors.ink,
              bold: true),
        ],
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (int i = 0; i < blocks.length; i++) ...[
              blocks[i],
              if (i != blocks.length - 1) const Divider(height: 18),
            ],
            const Divider(height: 20, thickness: 1),
            _summaryRow(t('total_general', _lang), grandMontant, grandCommission, AppColors.ink, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, int montant, int commission, Color color, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 14.5 : 13.5,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: bold ? AppColors.ink : AppColors.inkSoft,
    );
    return Row(
      children: [
        Expanded(flex: 2, child: Text(label, style: style)),
        Expanded(
          flex: 3,
          child: Text(fmtF(montant), textAlign: TextAlign.right, style: style.copyWith(color: color)),
        ),
        Expanded(
          flex: 3,
          child: Text(fmtF(commission), textAlign: TextAlign.right, style: style.copyWith(color: color)),
        ),
      ],
    );
  }

  Widget _txRow(MomoTransaction tx) {
    final network = kAllNetworks.firstWhere((n) => n['id'] == tx.network, orElse: () => kAllNetworks[0]);
    final isDepot = tx.type == 'depot';
    final localDate = tx.date.toLocal();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isDepot ? Icons.arrow_downward : Icons.arrow_upward,
          color: isDepot ? AppColors.green : AppColors.orange,
        ),
        title: Text(
          '${isDepot ? t('depot', _lang) : t('retrait', _lang)} · ${fmtF(tx.montant)} · ${network['label']}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${tx.operationNumber} · ${DateFormat('dd/MM/yyyy HH:mm').format(localDate)}',
          style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
        ),
        trailing: Text('+${fmtF(tx.commission)}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.green)),
      ),
    );
  }
}
