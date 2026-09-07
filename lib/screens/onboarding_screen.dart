import 'package:flutter/material.dart';
import '../services/country_controller.dart';
import '../services/subscription_service.dart';
import '../services/translations.dart';
import '../theme/app_theme.dart';
import 'reglages_screen.dart';

/// Affiché une seule fois, juste après l'inscription d'un nouvel agent.
/// L'objectif : s'assurer qu'il configure ses grilles de commission avant
/// d'arriver sur l'écran de saisie, plutôt que de le laisser découvrir
/// l'existence des Réglages par lui-même plus tard.
class OnboardingScreen extends StatelessWidget {
  final VoidCallback onDone;
  final LanguageController languageController;
  final CountryController countryController;

  const OnboardingScreen({
    super.key,
    required this.onDone,
    required this.languageController,
    required this.countryController,
  });

  @override
  Widget build(BuildContext context) {
    final lang = languageController.value;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: AppColors.green,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('bienvenue_titre', lang),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    t('bienvenue_texte', lang),
                    style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.5),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReglagesScreen(
                languageController: languageController,
                countryController: countryController,
                status: SubscriptionStatus(
                  state: SubscriptionState.essai,
                  daysLeft: SubscriptionService.trialDays,
                ),
                onStatusChanged: () {},
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                child: ElevatedButton(
                  onPressed: onDone,
                  child: Text(t('configure_commencer', lang)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
