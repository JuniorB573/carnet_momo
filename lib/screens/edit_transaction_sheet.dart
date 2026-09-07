import 'dart:async';
import 'package:flutter/material.dart';

import '../models/momo_transaction.dart';
import '../services/database_service.dart';
import '../services/formatters.dart';
import '../services/sync_service.dart';
import '../services/translations.dart';
import '../theme/app_theme.dart';
import '../theme/networks.dart';

/// Ouvre un panneau permettant de corriger une opération mal saisie
/// (mauvais montant, mauvais type, mauvais numéro...) ou de la supprimer
/// si elle a été enregistrée par erreur. Retourne true si un changement a
/// été effectué (pour que l'écran appelant recharge sa liste).
Future<bool?> showEditTransactionSheet(BuildContext context, MomoTransaction tx, String lang, String country) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (context) => _EditTransactionSheet(tx: tx, lang: lang, country: country),
  );
}

class _EditTransactionSheet extends StatefulWidget {
  final MomoTransaction tx;
  final String lang;
  final String country;
  const _EditTransactionSheet({required this.tx, required this.lang, required this.country});

  @override
  State<_EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<_EditTransactionSheet> {
  final _db = DatabaseService.instance;
  late String _type;
  late String _network;
  late TextEditingController _operationNumberCtrl;
  late TextEditingController _montantCtrl;
  int? _commission;
  String? _error;
  bool _saving = false;

  String get _lang => widget.lang;

  @override
  void initState() {
    super.initState();
    _type = widget.tx.type;
    _network = widget.tx.network;
    _operationNumberCtrl = TextEditingController(text: widget.tx.operationNumber);
    _montantCtrl = TextEditingController(text: widget.tx.montant.toString());
    _commission = widget.tx.commission;
  }

  @override
  void dispose() {
    _operationNumberCtrl.dispose();
    _montantCtrl.dispose();
    super.dispose();
  }

  Future<void> _recomputeCommission() async {
    final montant = int.tryParse(_montantCtrl.text);
    if (montant == null || montant <= 0) {
      setState(() => _commission = null);
      return;
    }
    final commission = await _db.findCommission(_network, _type, montant);
    if (!mounted) return;
    setState(() => _commission = commission);
  }

  Future<void> _save() async {
    final montant = int.tryParse(_montantCtrl.text);
    if (_operationNumberCtrl.text.trim().isEmpty) {
      setState(() => _error = t('indique_numero_op', _lang));
      return;
    }
    if (montant == null || montant <= 0) {
      setState(() => _error = t('indique_montant_valide', _lang));
      return;
    }
    if (_commission == null) {
      setState(() => _error = t('aucune_tranche', _lang));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final updated = MomoTransaction(
      id: widget.tx.id,
      network: _network,
      type: _type,
      operationNumber: _operationNumberCtrl.text.trim(),
      montant: montant,
      commission: _commission!,
      date: widget.tx.date,
    );
    await _db.updateTransaction(updated);
    unawaited(SyncService().pushTransaction(updated));

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('supprimer_op_titre', _lang)),
        content: Text(t('supprimer_op_texte', _lang)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('annuler', _lang))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('supprimer', _lang), style: const TextStyle(color: AppColors.orange)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.deleteTransaction(widget.tx.id);
      unawaited(SyncService().deleteRemoteTransaction(widget.tx.id));
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t('corriger_operation', _lang),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.orange),
                  onPressed: _confirmDelete,
                  tooltip: t('supprimer', _lang),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Text(t('reseau', _lang), style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: networksForCountry(widget.country).map((n) {
                final active = _network == n['id'];
                return ChoiceChip(
                  label: Text(n['label'] as String),
                  selected: active,
                  onSelected: (_) {
                    setState(() => _network = n['id'] as String);
                    _recomputeCommission();
                  },
                  selectedColor: n['color'] as Color,
                  labelStyle: TextStyle(color: active ? Colors.white : AppColors.inkSoft, fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            Text(t('type_col', _lang), style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text(t('depot', _lang)),
                    selected: _type == 'depot',
                    onSelected: (_) {
                      setState(() => _type = 'depot');
                      _recomputeCommission();
                    },
                    selectedColor: AppColors.green,
                    labelStyle: TextStyle(
                        color: _type == 'depot' ? Colors.white : AppColors.inkSoft, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Text(t('retrait', _lang)),
                    selected: _type == 'retrait',
                    onSelected: (_) {
                      setState(() => _type = 'retrait');
                      _recomputeCommission();
                    },
                    selectedColor: AppColors.orange,
                    labelStyle: TextStyle(
                        color: _type == 'retrait' ? Colors.white : AppColors.inkSoft, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Text(t('numero_operation', _lang).toUpperCase(),
                style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600)),
            TextField(controller: _operationNumberCtrl),
            const SizedBox(height: 14),

            Text(t('montant_fcfa', _lang).toUpperCase(), style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600)),
            TextField(
              controller: _montantCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => _recomputeCommission(),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t('nouvelle_commission', _lang), style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
                  Text(
                    _commission != null ? fmtF(_commission!) : t('hors_grille', _lang),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _commission != null ? AppColors.green : AppColors.orange,
                    ),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.orange, fontSize: 13)),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? t('enregistrement', _lang) : t('enregistrer_correction', _lang)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
