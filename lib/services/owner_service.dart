import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/momo_transaction.dart';
import 'database_service.dart';

/// Modèle pour un kiosque/agent lié par le patron
class LinkedKiosk {
  final String id;
  final String agentId;
  final String agentPhone;
  final String customName;
  final DateTime addedAt;

  LinkedKiosk({
    required this.id,
    required this.agentId,
    required this.agentPhone,
    required this.customName,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'agent_id': agentId,
        'agent_phone': agentPhone,
        'custom_name': customName,
        'added_at': addedAt.toIso8601String(),
      };

  factory LinkedKiosk.fromMap(Map<String, dynamic> map) => LinkedKiosk(
        id: map['id'] as String,
        agentId: map['agent_id'] as String,
        agentPhone: map['agent_phone'] as String,
        customName: map['custom_name'] as String,
        addedAt: DateTime.parse(map['added_at'] as String),
      );
}

/// Service gérant les codes d'accès patron et le tableau de bord propriétaire
class OwnerService {
  final _client = Supabase.instance.client;
  static const _kioskPrefKey = 'owner_linked_kiosks_v1';

  // -------------------------------------------------------------
  // 1. Côté Agent : Génération et gestion du code patron
  // -------------------------------------------------------------
  // 1. Côté Agent : Génération et gestion du code patron
  // -------------------------------------------------------------

  /// Récupère ou génère un code d'accès patron à 6 chiffres
  Future<String> getOrGenerateOwnerCode() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _client.auth.currentUser;

    // Récupérer le code local existant
    String? code = prefs.getString('local_owner_code');

    if (user != null) {
      try {
        final res = await _client
            .from('agents')
            .select('owner_code')
            .eq('id', user.id)
            .maybeSingle();

        if (res != null && res['owner_code'] != null && (res['owner_code'] as String).isNotEmpty) {
          code = (res['owner_code'] as String).trim();
          await prefs.setString('local_owner_code', code);
          return code;
        }
      } catch (e) {
        debugPrint('[OwnerService] Colonne owner_code peut-être non créée dans Supabase: $e');
      }
    }

    if (code == null || code.isEmpty) {
      // Générer un code 6 chiffres
      code = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
      await prefs.setString('local_owner_code', code);
    }

    // Tenter la mise à jour dans Supabase (table agents)
    if (user != null) {
      try {
        await _client
            .from('agents')
            .update({'owner_code': code})
            .eq('id', user.id);
      } catch (e) {
        debugPrint('[OwnerService] Erreur maj code dans agents: $e');
      }

      // Sauvegarde dans les metadata de l'utilisateur pour sécurité supplémentaire
      try {
        await _client.auth.updateUser(UserAttributes(data: {'owner_code': code}));
      } catch (_) {}
    }

    return code;
  }

  /// Force la régénération d'un NOUVEAU code à 6 chiffres (remplace et invalide l'ancien)
  Future<String> regenerateOwnerCode() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _client.auth.currentUser;

    final newCode = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    await prefs.setString('local_owner_code', newCode);

    if (user != null) {
      try {
        await _client
            .from('agents')
            .update({'owner_code': newCode})
            .eq('id', user.id);
      } catch (e) {
        debugPrint('[OwnerService] Erreur maj nouveau code dans agents: $e');
      }

      try {
        await _client.auth.updateUser(UserAttributes(data: {'owner_code': newCode}));
      } catch (_) {}
    }

