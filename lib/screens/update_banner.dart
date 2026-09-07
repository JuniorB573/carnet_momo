import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/translations.dart';
import '../services/version_check_service.dart';
import '../theme/app_theme.dart';

/// Bandeau discret en haut de l'écran, quel que soit l'écran affiché
/// (connexion, verrouillage, app, tableau de bord) — voir main.dart.
/// L'agent peut le fermer pour la session en cours ; il réapparaîtra au
/// prochain lancement tant que la version installée n'a pas changé.
class UpdateBanner extends StatelessWidget {
  final UpdateInfo info;
  final LanguageController languageController;
  final VoidCallback onDismiss;

  const UpdateBanner({
    super.key,
    required this.info,
    required this.languageController,
    required this.onDismiss,
  });

  String get _lang => languageController.value;

  Future<void> _openApk() async {
    final uri = Uri.parse(info.apkUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.green,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
          child: Row(
            children: [
              const Icon(Icons.system_update, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${t('nouvelle_version_disponible', _lang)} (v${info.latestVersion})',
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: _openApk,
                style: TextButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(t('telecharger', _lang), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
