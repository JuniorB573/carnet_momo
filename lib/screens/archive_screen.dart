import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/momo_transaction.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/formatters.dart';
import '../services/translations.dart';
import '../services/country_controller.dart';
import '../theme/app_theme.dart';
import '../theme/networks.dart';
import 'edit_transaction_sheet.dart';

/// Rapports mensuels : chaque mois a son propre dossier archivé,
/// contenant l'historique complet de ce mois, les totaux par type
/// d'opération (dépôt à part, retrait à part) réseau par réseau, et le
/// total de commission gagnée sur le mois — avec export CSV.
class ArchiveScreen extends StatefulWidget {
  final LanguageController languageController;
  final CountryController countryController;
  const ArchiveScreen({super.key, required this.languageController, required this.countryController});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final _db = DatabaseService.instance;
  final _exportService = ExportService();
  List<MomoTransaction> _all = [];
  bool _loading = true;
  bool _exporting = false;

  String get _lang => widget.languageController.value;

  @override
  void initState() {
    super.initState();
    widget.languageController.addListener(_onLanguageChanged);
    widget.countryController.addListener(_onCountryChanged);
    _load();
  }

  void _onLanguageChanged() => setState(() {});
  void _onCountryChanged() => setState(() {});

  @override
  void dispose() {
    widget.languageController.removeListener(_onLanguageChanged);
    widget.countryController.removeListener(_onCountryChanged);
    super.dispose();
  }

  Future<void> _load() async {
    final txs = await _db.getTransactions();
    if (!mounted) return;
    setState(() {
      _all = txs;
      _loading = false;
    });
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    // Un dossier par mois qui contient au moins une opération, du plus
    // récent au plus ancien — y compris le mois en cours.
    final byMonth = <String, List<MomoTransaction>>{};
    for (final tx in _all) {
      final key = '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => []).add(tx);
    }
    final monthKeys = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(t('archive', _lang),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 6),
          Text(t('archive_desc', _lang), style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft)),
          const SizedBox(height: 16),
          if (monthKeys.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(t('aucune_operation_periode', _lang),
                    style: const TextStyle(color: AppColors.inkMuted, fontSize: 13.5)),
              ),
            )
          else
            ...monthKeys.map((key) => _monthFolder(key, byMonth[key]!)),
        ],
      ),
    );
  }

  Widget _monthFolder(String key, List<MomoTransaction> txs) {
    final parts = key.split('-');
    final year = int.parse(parts[0]);
    final monthNum = int.parse(parts[1]);
    final monthDate = DateTime(year, monthNum);
    final totalCommission = txs.fold<int>(0, (a, tx) => a + tx.commission);
    final sorted = [...txs]..sort((a, b) => b.date.compareTo(a.date));

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          leading: const Icon(Icons.folder_outlined, color: AppColors.inkSoft, size: 20),
          title: Text(
            _capitalize(DateFormat('MMMM yyyy', 'fr_FR').format(monthDate)),
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
          ),
          subtitle: Text('${txs.length} ${t('n_operations', _lang)} · ${fmtF(totalCommission)}',
              style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
          trailing: IconButton(
            icon: _exporting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share, size: 18, color: AppColors.green),
            tooltip: t('exporter', _lang),
            onPressed: _exporting
                ? null
                : () async {
                    setState(() => _exporting = true);
                    try {
                      await _exportService.exportMonth(transactions: _all, year: year, month: monthNum);
                    } finally {
                      if (mounted) setState(() => _exporting = false);
                    }
                  },
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: _monthSummary(txs),
            ),
            if (sorted.any((tx) => tx.type == 'depot')) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                child: Text(_lang == 'fr' ? 'DÉPÔTS' : 'DEPOSITS',
                    style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w700)),
              ),
              ...sorted.where((tx) => tx.type == 'depot').map((tx) => Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 10, right: 10),
                    child: _txRow(tx),
                  )),
              const SizedBox(height: 12),
            ],
            if (sorted.any((tx) => tx.type == 'retrait')) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                child: Text(_lang == 'fr' ? 'RETRAITS' : 'WITHDRAWALS',
                    style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w700)),
              ),
              ...sorted.where((tx) => tx.type == 'retrait').map((tx) => Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 10, right: 10),
                    child: _txRow(tx),
                  )),
            ],
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  /// Totaux par type d'opération (dépôt à part, retrait à part) réseau
  /// par réseau, puis le total de commission du mois — même principe que
  /// l'onglet Synthèse, mais figé sur le mois de ce dossier.
  Widget _monthSummary(List<MomoTransaction> txs) {
    final countryNetworks = networksForCountry(widget.countryController.value);
    final presentIds = txs.map((tx) => tx.network).toSet();
    final orderedNetworks = [
      ...countryNetworks.where((n) => presentIds.contains(n['id'])),
      ...kAllNetworks.where(
          (n) => presentIds.contains(n['id']) && !countryNetworks.any((cn) => cn['id'] == n['id'])),
    ];

    int grandMontant = 0;
    int grandCommission = 0;
    final rows = <Widget>[];

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

      rows.add(Column(
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
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 6),
          _summaryRow(t('depot', _lang), depotMontant, depotCommission, AppColors.green),
          const SizedBox(height: 6),
          _summaryRow(t('retrait', _lang), retraitMontant, retraitCommission, AppColors.orange),
        ],
      ));
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1) const Divider(height: 16),
          ],
          const Divider(height: 18, thickness: 1),
          _summaryRow(t('total_general', _lang), grandMontant, grandCommission, AppColors.ink, bold: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, int montant, int commission, Color color, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 13.5 : 12.5,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () async {
          final changed = await showEditTransactionSheet(context, tx, _lang, widget.countryController.value);
          if (changed == true) _load();
        },
        leading: Icon(
          isDepot ? Icons.arrow_downward : Icons.arrow_upward,
          color: isDepot ? AppColors.green : AppColors.orange,
        ),
        title: Text(
          '${isDepot ? t('depot', _lang) : t('retrait', _lang)} · ${fmtF(tx.montant)} · ${network['label']}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${tx.operationNumber} · ${DateFormat('dd/MM/yyyy HH:mm').format(tx.date)}',
          style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('+${fmtF(tx.commission)}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.green)),
            const Icon(Icons.edit_outlined, size: 13, color: AppColors.inkMuted),
          ],
        ),
      ),
    );
  }
}
