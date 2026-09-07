import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
}
