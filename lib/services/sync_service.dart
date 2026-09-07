import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/momo_transaction.dart';
import '../models/tranche.dart';
import 'database_service.dart';

/// Sauvegarde les transactions et les grilles de commission vers Supabase,
/// et les restaure automatiquement après une réinstallation.
///
/// Toutes les opérations réseau sont "best effort" : si aucune connexion
/// n'est disponible, elles échouent silencieusement sans jamais bloquer
/// l'agent — les données restent utilisables en local dans tous les cas,
/// et la synchronisation reprendra la prochaine fois qu'une connexion sera
/// disponible (au prochain enregistrement, ou au prochain lancement).
class SyncService {
  final _client = Supabase.instance.client;

  String? get _agentId => _client.auth.currentUser?.id;

  // ---------------- Transactions ----------------

  Future<void> pushTransaction(MomoTransaction tx) async {
    final agentId = _agentId;
    if (agentId == null) return;
    try {
      await _client.from('transactions').upsert({
        ...tx.toMap(),
        'agent_id': agentId,
        'date': tx.date.toUtc().toIso8601String(),
      });
    } catch (_) {
      // Pas de connexion ou erreur réseau : on continue sans bloquer,
      // la donnée reste en sécurité en local.
    }
  }

  Future<void> deleteRemoteTransaction(String id) async {
    if (_agentId == null) return;
    try {
      await _client.from('transactions').delete().eq('id', id);
    } catch (_) {}
  }

  // ---------------- Tranches (grilles de commission) ----------------

  Future<void> pushTranche(Tranche tranche) async {
    final agentId = _agentId;
    if (agentId == null) return;
    try {
      await _client.from('tranches').upsert({
        ...tranche.toMap(),
        'agent_id': agentId,
      });
    } catch (_) {}
  }

  Future<void> deleteRemoteTranche(String id) async {
    if (_agentId == null) return;
    try {
      await _client.from('tranches').delete().eq('id', id);
    } catch (_) {}
  }

  // ---------------- Restauration (après réinstallation) ----------------

  /// Va chercher tout ce qui est sauvegardé sur Supabase pour l'agent
  /// connecté et le rapatrie dans la base locale — utile juste après une
  /// réinstallation de l'app, quand la base locale est vide mais que des
  /// données existent déjà côté serveur.
  Future<void> pullAndMergeAll(DatabaseService db) async {
    final agentId = _agentId;
    if (agentId == null) return;

    try {
      final remoteTx = await _client.from('transactions').select().eq('agent_id', agentId);
      final rawDb = await db.database;
      for (final row in remoteTx) {
        await rawDb.insert(
          'transactions',
          {
            'id': row['id'],
            'network': row['network'],
            'type': row['type'],
            'operation_number': row['operation_number'],
            'montant': row['montant'],
            'commission': row['commission'],
            'date': row['date'],
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      final remoteTranches = await _client.from('tranches').select().eq('agent_id', agentId);
      for (final row in remoteTranches) {
        await rawDb.insert(
          'tranches',
          {
            'id': row['id'],
            'network': row['network'],
            'type': row['type'],
            'min_amount': row['min_amount'],
            'max_amount': row['max_amount'],
            'commission': row['commission'],
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    } catch (_) {
      // Pas de connexion au premier lancement : l'agent peut quand même
      // utiliser l'app hors ligne, la restauration se fera plus tard.
    }
  }
}
