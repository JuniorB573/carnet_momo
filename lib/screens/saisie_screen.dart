import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/momo_transaction.dart';
import '../services/database_service.dart';
import '../services/formatters.dart';
import '../services/local_notification_service.dart';
import '../services/sync_service.dart';
import '../services/translations.dart';
import '../services/country_controller.dart';
import '../theme/app_theme.dart';
import '../theme/countries.dart';
import '../theme/networks.dart';
import 'home_shell.dart';

class SaisieScreen extends StatefulWidget {
  final NetworkController networkController;
  final LanguageController languageController;
  final CountryController countryController;
  const SaisieScreen({
    super.key,
    required this.networkController,
    required this.languageController,
    required this.countryController,
  });

  @override
  State<SaisieScreen> createState() => _SaisieScreenState();
}

class _SaisieScreenState extends State<SaisieScreen> {
  final _db = DatabaseService.instance;
  String _type = 'depot';
  final _operationNumberCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();
  int? _commission;
  String? _error;
  bool _checking = false;

  String get _lang => widget.languageController.value;

  List<Map<String, dynamic>> get _availableNetworks =>
      networksForCountry(widget.countryController.value);

  int _todayDepots = 0, _todayRetraits = 0;
  int _todayDepotCommission = 0, _todayRetraitCommission = 0;
  int _todayDepotsCount = 0, _todayRetraitsCount = 0;

  @override
  void initState() {
    super.initState();
    widget.networkController.addListener(_onNetworkChanged);
    widget.languageController.addListener(_onLanguageChanged);
    widget.countryController.addListener(_onCountryChanged);
    _refreshTodaySummary();
  }

  void _onLanguageChanged() => setState(() {});

  void _onCountryChanged() => setState(() {});

  @override
  void dispose() {
    widget.networkController.removeListener(_onNetworkChanged);
    widget.languageController.removeListener(_onLanguageChanged);
    widget.countryController.removeListener(_onCountryChanged);
    _operationNumberCtrl.dispose();
    _montantCtrl.dispose();
    super.dispose();
  }

  void _onNetworkChanged() {
    setState(() {});
    _refreshTodaySummary();
  }

