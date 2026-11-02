import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/tranche.dart';
import '../services/country_controller.dart';
import '../services/database_service.dart';
import '../services/feedback_service.dart';
import '../services/subscription_service.dart';
import '../services/sync_service.dart';
import '../services/translations.dart';
import '../theme/app_theme.dart';
import '../theme/countries.dart';
import '../theme/networks.dart';
import '../services/auth_service.dart';
import '../services/owner_service.dart';
import 'abonnement_screen.dart';
import 'owner_dashboard_screen.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ReglagesScreen extends StatefulWidget {
  final LanguageController languageController;
  final CountryController countryController;
  final SubscriptionStatus status;
  final VoidCallback onStatusChanged;
  const ReglagesScreen({
    super.key,
    required this.languageController,
    required this.countryController,
    required this.status,
    required this.onStatusChanged,
  });

  @override
  State<ReglagesScreen> createState() => _ReglagesScreenState();
}

class _ReglagesScreenState extends State<ReglagesScreen> {
  final _db = DatabaseService.instance;
  late String _network;
  String _type = 'depot';
  List<Tranche> _tranches = [];
  bool _loading = true;

  String get _lang => widget.languageController.value;

  @override
  void initState() {
    super.initState();
    _network = networksForCountry(widget.countryController.value).first['id'] as String;
    widget.languageController.addListener(_onLanguageChanged);
    widget.countryController.addListener(_onCountryChanged);
    _load();
  }

  void _onLanguageChanged() => setState(() {});

  void _onCountryChanged() {
    setState(() => _network = networksForCountry(widget.countryController.value).first['id'] as String);
    _load();
  }

  @override
  void dispose() {
    widget.languageController.removeListener(_onLanguageChanged);
    widget.countryController.removeListener(_onCountryChanged);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tranches = await _db.getTranches(_network, _type);
    if (!mounted) return;
    setState(() {
      _tranches = tranches;
      _loading = false;
    });
  }

  Future<void> _addTranche() async {
    final lastMax = _tranches.isNotEmpty ? _tranches.last.max : -1;
    final tranche = Tranche(
      id: const Uuid().v4(),
      network: _network,
      type: _type,
      min: lastMax + 1,
      max: lastMax + 1001,
      commission: 0,
    );
    await _db.upsertTranche(tranche);
    unawaited(SyncService().pushTranche(tranche));
    _load();
  }

  Future<void> _updateTranche(Tranche updated) async {
    await _db.upsertTranche(updated);
    unawaited(SyncService().pushTranche(updated));
    setState(() {
      final idx = _tranches.indexWhere((x) => x.id == updated.id);
      if (idx != -1) _tranches[idx] = updated;
    });
  }

  Future<void> _removeTranche(String id) async {
    await _db.deleteTranche(id);
    unawaited(SyncService().deleteRemoteTranche(id));
    _load();
  }

