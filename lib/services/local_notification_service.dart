import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

/// Affiche une notification directement sur le téléphone de l'agent,
/// immédiatement après une action (ex: transaction enregistrée).
///
/// Contrairement à une vraie notification "push" envoyée à distance
/// (qui nécessiterait de configurer Firebase Cloud Messaging, un service
/// externe séparé), ceci est une notification 100% locale : elle
/// fonctionne hors ligne et ne demande aucune configuration supplémentaire.
class LocalNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Demande explicitement l'autorisation d'envoyer des notifications (utile pour Android 13+)
  static Future<void> requestPermission() async {
    if (!_initialized) await init();
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
  }

  static Future<void> showTransactionNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();
    const androidDetails = AndroidNotificationDetails(
      'transactions_channel',
      'Opérations enregistrées',
      channelDescription: 'Confirmation après chaque dépôt ou retrait enregistré',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  /// Affiche une alerte d'abonnement quand l'agent ouvre l'app et que
  /// son abonnement expire bientôt (≤ 3 jours) ou est déjà expiré.
  /// La notification n'est affichée qu'une seule fois par journée pour
  /// ne pas être trop intrusive.
  static Future<void> showSubscriptionAlert({
    required bool isExpired,
    required int daysLeft,
    required String lang,
  }) async {
    if (!_initialized) await init();

    String title;
    String body;

    if (isExpired) {
      title = lang == 'fr' ? '🔒 Abonnement expiré' : '🔒 Subscription expired';
      body = lang == 'fr'
          ? 'Votre abonnement a expiré. Allez dans Réglages pour renouveler et continuer à utiliser l\'app.'
          : 'Your subscription has expired. Go to Settings to renew and continue using the app.';
    } else {
      title = lang == 'fr'
          ? '⏰ Abonnement : $daysLeft jour${daysLeft > 1 ? 's' : ''} restant${daysLeft > 1 ? 's' : ''}'
          : '⏰ Subscription: $daysLeft day${daysLeft > 1 ? 's' : ''} left';
      body = lang == 'fr'
          ? 'Pensez à renouveler votre abonnement avant qu\'il expire !'
          : 'Remember to renew your subscription before it expires!';
    }

    const androidDetails = AndroidNotificationDetails(
      'subscription_channel',
      'Abonnement',
      channelDescription: 'Alertes de renouvellement d\'abonnement',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    // ID fixe (42) pour éviter les doublons : une seule notif d'abo à la fois.
    await _plugin.show(42, title, body, details);
  }

  /// Affiche une notification de confirmation quand un abonnement est activé
  /// ou prolongé (soit par paiement automatique SasPay, soit manuellement par un admin).
  static Future<void> showSubscriptionActivatedNotification({
    DateTime? renewalDate,
    required String lang,
  }) async {
    if (!_initialized) await init();

    final dateStr = renewalDate != null
        ? DateFormat('dd/MM/yyyy').format(renewalDate.toLocal())
        : null;

    final title = lang == 'fr'
        ? '🎉 Abonnement activé !'
        : '🎉 Subscription activated!';

    final body = lang == 'fr'
        ? (dateStr != null
            ? 'Votre abonnement est actif jusqu\'au $dateStr. Vous pouvez maintenant continuer à travailler et utiliser l\'app.'
            : 'Votre abonnement est maintenant actif. Vous pouvez continuer à travailler et utiliser l\'app.')
        : (dateStr != null
            ? 'Your subscription is active until $dateStr. You can now continue working and using the app.'
            : 'Your subscription is now active. You can continue working and using the app.');

    const androidDetails = AndroidNotificationDetails(
      'subscription_success_channel',
      'Activation d\'abonnement',
      channelDescription: 'Notifications de confirmation d\'activation ou prolongation d\'abonnement',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      43,
      title,
      body,
      details,
    );
  }
}
