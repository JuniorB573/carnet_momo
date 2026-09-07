import 'package:flutter/material.dart';

import '../models/momo_transaction.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/formatters.dart';
import '../services/translations.dart';
import '../services/country_controller.dart';
import '../theme/app_theme.dart';
import '../theme/networks.dart';

/// Vue globale des totaux et des commissions : toutes les opérations de
/// dépôt et de retrait, pour tous les réseaux, avec calcul automatique du
/// suivi quotidien ("Aujourd'hui") et mensuel ("Ce mois"), dépôt à part,
/// retrait à part, puis le total de commission — par réseau, et pour
/// l'ensemble.
class SyntheseScreen extends StatefulWidget {
  final LanguageController languageController;
  final CountryController countryController;
  const SyntheseScreen({super.key, required this.languageController, required this.countryController});

  @override
  State<SyntheseScreen> createState() => _SyntheseScreenState();
}

class _SyntheseScreenState extends State<SyntheseScreen> {
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

  Future<void> _exportPdf(List<MomoTransaction> today, List<MomoTransaction> thisMonth) async {
    setState(() => _exporting = true);
    try {
      await _exportService.exportSummaryPdf(
        today: today,
        thisMonth: thisMonth,
        countryId: widget.countryController.value,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final now = DateTime.now();
    final today = _all
        .where((tx) => tx.date.year == now.year && tx.date.month == now.month && tx.date.day == now.day)
        .toList();
    final currentMonthTx = _all.where((tx) => tx.date.year == now.year && tx.date.month == now.month).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t('synthese', _lang),
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.ink)),
              OutlinedButton.icon(
                onPressed: _exporting ? null : () => _exportPdf(today, currentMonthTx),
                icon: _exporting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: Text(t('exporter', _lang)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.green,
                  side: const BorderSide(color: AppColors.green),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _summaryTable(t('aujourdhui', _lang), today),
          const SizedBox(height: 10),
          _summaryTable(t('ce_mois', _lang), currentMonthTx),
        ],
      ),
    );
  }

  /// Éclaté réseau par réseau : pour chaque réseau qui a au moins une
  /// opération sur la période, dépôt à part, retrait à part, puis le
  /// sous-total de commission de ce réseau — avant le total général.
  /// Fonctionne pour n'importe quel réseau de n'importe quel pays puisqu'on
  /// part des réseaux réellement présents dans `txs`, ordonnés selon la
  /// liste du pays de l'agent (networksForCountry).
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

    final countryNetworks = networksForCountry(widget.countryController.value);
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

      blocks.add(_networkSummaryBlock(
        network: network,
        depotMontant: depotMontant,
        depotCommission: depotCommission,
        retraitMontant: retraitMontant,
        retraitCommission: retraitCommission,
        totalCommission: depotCommission + retraitCommission,
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
            Row(
              children: [
                const Expanded(flex: 2, child: SizedBox()),
                Expanded(
                    flex: 3,
                    child: Text(t('montant_col', _lang),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 3,
                    child: Text(t('commission_col', _lang),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600))),
              ],
            ),
            const Divider(height: 14),
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

  Widget _networkSummaryBlock({
    required Map<String, dynamic> network,
    required int depotMontant,
    required int depotCommission,
    required int retraitMontant,
    required int retraitCommission,
    required int totalCommission,
  }) {
    return Column(
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
            Text(
              (network['label'] as String).toUpperCase(),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _summaryRow(t('depot', _lang), depotMontant, depotCommission, AppColors.green),
        const SizedBox(height: 8),
        _summaryRow(t('retrait', _lang), retraitMontant, retraitCommission, AppColors.orange),
        const SizedBox(height: 8),
        _summaryRow(t('total_commission_reseau', _lang), depotMontant + retraitMontant, totalCommission,
            AppColors.ink,
            bold: true),
      ],
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
}
