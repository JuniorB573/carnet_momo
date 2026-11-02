import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/momo_transaction.dart';

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

  /// Récupère ou génère un code d'accès patron à 6 chiffres
  Future<String> getOrGenerateOwnerCode() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Non connecté');

    try {
      final res = await _client
          .from('agents')
          .select('owner_code')
          .eq('id', user.id)
          .maybeSingle();

      if (res != null && res['owner_code'] != null && (res['owner_code'] as String).isNotEmpty) {
        return res['owner_code'] as String;
      }
    } catch (_) {}

    // Générer un code 6 chiffres
    final newCode = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    try {
      await _client
          .from('agents')
          .update({'owner_code': newCode})
          .eq('id', user.id);
    } catch (e) {
      debugPrint('[OwnerService] Erreur maj code: $e');
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

  /// Associe un agent avec son numéro, son code et un nom choisi par le patron
  Future<LinkedKiosk> linkAgent({
    required String phone,
    required String code,
    required String customName,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final cleanCode = code.trim();

    // Rechercher l'agent dans Supabase
    final res = await _client
        .from('agents')
        .select('id, phone_number, owner_code')
        .or('phone_number.eq.$cleanPhone,phone_number.ilike.%$cleanPhone%')
        .maybeSingle();

    if (res == null) {
      throw Exception('Aucun compte agent trouvé avec ce numéro.');
    }

    final serverCode = (res['owner_code'] as String?)?.trim();
    if (serverCode == null || serverCode.isEmpty || serverCode != cleanCode) {
      throw Exception('Code d’accès incorrect ou expiré. Demandez à votre agent de générer son code.');
    }

    final agentId = res['id'] as String;
    final agentPhone = res['phone_number'] as String? ?? cleanPhone;

    final kiosk = LinkedKiosk(
      id: const Uuid().v4(),
      agentId: agentId,
      agentPhone: agentPhone,
      customName: customName.trim(),
      addedAt: DateTime.now(),
    );

    final current = await getLinkedKiosks();
    // Éviter les doublons
    final updated = current.where((k) => k.agentId != agentId).toList()..add(kiosk);
    await saveLinkedKiosks(updated);
    return kiosk;
  }

  Future<void> removeKiosk(String kioskId) async {
    final current = await getLinkedKiosks();
    final updated = current.where((k) => k.id != kioskId).toList();
    await saveLinkedKiosks(updated);
  }

  // -------------------------------------------------------------
  // 3. Récupération des transactions de l'agent (en direct)
  // -------------------------------------------------------------

  Future<List<MomoTransaction>> fetchKioskTransactions(String agentId) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'kiosk_txs_cache_$agentId';
    try {
      final rows = await _client
          .from('transactions')
          .select()
          .eq('agent_id', agentId)
          .order('date', ascending: false)
          .timeout(const Duration(seconds: 6));

      final txs = (rows as List<dynamic>)
          .map((r) => MomoTransaction.fromMap(r as Map<String, dynamic>))
          .toList();

      // Mettre en cache local pour consultation hors ligne
      final encoded = jsonEncode(txs.map((t) => t.toMap()).toList());
      await prefs.setString(cacheKey, encoded);

      return txs;
    } catch (e) {
      debugPrint('[OwnerService] Mode hors ligne ou erreur fetch transactions: $e');
      // Hors ligne : charger les transactions depuis le cache local
      final raw = prefs.getString(cacheKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final list = jsonDecode(raw) as List<dynamic>;
          return list
              .map((r) => MomoTransaction.fromMap(r as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }
      return [];
    }
  }
}

