import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/momo_transaction.dart';
import '../services/database_service.dart';
import '../services/formatters.dart';
import '../services/translations.dart';
import '../services/country_controller.dart';
import '../theme/app_theme.dart';
import '../theme/networks.dart';
import 'edit_transaction_sheet.dart';

/// Journal complet : toutes les opérations enregistrées par l'agent, du
/// plus récent au plus ancien, groupées par jour pour la lisibilité. Les
/// totaux et les cumuls sont dans l'onglet Synthèse, et les rapports
/// mensuels exportables dans l'onglet Archive — cet écran ne fait que
/// lister, et permet de modifier une opération en tapant dessus.
class HistoriqueScreen extends StatefulWidget {
  final LanguageController languageController;
  final CountryController countryController;
  const HistoriqueScreen({super.key, required this.languageController, required this.countryController});

  @override
  State<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends State<HistoriqueScreen> {
  final _db = DatabaseService.instance;
  List<MomoTransaction> _all = [];
  bool _loading = true;
  // 'tous', 'depot', 'retrait'
  String _filter = 'tous';

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
    final txs = await _db.getTransactions();
    if (!mounted) return;
    setState(() {
      _all = txs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    // Appliquer le filtre sélectionné
    final filtered = _filter == 'tous'
        ? _all
        : _all.where((tx) => tx.type == _filter).toList();

    final sorted = [...filtered]..sort((a, b) => b.date.compareTo(a.date));

    // Groupé par jour (du plus récent au plus ancien) — comme un journal
    // de caisse journalier, avec un mini-récap par journée en entête.
    final byDay = <String, List<MomoTransaction>>{};
    for (final tx in sorted) {
      final key =
          '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}';
      byDay.putIfAbsent(key, () => []).add(tx);
    }
    final dayKeys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(t('historique', _lang),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 14),
          // Onglets de filtre
          Row(
            children: [
              _filterChip('tous',    _lang == 'fr' ? 'Tous' : 'All'),
              const SizedBox(width: 8),
              _filterChip('depot',   _lang == 'fr' ? 'Dépôts' : 'Deposits'),
              const SizedBox(width: 8),
              _filterChip('retrait', _lang == 'fr' ? 'Retraits' : 'Withdrawals'),
            ],
          ),
          const SizedBox(height: 16),
          if (dayKeys.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  t('historique_vide', _lang),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkMuted, fontSize: 13.5),
                ),
              ),
            )
          else
            for (final key in dayKeys) ...[
              _dayHeader(key, byDay[key]!),
              const SizedBox(height: 8),
              ...byDay[key]!.map((tx) => _txRow(tx)),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }

  /// Puce de filtre cliquable en haut de l'écran.
  Widget _filterChip(String value, String label) {
    final active = _filter == value;
    Color activeColor;
    if (value == 'depot') {
      activeColor = AppColors.green;
    } else if (value == 'retrait') {
      activeColor = AppColors.orange;
    } else {
      activeColor = AppColors.ink;
    }

    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor : AppColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active ? activeColor : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }

  Widget _dayHeader(String key, List<MomoTransaction> txs) {
    final parts = key.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday = date.year == now.year && date.month == now.month && date.day == now.day - 1;

    String label;
    if (isToday) {
      label = t('aujourdhui', _lang).toUpperCase();
    } else if (isYesterday) {
      label = _lang == 'fr' ? 'HIER' : 'YESTERDAY';
    } else {
      label = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date).toUpperCase();
    }

    // Mini-récap de la journée
    final depots = txs.where((tx) => tx.type == 'depot');
    final retraits = txs.where((tx) => tx.type == 'retrait');
    final commission = txs.fold<int>(0, (a, tx) => a + tx.commission);
    final depotCount = depots.length;
    final retraitCount = retraits.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted, fontWeight: FontWeight.w700)),
          ),
          if (depotCount > 0)
            _miniChip('↓$depotCount', AppColors.green),
          if (retraitCount > 0) ...[
            const SizedBox(width: 4),
            _miniChip('↑$retraitCount', AppColors.orange),
          ],
          const SizedBox(width: 6),
          Text('+${fmtF(commission)}',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.green)),
        ],
      ),
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
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
          '${tx.operationNumber}${tx.clientName != null && tx.clientName!.isNotEmpty ? " (${tx.clientName})" : ""} · ${DateFormat('dd/MM/yyyy HH:mm').format(tx.date)}',
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