  Future<void> _refreshTodaySummary() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final txs = await _db.getTransactions(
      network: widget.networkController.value,
      from: startOfDay,
    );
    int depots = 0, retraits = 0, depotComm = 0, retraitComm = 0, depotsCount = 0, retraitsCount = 0;
    for (final t in txs) {
      if (t.type == 'depot') {
        depots += t.montant;
        depotComm += t.commission;
        depotsCount++;
      } else {
        retraits += t.montant;
        retraitComm += t.commission;
        retraitsCount++;
      }
    }
    if (!mounted) return;
    setState(() {
      _todayDepots = depots;
      _todayRetraits = retraits;
      _todayDepotCommission = depotComm;
      _todayRetraitCommission = retraitComm;
      _todayDepotsCount = depotsCount;
      _todayRetraitsCount = retraitsCount;
    });
  }

  Future<void> _onMontantChanged(String value) async {
    final montant = int.tryParse(value);
    if (montant == null || montant <= 0) {
      setState(() => _commission = null);
      return;
    }
    setState(() => _checking = true);
    final commission = await _db.findCommission(
      widget.networkController.value,
      _type,
      montant,
    );
    if (!mounted) return;
    setState(() {
      _commission = commission;
      _checking = false;
    });
  }

  Future<void> _save() async {
    final montant = int.tryParse(_montantCtrl.text);
    final opNumber = _operationNumberCtrl.text.trim();

    final opError = validateOperationNumberForCountry(
      opNumber,
      widget.countryController.value,
      lang: _lang,
    );
    if (opError != null) {
      setState(() => _error = opError);
      return;
    }
    if (montant == null || montant <= 0) {
      setState(() => _error = t('indique_montant_valide', _lang));
      return;
    }
    if (_commission == null) {
      setState(() => _error = t('aucune_tranche_reglages', _lang));
      return;
    }

    final tx = MomoTransaction(
      id: const Uuid().v4(),
      network: widget.networkController.value,
      type: _type,
      operationNumber: _operationNumberCtrl.text.trim(),
      montant: montant,
      commission: _commission!,
      date: DateTime.now(),
    );
    await _db.insertTransaction(tx);
    unawaited(SyncService().pushTransaction(tx));
    unawaited(LocalNotificationService.showTransactionNotification(
      title: tx.type == 'depot' ? 'Dépôt enregistré' : 'Retrait enregistré',
      body: '${fmtF(tx.montant)} · Commission ${fmtF(tx.commission)}',
    ));

    _operationNumberCtrl.clear();
    _montantCtrl.clear();
    setState(() {
      _commission = null;
      _error = null;
    });
    _refreshTodaySummary();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${tx.type == "depot" ? "Dépôt" : "Retrait"} enregistré · commission ${fmtF(tx.commission)}',
        ),
        backgroundColor: AppColors.ink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t('nouvelle_operation', _lang),
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              _NetworkPicker(controller: widget.networkController, networks: _availableNetworks),
            ],
          ),
          const SizedBox(height: 14),

          // Type d'opération : dépôt / retrait
          Container(
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _typeButton('depot', t('depot', _lang), Icons.arrow_downward, AppColors.green),
                _typeButton('retrait', t('retrait', _lang), Icons.arrow_upward, AppColors.orange),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('numero_operation', _lang).toUpperCase(),
                      style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600)),
                  TextField(
                    controller: _operationNumberCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: (countryById(widget.countryController.value)['placeholder'] as String?) ?? t('numero_operation', _lang),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(t('montant', _lang).toUpperCase(),
                      style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600)),
                  TextField(
                    controller: _montantCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: _onMontantChanged,
                    decoration: const InputDecoration(hintText: '0'),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t('commission_calculee', _lang), style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
                        Text(
                          _checking
                              ? '…'
                              : (_montantCtrl.text.isEmpty
                                  ? '—'
                                  : (_commission != null ? fmtF(_commission!) : 'Hors grille')),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _commission != null ? AppColors.green : AppColors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.orange, fontSize: 13)),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _save, child: Text(t('enregistrer', _lang))),
          ),

          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('aujourdhui', _lang).toUpperCase(),
                      style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, fontWeight: FontWeight.w700)),
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
                  _summaryRow('${t('depot', _lang)} ($_todayDepotsCount)', _todayDepots, _todayDepotCommission, AppColors.green),
                  const SizedBox(height: 8),
                  _summaryRow('${t('retrait', _lang)} ($_todayRetraitsCount)', _todayRetraits, _todayRetraitCommission, AppColors.orange),
                  const Divider(height: 18),
                  _summaryRow('TOTAL', _todayDepots + _todayRetraits, _todayDepotCommission + _todayRetraitCommission, AppColors.ink, bold: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeButton(String value, String label, IconData icon, Color activeColor) {
    final active = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _type = value);
          _onMontantChanged(_montantCtrl.text);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? Colors.white : AppColors.inkSoft),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
}

class _NetworkPicker extends StatelessWidget {
  final NetworkController controller;
  final List<Map<String, dynamic>> networks;
  const _NetworkPicker({required this.controller, required this.networks});

  @override
  Widget build(BuildContext context) {
    final current = networks.firstWhere((n) => n['id'] == controller.value, orElse: () => networks.first);
    return PopupMenuButton<String>(
      onSelected: (v) => controller.value = v,
      itemBuilder: (context) => networks
          .map((n) => PopupMenuItem<String>(
                value: n['id'] as String,
                child: Row(
                  children: [
                    Container(width: 10, height: 10, color: n['color'] as Color),
                    const SizedBox(width: 8),
                    Text(n['label'] as String),
                  ],
                ),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: current['color'] as Color, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Text(current['label'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}
