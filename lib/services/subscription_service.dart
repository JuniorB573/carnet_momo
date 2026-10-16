import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_notification_service.dart';

enum SubscriptionState { essai, actif, expire }

class SubscriptionStatus {
  final SubscriptionState state;
  final int daysLeft;
  final DateTime? renewalDate;

  SubscriptionStatus({
    required this.state,
    required this.daysLeft,
    this.renewalDate,
  });
}

/// Gère l'essai gratuit de 7 jours et le déblocage de l'abonnement.
///
/// La date de début d'essai et la date de fin d'abonnement payé sont
/// stockées de façon fiable sur Supabase (table `subscriptions`), pas
/// seulement sur le téléphone — sinon un agent pourrait relancer un
/// essai gratuit en désinstallant puis réinstallant l'app. La copie
/// locale (SharedPreferences) ne sert que de secours pour continuer à
/// fonctionner hors ligne entre deux synchronisations.
///
/// Le déblocage se fait exclusivement via SasPay (voir
/// startSasPayCheckout) — l'activation par webhook met à jour
/// `subscriptions.paid_until`, repris ici au prochain _syncFromServer.
class SubscriptionService {
  static const int trialDays = 7;
  static const int monthlyFeeFcfa = 800;


  final _client = Supabase.instance.client;

  /// Démarre un paiement SasPay pour l'abonnement mensuel. Appelle une
  /// Edge Function Supabase ('create-saspay-checkout') qui crée la
  /// session de paiement côté serveur (clé secrète SasPay jamais exposée
  /// dans l'app) et retourne l'URL de paiement à ouvrir. L'activation
  /// réelle de l'abonnement se fait ensuite via un webhook SasPay →
  /// Supabase, une fois le paiement confirmé — pas de code à saisir.
  Future<String> startSasPayCheckout() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }
    final res = await _client.functions.invoke(
      'create-saspay-checkout',
      body: {
        'user_id': user.id,
        'amount': monthlyFeeFcfa,
        'customer_email': user.email ?? 'agent@carnetmomo.app',
        'customer_name': (user.userMetadata?['full_name'] as String?)
            ?? user.email
            ?? 'Agent',
      },
    );
    final data = res.data;
    if (data is Map && data['checkout_url'] is String) {
      return data['checkout_url'] as String;
    }
    throw Exception('Réponse inattendue du serveur de paiement.');
  }

  Future<SubscriptionStatus> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await _syncFromServer(prefs);

    var trialStartStr = prefs.getString('trial_start');
    if (trialStartStr == null) {
      // Filet de sécurité si jamais la synchronisation serveur a échoué
      // et qu'aucune valeur locale n'existe encore.
      trialStartStr = DateTime.now().toIso8601String();
      await prefs.setString('trial_start', trialStartStr);
    }

    final paidUntilStr = prefs.getString('paid_until');
    final now = DateTime.now();

    if (paidUntilStr != null) {
      final paidUntil = DateTime.parse(paidUntilStr).toLocal();
      if (paidUntil.isAfter(now)) {
        final daysLeft = paidUntil.difference(now).inDays + 1;
        return SubscriptionStatus(
          state: SubscriptionState.actif,
          daysLeft: daysLeft,
          renewalDate: paidUntil,
        );
      }
    }

    final trialStart = DateTime.parse(trialStartStr).toLocal();
    final daysElapsed = now.difference(trialStart).inHours / 24;

    if (daysElapsed <= trialDays) {
      final daysLeft = (trialDays - daysElapsed).ceil().clamp(0, trialDays);
      return SubscriptionStatus(state: SubscriptionState.essai, daysLeft: daysLeft);
    }

    return SubscriptionStatus(state: SubscriptionState.expire, daysLeft: 0);
  }

  /// Va chercher sur Supabase la vraie date de début d'essai (et de fin
  /// d'abonnement payé) et met à jour la copie locale. Si aucune
  /// connexion n'est disponible, échoue silencieusement et on continue
  /// avec la dernière copie locale connue.
  Future<void> _syncFromServer(SharedPreferences prefs) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final row = await _client
          .from('subscriptions')
          .select()
          .eq('agent_id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 3));

      if (row != null) {
        if (row['trial_start'] != null) {
          await prefs.setString('trial_start', row['trial_start'] as String);
        }
        if (row['paid_until'] != null) {
          final serverPaidUntil = row['paid_until'] as String;
          final lastNotified = prefs.getString('last_notified_paid_until');
          final parsed = DateTime.tryParse(serverPaidUntil)?.toLocal();

          if (parsed != null && parsed.isAfter(DateTime.now())) {
            if (lastNotified != serverPaidUntil) {
              await prefs.setString('last_notified_paid_until', serverPaidUntil);
              final lang = prefs.getString('language') ?? 'fr';
              await LocalNotificationService.showSubscriptionActivatedNotification(
                renewalDate: parsed,
                lang: lang,
              );
            }
          }
          await prefs.setString('paid_until', serverPaidUntil);
        }
      } else {
        // Si la requête réussit mais qu'aucune ligne n'est trouvée, cela
        // signifie que l'agent a été supprimé de la base de données.
        // On force la déconnexion immédiate.
        await _client.auth.signOut();
      }
    } on AuthException catch (_) {
      // Jeton invalide ou expiré suite à une suppression de compte
      await _client.auth.signOut();
    } catch (e) {
      // Pas de connexion ou serveur injoignable : on continue avec la
      // dernière valeur locale connue, sans bloquer l'agent.
    }
  }
}
