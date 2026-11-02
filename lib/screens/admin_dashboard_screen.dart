import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/admin_dashboard_service.dart';
import '../services/auth_service.dart';
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
  final _searchController = TextEditingController();
  String _searchQuery = '';
  AgentSubStatus? _statusFilter;
  List<AgentSummary> _agents = [];
  List<AgentFeedback> _feedbacks = [];
  List<PatronGroup> _patrons = [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _subscription;

  String get _lang => widget.languageController.value;

  @override
  void initState() {
    super.initState();
    widget.languageController.addListener(_onLanguageChanged);
    _load();
    _setupRealtime();
  }

  void _setupRealtime() {
    _subscription = Supabase.instance.client
        .channel('public:transactions')
        .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'transactions',
            callback: (payload) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _lang == 'fr'
                          ? 'Nouvelle transaction enregistrée par un agent !'
                          : 'New transaction recorded by an agent!',
                    ),
                    duration: const Duration(seconds: 4),
                    backgroundColor: AppColors.green,
                  ),
                );
                _load(showLoading: false);
              }
            })
        .subscribe();
  }

  void _onLanguageChanged() => setState(() {});

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _searchController.dispose();
    widget.languageController.removeListener(_onLanguageChanged);
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final agents = await _service.fetchAgentSummaries();
      final feedbacks = await _service.fetchFeedbacks();
      final patrons = await _service.fetchPatronsWithKiosks();
      if (!mounted) return;
      setState(() {
        _agents = agents;
        _feedbacks = feedbacks;
        _patrons = patrons;
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

  Future<void> _openWhatsApp(String rawPhone, String message) async {
    final e164 = AuthService().formatE164Phone(rawPhone);
    final msg = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$e164?text=$msg');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir WhatsApp : $e')),
        );
      }
    }
  }

  Future<void> _contactAgentWhatsApp(AgentSummary agent) async {
    final rawPhone = agent.whatsappNumber?.isNotEmpty == true
        ? agent.whatsappNumber!
        : agent.phoneNumber;
    final msg = _lang == 'fr'
        ? 'Bonjour, je vous contacte depuis Carnet MoMo.'
        : 'Hello, I am contacting you from Carnet MoMo.';
    await _openWhatsApp(rawPhone, msg);
  }

  @override
  Widget build(BuildContext context) {
    final totalCommission = _agents.fold<int>(0, (a, s) => a + s.totalCommission);
    final totalOperations = _agents.fold<int>(0, (a, s) => a + s.transactionCount);
    final avgRating = _feedbacks.isEmpty
        ? 0.0
        : _feedbacks.fold<int>(0, (a, f) => a + f.rating) / _feedbacks.length;

    final activeCount = _agents.where((a) => a.subStatus == AgentSubStatus.actif).length;
    final trialCount = _agents.where((a) => a.subStatus == AgentSubStatus.essai).length;
    final expiredCount = _agents.where((a) => a.subStatus == AgentSubStatus.expire).length;

    final filteredAgents = _agents.where((a) {
      if (_statusFilter != null && a.subStatus != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final country = a.country != null ? countryById(a.country!) : null;
        final countryName = country != null ? country['name'].toString().toLowerCase() : '';
        final phone = a.phoneNumber.toLowerCase();
        final whatsapp = a.whatsappNumber?.toLowerCase() ?? '';
        if (!phone.contains(_searchQuery) &&
            !whatsapp.contains(_searchQuery) &&
            !countryName.contains(_searchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: Navigator.canPop(context) ? const BackButton() : null,
          title: Text(t('tableau_admin_titre', _lang)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualiser',
              onPressed: () => _load(),
            ),
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
                icon: const Icon(Icons.storefront_outlined, size: 20),
                text: '${t('patrons_tab', _lang)} (${_patrons.length})',
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
                          padding: const EdgeInsets.all(16),
                          children: [
                            Row(
                              children: [
                                Expanded(child: _statCard(t('agents_connectes', _lang), '${_agents.length}')),
                                const SizedBox(width: 8),
                                Expanded(child: _statCard(t('operations_col', _lang), '$totalOperations')),
                                const SizedBox(width: 8),
                                Expanded(child: _statCard(t('commission_totale_col', _lang), fmtF(totalCommission))),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Barre de recherche
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                                decoration: InputDecoration(
                                  hintText: t('rechercher_agent', _lang),
                                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
                                  prefixIcon: const Icon(Icons.search, color: AppColors.inkMuted, size: 20),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Filtres par statut
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _filterChip(null, '${t('tous_les_agents', _lang)} (${_agents.length})'),
                                  const SizedBox(width: 8),
                                  _filterChip(AgentSubStatus.actif, '${t('agents_actifs', _lang)} ($activeCount)', color: AppColors.green),
                                  const SizedBox(width: 8),
                                  _filterChip(AgentSubStatus.essai, '${t('agents_essai', _lang)} ($trialCount)', color: AppColors.orange),
                                  const SizedBox(width: 8),
                                  _filterChip(AgentSubStatus.expire, '${t('agents_expires', _lang)} ($expiredCount)', color: AppColors.inkMuted),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            if (filteredAgents.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 36),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const Icon(Icons.person_search_outlined, size: 48, color: AppColors.inkMuted),
                                      const SizedBox(height: 8),
                                      Text(
                                        _searchQuery.isNotEmpty || _statusFilter != null
                                            ? 'Aucun agent correspondant'
                                            : t('aucun_agent', _lang),
                                        style: const TextStyle(color: AppColors.inkMuted, fontSize: 13.5),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ...filteredAgents.map(_agentCard),
                          ],
                        ),

                        // Onglet 2 : Patrons & Kiosques
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Row(
                              children: [
                                Expanded(child: _statCard(t('patrons_actifs', _lang), '${_patrons.length}')),
                                const SizedBox(width: 8),
                                Expanded(child: _statCard(t('kiosques_lies', _lang), '${_patrons.fold<int>(0, (sum, p) => sum + p.kiosks.length)}')),
                                const SizedBox(width: 8),
                                Expanded(child: _statCard(t('volume_reseau', _lang), fmtF(_patrons.fold<int>(0, (sum, p) => sum + p.totalMontant)))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_patrons.isEmpty)
                              Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: AppColors.border),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.storefront_outlined, size: 48, color: AppColors.inkMuted),
                                      const SizedBox(height: 12),
                                      Text(
                                        t('aucun_patron', _lang),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.ink),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        t('aucun_patron_desc', _lang),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ..._patrons.map(_patronCard),
                          ],
                        ),

                        // Onglet 3 : Avis & Retours
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

  Widget _filterChip(AgentSubStatus? status, String label, {Color? color}) {
    final active = _statusFilter == status;
    final chipColor = color ?? AppColors.green;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _statusFilter = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? chipColor : chipColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? chipColor : chipColor.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.w600,
            color: active ? Colors.white : chipColor,
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(fontSize: 10, color: AppColors.inkMuted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
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
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AgentDetailScreen(agent: agent, languageController: widget.languageController),
          ));
          _load();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              agent.phoneNumber,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                            ),
                            if (agent.role == 'admin') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('ADMIN',
                                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.green)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              country != null ? '${country['flag']} ${country['name']}' : '—',
                              style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                            ),
                            if (agent.createdAt != null) ...[
                              const Text(' • ', style: TextStyle(color: AppColors.inkMuted, fontSize: 11)),
                              Text(
                                '${t('inscrit_le', _lang)} ${DateFormat('dd/MM/yyyy').format(agent.createdAt!)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Bouton WhatsApp direct
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.12),
                      foregroundColor: const Color(0xFF128C7E),
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    tooltip: t('contacter_whatsapp', _lang),
                    onPressed: () => _contactAgentWhatsApp(agent),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18, color: AppColors.inkMuted),
                ],
              ),
              const SizedBox(height: 10),
              _statusBadge(agent),
              const Divider(height: 20),
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

  Widget _patronCard(PatronGroup patron) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.badge_outlined, color: AppColors.green, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            patron.ownerPhone,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.ink),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('PATRON',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.green)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${patron.kiosks.length} kiosque(s) / agent(s) rattaché(s)',
                        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.12),
                    foregroundColor: const Color(0xFF128C7E),
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  tooltip: 'WhatsApp Patron',
                  onPressed: () => _openWhatsApp(patron.ownerPhone, 'Bonjour Patron, je vous contacte depuis Carnet MoMo.'),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(child: _miniStat(t('operations_col', _lang), '${patron.totalOperations}')),
                Expanded(child: _miniStat(t('montant_col', _lang), fmtF(patron.totalMontant))),
                Expanded(child: _miniStat(t('commission_totale_col', _lang), fmtF(patron.totalCommission))),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'AGENTS & KIOSQUES DE CE PATRON (${patron.kiosks.length})',
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 8),
            ...patron.kiosks.map((kiosk) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storefront, size: 20, color: AppColors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kiosk.customName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Agent : ${kiosk.agentPhone} • ${kiosk.operations} ops • ${fmtF(kiosk.totalMontant)}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(30, 30),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF128C7E)),
                    tooltip: 'WhatsApp Agent',
                    onPressed: () => _openWhatsApp(kiosk.agentPhone, 'Bonjour, je vous contacte depuis Carnet MoMo.'),
                  ),
                ],
              ),
            )),
          ],
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