  Future<void> _openAbonnement() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AbonnementScreen(
        status: widget.status,
        onStatusChanged: widget.onStatusChanged,
        languageController: widget.languageController,
      ),
    ));
    // Le statut peut avoir changé (paiement FedaPay effectué pendant que
    // l'agent était sur l'écran Abonnement) ; on rafraîchit au retour.
    widget.onStatusChanged();
  }

  Widget _abonnementCard() {
    final s = widget.status;
    late String badge;
    late Color badgeColor;
    late String line;

    final jourWord = s.daysLeft > 1 ? t('jour_restant_pl', _lang) : t('jour_restant_sg', _lang);
    switch (s.state) {
      case SubscriptionState.essai:
        badge = t('essai_gratuit', _lang);
        badgeColor = AppColors.inkMuted;
        line = '${s.daysLeft} $jourWord';
        break;
      case SubscriptionState.actif:
        badge = t('abonnement_actif_badge', _lang);
        badgeColor = AppColors.green;
        line = s.renewalDate != null
            ? '${t('renouvellement_1', _lang)}${DateFormat('dd/MM/yyyy').format(s.renewalDate!)}.'
            : '${s.daysLeft} $jourWord';
        break;
      case SubscriptionState.expire:
        badge = t('essai_termine_badge', _lang);
        badgeColor = AppColors.orange;
        line = t('active_pour_continuer', _lang);
        break;
    }

    return Card(
      child: InkWell(
        onTap: _openAbonnement,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(20)),
                child: Text(badge,
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(line, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
              ),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ownerSpaceCard() {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => OwnerDashboardScreen(
              languageController: widget.languageController,
              countryController: widget.countryController,
            ),
          ));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront, color: AppColors.green, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('espace_proprietaire', _lang),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t('espace_proprietaire_desc', _lang),
                      style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _agentOwnerCodeCard() {
    return Card(
      child: InkWell(
        onTap: _showOwnerCodeDialog,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.vpn_key_outlined, color: AppColors.green, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('code_acces_patron', _lang),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t('code_patron_desc', _lang),
                      style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showOwnerCodeDialog() async {
    String? code;
    bool loading = true;
    final ownerService = OwnerService();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            if (loading) {
              ownerService.getOrGenerateOwnerCode().then((c) {
                if (ctx.mounted) {
                  setDialogState(() {
                    code = c;
                    loading = false;
                  });
                }
              }).catchError((_) {
                if (ctx.mounted) {
                  setDialogState(() => loading = false);
                }
              });
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.vpn_key_outlined, color: AppColors.green),
                  const SizedBox(width: 8),
                  Text(t('code_acces_patron', _lang), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t('code_patron_desc', _lang),
                    style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  if (loading)
                    const CircularProgressIndicator()
                  else if (code != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.green, width: 1.5),
                      ),
                      child: Text(
                        code!,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 6, color: AppColors.green),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: code!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(t('code_copie', _lang)), backgroundColor: AppColors.green),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copier'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Share.share('${t('code_patron_partage_msg', _lang)} $code');
                          },
                          icon: const Icon(Icons.share, size: 16),
                          label: const Text('Partager'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _changePinCard() {
    return Card(
      child: InkWell(
        onTap: _showChangePinDialog,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline, color: AppColors.orange, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t('modifier_code_pin', _lang),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChangePinDialog() async {
    final oldPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    String? error;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(t('modifier_code_pin', _lang), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPinCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: InputDecoration(hintText: t('code_pin_actuel', _lang)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newPinCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: InputDecoration(hintText: t('nouveau_code_pin', _lang)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmPinCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: InputDecoration(hintText: t('confirmer_nouveau_pin', _lang)),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: AppColors.orange, fontSize: 13)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t('annuler', _lang), style: const TextStyle(color: AppColors.inkMuted)),
                ),
                ElevatedButton(
                  onPressed: saving ? null : () async {
                    setStateDialog(() { error = null; saving = true; });
                    try {
                      if (newPinCtrl.text != confirmPinCtrl.text) {
                        throw t('les_pins_ne_correspondent_pas', _lang);
                      }
                      if (newPinCtrl.text.length < 4) {
                        throw t('pin_min_4', _lang);
                      }
                      await AuthService().changePin(oldPinCtrl.text, newPinCtrl.text);
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t('pin_modifie_succes', _lang)), backgroundColor: AppColors.green),
                      );
                    } catch (e) {
                      setStateDialog(() { error = e.toString().replaceFirst('Exception: ', ''); });
                    } finally {
                      setStateDialog(() { saving = false; });
                    }
                  },
                  child: saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(t('changer', _lang)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final networks = networksForCountry(widget.countryController.value);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(t('reglages', _lang),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 14),
        Text(t('abonnement', _lang).toUpperCase(),
            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _abonnementCard(),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(t('grille_commission', _lang),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
            _NetworkPicker(
              value: _network,
              networks: networks,
              onChanged: (v) {
                setState(() => _network = v);
                _load();
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          t('grille_desc', _lang),
          style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),

        Container(
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _typeTab('depot', t('depot', _lang), Icons.arrow_downward, AppColors.green),
              _typeTab('retrait', t('retrait', _lang), Icons.arrow_upward, AppColors.orange),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          for (int i = 0; i < _tranches.length; i++)
            _TrancheCard(
              key: ValueKey(_tranches[i].id),
              tranche: _tranches[i],
              index: i,
              lang: _lang,
              onChanged: _updateTranche,
              onDelete: () => _removeTranche(_tranches[i].id),
            ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _addTranche,
            icon: const Icon(Icons.add),
            label: Text(t('ajouter_tranche', _lang)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 46),
              side: const BorderSide(color: AppColors.inkMuted, style: BorderStyle.solid),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],

        const SizedBox(height: 24),
        Text(t('ton_pays', _lang).toUpperCase(),
            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kCountries.map((c) => _countryChip(c)).toList(),
        ),

        const SizedBox(height: 24),
        Text(t('langue', _lang).toUpperCase(),
            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _langChip('fr', 'Français'),
                const SizedBox(width: 8),
                _langChip('en', 'English'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        Text(t('code_pin', _lang).toUpperCase(),
            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _changePinCard(),

        const SizedBox(height: 24),
        Text(t('espace_proprietaire', _lang).toUpperCase(),
            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _ownerSpaceCard(),
        const SizedBox(height: 10),
        _agentOwnerCodeCard(),

        const SizedBox(height: 24),
        Text(t('nous_contacter', _lang).toUpperCase(),
            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _SupportCard(lang: _lang),

        const SizedBox(height: 24),
        Text(t('donne_avis', _lang),
            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _FeedbackCard(lang: _lang),
      ],
    );
  }

  Widget _langChip(String code, String label) {
    final active = _lang == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.languageController.setLanguage(code),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.green : AppColors.background,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }

  Widget _countryChip(Map<String, dynamic> c) {
    final active = widget.countryController.value == c['id'];
    return GestureDetector(
      onTap: () => widget.countryController.setCountry(c['id']!),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.green : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.green : AppColors.border),
        ),
        child: Text(
          '${c['flag']} ${c['name']}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }

  Widget _typeTab(String value, String label, IconData icon, Color activeColor) {
    final active = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _type = value);
          _load();
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
              Text(label, style: TextStyle(color: active ? Colors.white : AppColors.inkSoft, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte d'une tranche avec ses propres champs de texte persistants.
/// Important : les TextEditingController sont créés une seule fois dans
/// initState et vivent tant que la tranche existe (grâce à la ValueKey
/// posée sur ce widget dans la liste parente). Les recréer à chaque frappe
/// remettrait le curseur au début du champ et casserait la saisie.
class _TrancheCard extends StatefulWidget {
  final Tranche tranche;
  final int index;
  final String lang;
  final ValueChanged<Tranche> onChanged;
  final VoidCallback onDelete;

  const _TrancheCard({
    super.key,
    required this.tranche,
    required this.index,
    required this.lang,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_TrancheCard> createState() => _TrancheCardState();
}

class _TrancheCardState extends State<_TrancheCard> {
  late TextEditingController _minCtrl;
  late TextEditingController _maxCtrl;
  late TextEditingController _commissionCtrl;

  @override
  void initState() {
    super.initState();
    _minCtrl = TextEditingController(text: widget.tranche.min.toString());
    _maxCtrl = TextEditingController(text: widget.tranche.max.toString());
    _commissionCtrl = TextEditingController(text: widget.tranche.commission.toString());
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _commissionCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final min = int.tryParse(_minCtrl.text) ?? widget.tranche.min;
    final max = int.tryParse(_maxCtrl.text) ?? widget.tranche.max;
    final commission = int.tryParse(_commissionCtrl.text) ?? widget.tranche.commission;
    widget.onChanged(widget.tranche.copyWith(min: min, max: max, commission: commission));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TRANCHE ${widget.index + 1}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.orange, size: 20),
                  onPressed: widget.onDelete,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _field(t('minimum', widget.lang), _minCtrl)),
                const SizedBox(width: 10),
                Expanded(child: _field(t('maximum', widget.lang), _maxCtrl)),
              ],
            ),
            const SizedBox(height: 10),
            _field(t('commission_col', widget.lang), _commissionCtrl),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 10.5, color: AppColors.inkMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          onTap: () => controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length),
          onChanged: (_) => _emit(),
        ),
      ],
    );
  }
}

class _NetworkPicker extends StatelessWidget {
  final String value;
  final List<Map<String, dynamic>> networks;
  final ValueChanged<String> onChanged;
  const _NetworkPicker({required this.value, required this.networks, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final current = networks.firstWhere((n) => n['id'] == value, orElse: () => networks.first);
    return PopupMenuButton<String>(
      onSelected: onChanged,
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

/// Carte permettant à l'agent de laisser une note (étoiles) et un
/// commentaire libre sur l'app, envoyé directement à l'administrateur.
class _FeedbackCard extends StatefulWidget {
  final String lang;
  const _FeedbackCard({required this.lang});

  @override
  State<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<_FeedbackCard> {
  final _service = FeedbackService();
  final _commentCtrl = TextEditingController();
  int _rating = 0;
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = t('note_avant_envoi', widget.lang));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _service.submit(rating: _rating, comment: _commentCtrl.text);
      if (!mounted) return;
      setState(() => _sent = true);
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('failed host lookup') || errStr.contains('timeoutexception') || errStr.contains('connection reset')) {
        setState(() => _error = t('err_pas_internet', widget.lang));
      } else {
        setState(() => _error = "${t('erreur_prefix', widget.lang)}$e");
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.green, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(t('merci_avis', widget.lang), style: const TextStyle(fontSize: 13.5, color: AppColors.ink)),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('demande_avis', widget.lang),
              style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return IconButton(
                  onPressed: () => setState(() => _rating = i + 1),
                  icon: Icon(
                    filled ? Icons.star : Icons.star_border,
                    color: filled ? AppColors.mtn : AppColors.inkMuted,
                    size: 30,
                  ),
                );
              }),
            ),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: t('commentaire_optionnel', widget.lang),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(color: AppColors.orange, fontSize: 12.5)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sending ? null : _submit,
                child: Text(_sending ? t('envoi_en_cours', widget.lang) : t('envoyer_avis', widget.lang)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte permettant de contacter l'équipe via WhatsApp
class _SupportCard extends StatelessWidget {
  final String lang;
  const _SupportCard({required this.lang});

  Future<void> _openWhatsApp() async {
    // Remplacer par le numéro de téléphone de l'équipe support (avec l'indicatif)
    final phoneNumber = '2290153467177'; 
    final message = lang == 'fr' 
        ? 'Bonjour l\'équipe Carnet MoMo, j\'ai besoin d\'aide :'
        : 'Hello Carnet MoMo team, I need some help:';
    
    final url = Uri.parse('https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch WhatsApp: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: _openWhatsApp,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.support_agent, color: AppColors.green, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('contacter_support', lang),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t('contacter_support_desc', lang),
                      style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
