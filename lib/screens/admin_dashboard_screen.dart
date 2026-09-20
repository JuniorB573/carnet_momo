import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/admin_dashboard_service.dart';
import '../services/country_controller.dart';
import '../services/formatters.dart';
import '../services/translations.dart';
import '../theme/app_theme.dart';
import '../theme/countries.dart';
import 'agent_detail_screen.dart';
import 'home_shell.dart';

/// Visible uniquement par un compte marqué `role = 'admin'` (voir
/// AuthService.isCurrentUserAdmin et RoleGate). Liste tous les agents,
/// leur pays, le statut de leur abonnement, le cumul de leurs
/// opérations et l'ensemble des avis/retours envoyés.
class AdminDashboardScreen extends StatefulWidget {
  final LanguageController languageController;
  final CountryController countryController;
  final VoidCallback onSignOut;
  const AdminDashboardScreen({
    super.key,
    required this.languageController,
    required this.countryController,
    required this.onSignOut,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _service = AdminDashboardService();
  List<AgentSummary> _agents = [];
  List<AgentFeedback> _feedbacks = [];
  bool _loading = true;
  String? _error;

  String get _lang => widget.languageController.value;

  @override
  void initState() {
    super.initState();
    widget.languageController.addListener(_onLanguageChanged);
    _load();
  }

  void _onLanguageChanged() => setState(() {});

  @override
  void dispose() {
    widget.languageController.removeListener(_onLanguageChanged);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final agents = await _service.fetchAgentSummaries();
      final feedbacks = await _service.fetchFeedbacks();
      if (!mounted) return;
      setState(() {
        _agents = agents;
        _feedbacks = feedbacks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString().toLowerCase();
      setState(() {
        if (errStr.contains('socketexception') || errStr.contains('failed host lookup') || errStr.contains('timeoutexception') || errStr.contains('connection reset')) {
          _error = t('err_pas_internet', _lang);
        } else {
          _error = '${t('erreur_prefix', _lang)}$e';
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCommission = _agents.fold<int>(0, (a, s) => a + s.totalCommission);
    final totalOperations = _agents.fold<int>(0, (a, s) => a + s.transactionCount);
    final avgRating = _feedbacks.isEmpty
        ? 0.0
        : _feedbacks.fold<int>(0, (a, f) => a + f.rating) / _feedbacks.length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('tableau_de_bord', _lang)),
          actions: [
            IconButton(
              icon: const Icon(Icons.smartphone),
              tooltip: t('voir_comme_agent', _lang),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => HomeShell(
                    languageController: widget.languageController,
                    countryController: widget.countryController,
                  ),
                ));
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: t('se_deconnecter', _lang),
              onPressed: widget.onSignOut,
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.people_alt_outlined, size: 20),
                text: '${t('agents_tab', _lang)} (${_agents.length})',
              ),
              Tab(
                icon: const Icon(Icons.star_rate_rounded, size: 20),
                text: '${t('avis_tab', _lang)} (${_feedbacks.length})',
              ),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        const SizedBox(height: 40),
                        Text(_error!, style: const TextStyle(color: AppColors.orange)),
                      ],
                    )
                  : TabBarView(
                      children: [
                        // Onglet 1 : Agents
                        ListView(
                          padding: const EdgeInsets.all(18),
                          children: [
                            Row(
                              children: [
                                Expanded(child: _statCard(t('operations_col', _lang), '$totalOperations')),
                                const SizedBox(width: 10),
                                Expanded(child: _statCard(t('commission_totale_col', _lang), fmtF(totalCommission))),
                              ],
                            ),
                            const SizedBox(height: 18),
                            if (_agents.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(t('aucun_agent', _lang),
                                      style: const TextStyle(color: AppColors.inkMuted, fontSize: 13.5)),
                                ),
                              )
                            else
                              ..._agents.map(_agentCard),
                          ],
                        ),

                        // Onglet 2 : Avis & Retours
                        ListView(
                          padding: const EdgeInsets.all(18),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _statCard(
                                    t('note_moyenne', _lang),
                                    _feedbacks.isEmpty
                                        ? '—'
                                        : '★ ${avgRating.toStringAsFixed(1)} / 5',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _statCard(
                                    t('total_avis', _lang),
                                    '${_feedbacks.length}',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            if (_feedbacks.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(t('aucun_avis', _lang),
                                      style: const TextStyle(color: AppColors.inkMuted, fontSize: 13.5)),
                                ),
                              )
                            else
                              ..._feedbacks.map(_feedbackCard),
                          ],
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
          ],
        ),
      ),
    );
  }