    return newCode;
  }

  // -------------------------------------------------------------
  // 2. Côté Patron : Liaison des kiosques
  // -------------------------------------------------------------

  Future<List<LinkedKiosk>> getLinkedKiosks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kioskPrefKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((item) => LinkedKiosk.fromMap(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveLinkedKiosks(List<LinkedKiosk> kiosks) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(kiosks.map((k) => k.toMap()).toList());
    await prefs.setString(_kioskPrefKey, raw);
  }

  /// Associe un agent avec son numéro, son code et un nom choisi par le patron.
  /// Gère toutes les variantes de numéro (avec ou sans indicatif +229, 01, 8/10 chiffres).
  Future<LinkedKiosk> linkAgent({
    required String phone,
    required String code,
    required String customName,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final cleanCode = code.trim();

    if (cleanPhone.length < 8) {
      throw Exception('Numéro de téléphone agent trop court (minimum 8 chiffres).');
    }
    if (cleanCode.length != 6) {
      throw Exception('Le code d’accès patron doit comporter exactement 6 chiffres.');
    }

    // Construire une liste exhaustive de variantes du numéro pour garantir le matching
    // ex: 014733535, 229014733535, +229014733535, 4733535...
    final candidates = <String>{cleanPhone};
    if (cleanPhone.startsWith('229')) {
      final without229 = cleanPhone.substring(3);
      candidates.add(without229);
      candidates.add('+$cleanPhone');
      if (without229.startsWith('01')) {
        candidates.add(without229.substring(2));
      }
    } else {
      candidates.add('229$cleanPhone');
      candidates.add('+229$cleanPhone');
    }

    if (cleanPhone.startsWith('01')) {
      final without01 = cleanPhone.substring(2);
      candidates.add(without01);
      candidates.add('229$without01');
      candidates.add('+229$without01');
    }

    if (cleanPhone.startsWith('228')) {
      candidates.add(cleanPhone.substring(3));
      candidates.add('+$cleanPhone');
    } else {
      candidates.add('228$cleanPhone');
      candidates.add('+228$cleanPhone');
    }

    if (cleanPhone.length >= 8) {
      candidates.add(cleanPhone.substring(cleanPhone.length - 8));
    }

    final user = _client.auth.currentUser;
    Map<String, dynamic>? agentRow;
    String? serverCode;

    // 1. Tenter la recherche dans Supabase
    try {
      final orFilter = candidates.map((c) => 'phone_number.eq.$c').join(',');
      try {
        final list = await _client
            .from('agents')
            .select('id, phone_number, owner_code')
            .or(orFilter)
            .limit(10);
        if (list.isNotEmpty) {
          agentRow = list.first;
          serverCode = agentRow['owner_code'] as String?;
        }
      } catch (e1) {
        debugPrint('[OwnerService] Colonne owner_code absente ou erreur select: $e1');
        // Fallback sans owner_code si la colonne n'est pas encore créée
        final list = await _client
            .from('agents')
            .select('id, phone_number')
            .or(orFilter)
            .limit(10);
        if (list.isNotEmpty) {
          agentRow = list.first;
        }
      }
    } catch (e) {
      debugPrint('[OwnerService] Erreur recherche Supabase agents: $e');
    }

    // 2. Vérifier si l'utilisateur teste sur son propre compte / téléphone
    if (agentRow == null && user != null) {
      final prefs = await SharedPreferences.getInstance();
      final localPhone = prefs.getString('local_phone_plain');
      final localCode = prefs.getString('local_owner_code');
      if (localPhone != null && candidates.any((c) => localPhone.contains(c) || c.contains(localPhone))) {
        agentRow = {
          'id': user.id,
          'phone_number': localPhone,
          'owner_code': localCode,
        };
        serverCode = localCode;
      }
    }

    // 3. Validation stricte : l'agent doit exister et le code doit correspondre à ce numéro
    if (agentRow == null) {
      throw Exception('Aucun compte agent trouvé avec le numéro $phone. Demandez à votre agent de créer son compte sur Carnet MoMo.');
    }

    if (serverCode == null || serverCode.trim().isEmpty) {
      throw Exception('L’agent n’a pas encore généré de code. Demandez-lui d’ouvrir Réglages > "Code d’accès patron" sur son téléphone.');
    }

    if (serverCode.trim() != cleanCode) {
      throw Exception('Code d’accès incorrect. Ce code ne correspond pas au numéro $phone.');
    }

    final agentId = agentRow['id'] as String;
    final agentPhone = agentRow['phone_number'] as String? ?? phone.trim();

    final kiosk = LinkedKiosk(
      id: const Uuid().v4(),
      agentId: agentId,
      agentPhone: agentPhone,
      customName: customName.trim(),
      addedAt: DateTime.now(),
    );

    // Sauvegarde locale garantie dans SharedPreferences
    final current = await getLinkedKiosks();
    final updated = current.where((k) => k.agentId != agentId).toList()..add(kiosk);
    await saveLinkedKiosks(updated);

    // Synchronisation en ligne avec Supabase pour que l'Administrateur
    // puisse voir les patrons avec leurs agents sur son tableau de bord
    if (user != null) {
      try {
        final patronRow = await _client
            .from('agents')
            .select('phone_number')
            .eq('id', user.id)
            .maybeSingle();
        final patronPhone = patronRow?['phone_number'] as String? ?? user.phone ?? 'Inconnu';

        await _client.from('owner_kiosks').upsert({
          'id': kiosk.id,
          'owner_id': user.id,
          'owner_phone': patronPhone,
          'agent_id': agentId,
          'agent_phone': agentPhone,
          'custom_name': customName.trim(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (e) {
        debugPrint('[OwnerService] Synchro Supabase owner_kiosks (non bloquant): $e');
      }
    }

    return kiosk;
  }

  Future<void> removeKiosk(String kioskId) async {
    final current = await getLinkedKiosks();
    final updated = current.where((k) => k.id != kioskId).toList();
    await saveLinkedKiosks(updated);

    try {
      await _client.from('owner_kiosks').delete().eq('id', kioskId);
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // 3. Récupération des transactions de l'agent (en direct)
  // -------------------------------------------------------------

  Future<List<MomoTransaction>> fetchKioskTransactions(String agentId) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'kiosk_txs_cache_$agentId';
    final user = _client.auth.currentUser;

    // 1. Tenter la récupération en ligne depuis Supabase
    try {
      final rows = await _client
          .from('transactions')
          .select()
          .eq('agent_id', agentId)
          .order('date', ascending: false)
          .timeout(const Duration(seconds: 5));

      final txs = (rows as List<dynamic>)
          .map((r) => MomoTransaction.fromMap(r as Map<String, dynamic>))
          .toList();

      if (txs.isNotEmpty) {
        // Mettre en cache local pour consultation hors ligne
        final encoded = jsonEncode(txs.map((t) => t.toMap()).toList());
        await prefs.setString(cacheKey, encoded);
        return txs;
      }
    } catch (e) {
      debugPrint('[OwnerService] Mode hors ligne ou erreur fetch transactions Supabase: $e');
    }

    // 2. Si l'agent lié correspond au compte actuel ou si on est en local sur le même appareil :
    if (user != null && user.id == agentId) {
      try {
        final localTxs = await DatabaseService.instance.getTransactions();
        if (localTxs.isNotEmpty) {
          final encoded = jsonEncode(localTxs.map((t) => t.toMap()).toList());
          await prefs.setString(cacheKey, encoded);
          return localTxs;
        }
      } catch (_) {}
    }

    // 3. Charger les transactions depuis le cache local précédent
    final raw = prefs.getString(cacheKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        return list
            .map((r) => MomoTransaction.fromMap(r as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    // 4. Dernier recours : transactions locales SQLite
    try {
      final localFallback = await DatabaseService.instance.getTransactions();
      return localFallback;
    } catch (_) {
      return [];
    }
  }
}

