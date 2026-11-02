import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/momo_transaction.dart';
import '../services/country_controller.dart';
import '../services/export_service.dart';
import '../services/formatters.dart';
import '../services/owner_service.dart';
import '../services/translations.dart';
import '../theme/app_theme.dart';
import '../theme/networks.dart';

class OwnerDashboardScreen extends StatefulWidget {
  final LanguageController languageController;
  final CountryController countryController;

  const OwnerDashboardScreen({
    super.key,
    required this.languageController,
    required this.countryController,
  });

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final _ownerService = OwnerService();
  final _exportService = ExportService();

  List<LinkedKiosk> _kiosks = [];
  LinkedKiosk? _selectedKiosk;
  List<MomoTransaction> _transactions = [];
  bool _loading = true;
  bool _loadingTx = false;
  String _timeFilter = 'today'; // 'today', 'week', 'month', 'all'

  String get _lang => widget.languageController.value;

  @override
  void initState() {
    super.initState();
    _loadKiosks();
  }

  Future<void> _loadKiosks() async {
    setState(() => _loading = true);
    final kiosks = await _ownerService.getLinkedKiosks();
    if (!mounted) return;
    setState(() {
      _kiosks = kiosks;
      _selectedKiosk = kiosks.isNotEmpty ? kiosks.first : null;
      _loading = false;
    });

    if (_selectedKiosk != null) {
      await _loadTransactionsForKiosk(_selectedKiosk!);
    }
  }

  Future<void> _loadTransactionsForKiosk(LinkedKiosk kiosk) async {
    setState(() => _loadingTx = true);
    final txs = await _ownerService.fetchKioskTransactions(kiosk.agentId);
    if (!mounted) return;
    setState(() {
      _transactions = txs;
      _loadingTx = false;
    });
  }

  List<MomoTransaction> get _filteredTransactions {
    final now = DateTime.now();
    switch (_timeFilter) {
      case 'today':
        final startOfDay = DateTime(now.year, now.month, now.day);
        return _transactions.where((t) => t.date.isAfter(startOfDay)).toList();
      case 'week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return _transactions.where((t) => t.date.isAfter(start)).toList();
      case 'month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        return _transactions.where((t) => t.date.isAfter(startOfMonth)).toList();
      default:
        return _transactions;
    }
  }

