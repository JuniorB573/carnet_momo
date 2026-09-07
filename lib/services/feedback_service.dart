import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Permet à l'agent de laisser une note (1 à 5 étoiles) et un commentaire
/// libre sur l'app, envoyé directement à l'administrateur via Supabase.
class FeedbackService {
  final _client = Supabase.instance.client;

  Future<void> submit({required int rating, String? comment}) async {
    final agentId = _client.auth.currentUser?.id;
    if (agentId == null) {
      throw Exception("Connexion nécessaire pour envoyer un avis.");
    }
    await _client.from('feedback').insert({
      'agent_id': agentId,
      'rating': rating,
      'comment': (comment != null && comment.trim().isNotEmpty) ? comment.trim() : null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }).timeout(const Duration(seconds: 10));
  }
}
