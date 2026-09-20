import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/momo_transaction.dart';

enum AgentSubStatus { essai, actif, expire, inconnu }

/// Une ligne du tableau de bord : un agent, son pays, son abonnement et
/// le total de ses opérations — reconstitué à partir de trois tables
/// Supabase (`agents`, `subscriptions`, `transactions`).
class AgentSummary {
  final String id;
  final String phoneNumber;
  final String? country;
  final String role;
  final AgentSubStatus subStatus;
  final DateTime? renewalDate;
  final int daysLeft;
  final int transactionCount;
  final int totalMontant;
  final int totalCommission;

  AgentSummary({
    required this.id,
    required this.phoneNumber,
    required this.country,
    required this.role,
    required this.subStatus,
    required this.renewalDate,
    required this.daysLeft,
    required this.transactionCount,
    required this.totalMontant,
    required this.totalCommission,
  });
}

/// Un avis/note laissé par un agent, avec ses informations de profil.
class AgentFeedback {
  final String id;
  final String agentId;
  final String phoneNumber;
  final String? country;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  AgentFeedback({
    required this.id,
    required this.agentId,
    required this.phoneNumber,
    required this.country,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });
}

/// Réservé à un compte marqué `role = 'admin'` côté Supabase (voir
/// AuthService.isCurrentUserAdmin). Les policies RLS sur `agents`,
/// `subscriptions` et `transactions` doivent autoriser un admin à lire
/// toutes les lignes (pas seulement les siennes) pour que ce service
/// fonctionne — voir la migration SQL fournie séparément.
class AdminDashboardService {
  final _client = Supabase.instance.client;

  static const int _trialDays = 7; // doit être identique à SubscriptionService.trialDays

  AgentSubStatus _statusFromRow(Map<String, dynamic>? sub) {
    if (sub == null) return AgentSubStatus.inconnu;
    final now = DateTime.now();

    final paidUntilStr = sub['paid_until'] as String?;
    if (paidUntilStr != null) {
      final paidUntil = DateTime.parse(paidUntilStr).toLocal();
      if (paidUntil.isAfter(now)) return AgentSubStatus.actif;
    }

    final trialStartStr = sub['trial_start'] as String?;
    if (trialStartStr != null) {
      final trialStart = DateTime.parse(trialStartStr).toLocal();
      final daysElapsed = now.difference(trialStart).inHours / 24;
      if (daysElapsed <= _trialDays) return AgentSubStatus.essai;
    }

    return AgentSubStatus.expire;
  }

  /// Calcule le nombre de jours restants pour un agent donné.
  int _daysLeftFromRow(Map<String, dynamic>? sub) {
    if (sub == null) return 0;
    final now = DateTime.now();

    final paidUntilStr = sub['paid_until'] as String?;
    if (paidUntilStr != null) {
      final paidUntil = DateTime.parse(paidUntilStr).toLocal();
      if (paidUntil.isAfter(now)) {
        return paidUntil.difference(now).inDays + 1;
      }
    }

    final trialStartStr = sub['trial_start'] as String?;
    if (trialStartStr != null) {
      final trialStart = DateTime.parse(trialStartStr).toLocal();
      final daysElapsed = now.difference(trialStart).inHours / 24;
      if (daysElapsed <= _trialDays) {
        return (_trialDays - daysElapsed).ceil().clamp(0, _trialDays);
      }
    }

    return 0;
  }

  DateTime? _renewalFromRow(Map<String, dynamic>? sub) {
    final paidUntilStr = sub?['paid_until'] as String?;
    if (paidUntilStr == null) return null;
    return DateTime.parse(paidUntilStr).toLocal();
  }

  /// Récupère tous les agents avec leur pays, leur statut d'abonnement et
  /// le cumul de leurs opérations (dépôts + retraits confondus). Trié du
  /// plus gros contributeur de commission au plus petit.
  Future<List<AgentSummary>> fetchAgentSummaries() async {
    final agentsRows = await _client.from('agents').select('id, phone_number, country, role').timeout(const Duration(seconds: 10));
    final subsRows = await _client.from('subscriptions').select('agent_id, trial_start, paid_until').timeout(const Duration(seconds: 10));
    final txRows = await _client.from('transactions').select('agent_id, montant, commission').timeout(const Duration(seconds: 10));

    final subsByAgent = <String, Map<String, dynamic>>{
      for (final row in subsRows) row['agent_id'] as String: row,
    };

    final txCountByAgent = <String, int>{};
    final txMontantByAgent = <String, int>{};
    final txCommissionByAgent = <String, int>{};
    for (final row in txRows) {
      final agentId = row['agent_id'] as String;
      txCountByAgent[agentId] = (txCountByAgent[agentId] ?? 0) + 1;
      txMontantByAgent[agentId] = (txMontantByAgent[agentId] ?? 0) + (row['montant'] as int);
      txCommissionByAgent[agentId] = (txCommissionByAgent[agentId] ?? 0) + (row['commission'] as int);
    }

    final summaries = agentsRows.map<AgentSummary>((row) {
      final id = row['id'] as String;
      final sub = subsByAgent[id];
      return AgentSummary(
        id: id,
        phoneNumber: row['phone_number'] as String? ?? '—',
        country: row['country'] as String?,
        role: row['role'] as String? ?? 'agent',
        subStatus: _statusFromRow(sub),
        renewalDate: _renewalFromRow(sub),
        daysLeft: _daysLeftFromRow(sub),
        transactionCount: txCountByAgent[id] ?? 0,
        totalMontant: txMontantByAgent[id] ?? 0,
        totalCommission: txCommissionByAgent[id] ?? 0,
      );
    }).toList();

    summaries.sort((a, b) => b.totalCommission.compareTo(a.totalCommission));
    return summaries;
  }