  Future<void> _showAddKioskDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String? dialogError;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.storefront, color: AppColors.green),
                  const SizedBox(width: 8),
                  Text(t('ajouter_kiosque', _lang), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('nom_kiosque_label', _lang).toUpperCase(),
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(hintText: t('nom_kiosque_hint', _lang)),
                    ),
                    const SizedBox(height: 14),
                    Text(t('numero_agent_label', _lang).toUpperCase(),
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(hintText: '+229 01 XX XX XX XX'),
                    ),
                    const SizedBox(height: 14),
                    Text(t('code_agent_label', _lang).toUpperCase(),
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: codeCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(hintText: '123456', counterText: ''),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Text(dialogError!, style: const TextStyle(color: AppColors.orange, fontSize: 12.5)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: Text(t('annuler', _lang)),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();
                          final code = codeCtrl.text.trim();
                          if (name.isEmpty || phone.isEmpty || code.isEmpty) {
                            setDialogState(() => dialogError = 'Veuillez remplir tous les champs.');
                            return;
                          }
                          setDialogState(() {
                            saving = true;
                            dialogError = null;
                          });
                          try {
                            final newKiosk = await _ownerService.linkAgent(
                              phone: phone,
                              code: code,
                              customName: name,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(t('kiosque_ajoute_succes', _lang)),
                                backgroundColor: AppColors.green,
                              ),
                            );
                            await _loadKiosks();
                            setState(() => _selectedKiosk = newKiosk);
                            await _loadTransactionsForKiosk(newKiosk);
                          } catch (e) {
                            setDialogState(() {
                              saving = false;
                              dialogError = e.toString().replaceAll('Exception:', '').trim();
                            });
                          }
                        },
                  child: Text(saving ? 'Liaison…' : t('associer_kiosque', _lang)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportPdf() async {
    if (_selectedKiosk == null) return;
    try {
      final txList = _filteredTransactions;
      final file = await _exportService.exportKioskReport(
        kioskName: _selectedKiosk!.customName,
        agentPhone: _selectedKiosk!.agentPhone,
        transactions: txList,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${t('enregistre_dans_documents', _lang)}\n(${file.path.split('/').last})"),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur export: $e'), backgroundColor: AppColors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          _lang == 'en' ? 'My Dashboard' : 'Mon Tableau de bord',
          style: const TextStyle(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business_outlined, color: AppColors.green),
            tooltip: t('ajouter_kiosque', _lang),
            onPressed: _showAddKioskDialog,
          ),
          if (_selectedKiosk != null)
            IconButton(
              icon: const Icon(Icons.share, color: AppColors.green),
              tooltip: t('exporter_whatsapp', _lang),
              onPressed: _exportPdf,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _kiosks.isEmpty
              ? _buildEmptyState()
              : _buildDashboard(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront, size: 48, color: AppColors.green),
            ),
            const SizedBox(height: 16),
            Text(
              t('aucun_kiosque', _lang),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              t('espace_proprietaire_desc', _lang),
              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddKioskDialog,
              icon: const Icon(Icons.add),
              label: Text(t('ajouter_premier_kiosque', _lang)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final filtered = _filteredTransactions;
    int depots = 0, retraits = 0, comm = 0;
    for (final t in filtered) {
      if (t.type == 'depot') {
        depots += t.montant;
      } else {
        retraits += t.montant;
      }
      comm += t.commission;
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (_selectedKiosk != null) {
          await _loadTransactionsForKiosk(_selectedKiosk!);
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 1. Sélecteur de kiosques / onglets horizontaux ──────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._kiosks.map((k) {
                  final active = _selectedKiosk?.id == k.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(k.customName),
                      selected: active,
                      selectedColor: AppColors.green,
                      labelStyle: TextStyle(
                        color: active ? Colors.white : AppColors.inkSoft,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedKiosk = k);
                          _loadTransactionsForKiosk(k);
                        }
                      },
                    ),
                  );
                }),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16, color: AppColors.green),
                  label: Text(t('ajouter_kiosque', _lang), style: const TextStyle(color: AppColors.green, fontSize: 12)),
                  onPressed: _showAddKioskDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── 2. En-tête du kiosque sélectionné ───────────────────
          if (_selectedKiosk != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.store, color: AppColors.green, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedKiosk!.customName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Agent : ${_selectedKiosk!.agentPhone}',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.orange, size: 20),
                      tooltip: t('retirer_kiosque', _lang),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: Text(t('retirer_kiosque', _lang)),
                            content: Text(t('supprimer_kiosque_confirm', _lang)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('annuler', _lang))),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
                                onPressed: () => Navigator.pop(c, true),
                                child: Text(t('retirer_kiosque', _lang)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _ownerService.removeKiosk(_selectedKiosk!.id);
                          await _loadKiosks();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),

          // ── 3. Filtre Temporel (Aujourd'hui, Semaine, Mois, Tout)
          Row(
            children: [
              _timeChip('today', "Aujourd'hui"),
              const SizedBox(width: 6),
              _timeChip('week', 'Cette semaine'),
              const SizedBox(width: 6),
              _timeChip('month', 'Ce mois'),
              const SizedBox(width: 6),
              _timeChip('all', 'Tout'),
            ],
          ),
          const SizedBox(height: 14),

          // ── 4. Cartes de synthèse financière ────────────────────
          Row(
            children: [
              Expanded(
                child: _summaryMetricCard(
                  title: 'DÉPÔTS',
                  amount: depots,
                  color: AppColors.green,
                  icon: Icons.arrow_downward,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryMetricCard(
                  title: 'RETRAITS',
                  amount: retraits,
                  color: AppColors.orange,
                  icon: Icons.arrow_upward,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('COMMISSIONS GÉNÉRÉES',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkMuted)),
                    SizedBox(height: 2),
                    Text('Bénéfice net kiosque', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                  ],
                ),
                Text(
                  '+${fmtF(comm)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.green),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 5. Bouton d'exportation PDF & WhatsApp ───────────────
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _exportPdf,
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: Text("${t('exporter_pdf', _lang)} / WhatsApp"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 6. Liste des dernières opérations ────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TRANSACTIONS (${filtered.length})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.inkMuted),
              ),
              if (_loadingTx)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 8),

          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: const Text('Aucune transaction pour cette période.',
                  style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
            )
          else
            ...filtered.map((tx) => _txTile(tx)),
        ],
      ),
    );
  }

  Widget _timeChip(String id, String label) {
    final active = _timeFilter == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _timeFilter = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active ? AppColors.ink : AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? AppColors.ink : AppColors.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryMetricCard({
    required String title,
    required int amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(title, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            fmtF(amount),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _txTile(MomoTransaction tx) {
    final net = kAllNetworks.firstWhere((n) => n['id'] == tx.network, orElse: () => {'label': tx.network});
    final isDepot = tx.type == 'depot';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Icon(
          isDepot ? Icons.arrow_downward : Icons.arrow_upward,
          color: isDepot ? AppColors.green : AppColors.orange,
          size: 20,
        ),
        title: Text(
          '${isDepot ? "Dépôt" : "Retrait"} · ${fmtF(tx.montant)} · ${net['label']}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${tx.operationNumber}${tx.clientName != null ? " (${tx.clientName})" : ""} · ${DateFormat('dd/MM HH:mm').format(tx.date)}',
          style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
        ),
        trailing: Text(
          '+${fmtF(tx.commission)}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.green),
        ),
      ),
    );
  }
}
