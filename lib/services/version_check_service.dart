import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UpdateInfo {
  final String latestVersion;
  final String apkUrl;
  final String? message;

  UpdateInfo({required this.latestVersion, required this.apkUrl, this.message});
}

/// Vérifie, au démarrage de l'app, si une version plus récente de l'APK
/// est disponible — utile car l'app est distribuée manuellement (APK sur
/// Google Drive) et non via un store qui gèrerait les mises à jour
/// automatiquement.
///
/// S'appuie sur une seule ligne (id = 1) de la table Supabase
/// `app_config`, lisible sans connexion (voir supabase_admin_dashboard.sql)
/// puisqu'elle ne contient aucune donnée sensible.
class VersionCheckService {
  final _client = Supabase.instance.client;

  /// Vrai si [remote] est une version plus récente que [local]. Compare
  /// segment par segment ("1.2.10" > "1.2.9"), en complétant par des 0 les
  /// formats de longueur différente ("1.3" vs "1.3.1").
  bool _isNewer(String remote, String local) {
    final r = remote.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
    final l = local.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
    final len = r.length > l.length ? r.length : l.length;
    for (var i = 0; i < len; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv != lv) return rv > lv;
    }
    return false;
  }

  /// Renvoie les infos de mise à jour si une version plus récente existe
  /// côté serveur, sinon null. Toujours "best effort" : une erreur réseau,
  /// une table absente ou une ligne manquante ne bloque jamais l'agent —
  /// on se contente de ne rien afficher.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final row = await _client.from('app_config').select().eq('id', 1).maybeSingle().timeout(const Duration(seconds: 3));
      if (row == null) return null;

      final latest = row['latest_version'] as String?;
      final apkUrl = row['apk_url'] as String?;
      if (latest == null || apkUrl == null) return null;

      if (_isNewer(latest, info.version)) {
        return UpdateInfo(
          latestVersion: latest,
          apkUrl: apkUrl,
          message: row['update_message'] as String?,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