  Widget _agentCard(AgentSummary agent) {
    final country = agent.country != null ? countryById(agent.country!) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AgentDetailScreen(agent: agent, languageController: widget.languageController),
          ));
          // On rafraîchit toujours au retour : l'agent peut avoir été
          // prolongé exceptionnellement depuis l'écran de détail, et le
          // statut affiché sur cette carte doit rester à jour.
          _load();
        },
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    agent.phoneNumber,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ),
                if (agent.role == 'admin')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('ADMIN',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.green)),
                  ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.inkMuted),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              country != null ? '${country['flag']} ${country['name']}' : '—',
              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 10),
            _statusBadge(agent),
            const Divider(height: 22),
            Row(
              children: [
                Expanded(
                  child: _miniStat(t('operations_col', _lang), '${agent.transactionCount}'),
                ),
                Expanded(
                  child: _miniStat(t('montant_col', _lang), fmtF(agent.totalMontant)),
                ),
                Expanded(
                  child: _miniStat(t('commission_totale_col', _lang), fmtF(agent.totalCommission)),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _statusBadge(AgentSummary agent) {
    late final String label;
    late final Color color;
    switch (agent.subStatus) {
      case AgentSubStatus.essai:
        label = t('essai_gratuit', _lang);
        color = AppColors.orange;
        break;
      case AgentSubStatus.actif:
        label = t('abonnement_actif_badge', _lang);
        color = AppColors.green;
        break;
      case AgentSubStatus.expire:
        label = t('essai_termine_badge', _lang);
        color = AppColors.inkMuted;
        break;
      case AgentSubStatus.inconnu:
        label = '—';
        color = AppColors.inkMuted;
        break;
    }

    // Afficher les jours restants pour les statuts actif et essai
    final showDays = agent.subStatus == AgentSubStatus.essai ||
        agent.subStatus == AgentSubStatus.actif;
    final daysText = agent.daysLeft <= 1
        ? '${agent.daysLeft} jour restant'
        : '${agent.daysLeft} jours restants';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ),
        if (showDays) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Text(
              daysText,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ],
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 9.5, color: AppColors.inkMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
      ],
    );
  }

  Widget _feedbackCard(AgentFeedback feedback) {
    final country = feedback.country != null ? countryById(feedback.country!) : null;
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(feedback.createdAt);

    Future<void> deleteFeedback() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('confirmer_suppression_avis_titre', _lang)),
          content: Text(t('confirmer_suppression_avis_texte', _lang)),
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
      try {
        await _service.deleteFeedback(feedback.id);
        if (!mounted) return;
        setState(() => _feedbacks.removeWhere((f) => f.id == feedback.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('avis_supprime', _lang))),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t('erreur_prefix', _lang)}$e')),
        );
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feedback.phoneNumber,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        country != null ? '${country['flag']} ${country['name']}' : '—',
                        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.orange, size: 20),
                  tooltip: t('supprimer_avis', _lang),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: deleteFeedback,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(5, (i) {
                final filled = i < feedback.rating;
                return Icon(
                  filled ? Icons.star : Icons.star_border,
                  color: filled ? AppColors.mtn : AppColors.inkMuted,
                  size: 20,
                );
              }),
            ),
            if (feedback.comment != null && feedback.comment!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  feedback.comment!,
                  style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