  /// Toutes les opérations d'un agent donné, les plus récentes en premier
  /// — utilisé par l'écran de détail agent du tableau de bord.
  Future<List<MomoTransaction>> fetchAgentTransactions(String agentId) async {
    final rows = await _client
        .from('transactions')
        .select()
        .eq('agent_id', agentId)
        .order('date', ascending: false)
        .timeout(const Duration(seconds: 10));
    return rows.map<MomoTransaction>((row) => MomoTransaction.fromMap(row)).toList();
  }

  /// Prolonge exceptionnellement l'abonnement d'un agent de [days] jours
  /// depuis le tableau de bord — pour débloquer un cas particulier (souci
  /// de paiement FedaPay, geste commercial, etc.) sans passer par un
  /// nouveau paiement. Le paiement normal reste entièrement géré par
  /// FedaPay (voir SubscriptionService.startFedaPayCheckout) ; ceci est
  /// une exception, pas un mode d'activation parallèle.
  ///
  /// Part de la date de fin d'abonnement actuelle si elle est encore
  /// valide (pour ne pas faire perdre de jours déjà payés), sinon
  /// d'aujourd'hui.
  Future<DateTime> extendSubscription(String agentId, int days) async {
    final now = DateTime.now();
    final row = await _client
        .from('subscriptions')
        .select('paid_until, trial_start')
        .eq('agent_id', agentId)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));

    var base = now;
    final paidUntilStr = row?['paid_until'] as String?;
    if (paidUntilStr != null) {
      final paidUntil = DateTime.parse(paidUntilStr).toLocal();
      if (paidUntil.isAfter(now)) base = paidUntil;
    }
    final next = base.add(Duration(days: days));

    // Utilisation de upsert au cas où la ligne n'existerait pas (ex: admin créé manuellement)
    await _client.from('subscriptions').upsert({
      'agent_id': agentId,
      'trial_start': row?['trial_start'] ?? now.toUtc().toIso8601String(),
      'paid_until': next.toUtc().toIso8601String(),
      'updated_at': now.toUtc().toIso8601String(),
    }).timeout(const Duration(seconds: 10));

    return next;
  }

  /// Supprime complètement un agent : subscriptions, transactions, feedback
  /// et la ligne agents. Le compte Supabase Auth reste (seul un service_role
  /// peut le supprimer) mais l'agent ne pourra plus se connecter car sa ligne
  /// dans `agents` n'existera plus.
  Future<void> deleteAgent(String agentId) async {
    await _client.from('subscriptions').delete().eq('agent_id', agentId).timeout(const Duration(seconds: 10));
    await _client.from('transactions').delete().eq('agent_id', agentId).timeout(const Duration(seconds: 10));
    await _client.from('tranches').delete().eq('agent_id', agentId).timeout(const Duration(seconds: 10));
    await _client.from('feedback').delete().eq('agent_id', agentId).timeout(const Duration(seconds: 10));
    await _client.from('agents').delete().eq('id', agentId).timeout(const Duration(seconds: 10));
  }

  /// Supprime un avis/commentaire individuel.
  Future<void> deleteFeedback(String feedbackId) async {
    await _client.from('feedback').delete().eq('id', feedbackId).timeout(const Duration(seconds: 10));
  }

  /// Récupère tous les avis / notes laissés par les agents, triés du plus
  /// récent au plus ancien.
  Future<List<AgentFeedback>> fetchFeedbacks() async {
    final feedbackRows = await _client
        .from('feedback')
        .select('id, agent_id, rating, comment, created_at')
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 10));

    final agentsRows = await _client.from('agents').select('id, phone_number, country').timeout(const Duration(seconds: 10));
    final agentsMap = <String, Map<String, dynamic>>{
      for (final row in agentsRows) row['id'] as String: row,
    };

    return feedbackRows.map<AgentFeedback>((row) {
      final agentId = row['agent_id'] as String;
      final agent = agentsMap[agentId];
      return AgentFeedback(
        id: row['id'] as String,
        agentId: agentId,
        phoneNumber: agent?['phone_number'] as String? ?? '—',
        country: agent?['country'] as String?,
        rating: (row['rating'] as num).toInt(),
        comment: row['comment'] as String?,
        createdAt: row['created_at'] != null
            ? DateTime.parse(row['created_at'] as String).toLocal()
            : DateTime.now(),
      );
    }).toList();
  }
}
