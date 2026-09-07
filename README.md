# Carnet MoMo — Projet Flutter (V1, étape 1)

## Ce qui est déjà là
- Saisie d'opérations (dépôt/retrait) avec calcul automatique de commission
- Grilles de commission configurables par réseau (MTN, Moov, Celtiis) et par type
- Historique avec bilan jour/mois
- Résumé du jour visible directement sur l'écran de saisie
- Stockage 100% local (SQLite) — fonctionne entièrement hors ligne
- Essai gratuit de 4 jours + activation par code (fonctionne aussi hors ligne)

## Ce qui manque encore (prochaines étapes)
- Compte agent (inscription numéro + PIN)
- Synchronisation avec un serveur (Supabase/Firebase) pour la sauvegarde
- Espace administrateur pour activer les abonnements
- Multilingue FR/EN/Fon

## Comment lancer le projet

1. Copie tout ce dossier dans VS Code.
2. Ouvre un terminal dans ce dossier et lance :
   ```
   flutter pub get
   ```
   (télécharge les dépendances listées dans `pubspec.yaml`)
3. Branche ton téléphone Android en USB (débogage USB activé).
4. Vérifie que ton téléphone est bien détecté :
   ```
   flutter devices
   ```
5. Lance l'app :
   ```
   flutter run
   ```

## Si tu rencontres une erreur
Copie-colle le message d'erreur exact ici dans le chat, on la corrige ensemble.

## Un point de sécurité à changer avant tout vrai lancement
Dans `lib/services/subscription_service.dart`, la variable `_secretSalt` doit être
remplacée par une vraie valeur secrète (pas celle laissée par défaut) avant de
distribuer l'app à de vrais agents — c'est elle qui protège la génération des
codes d'activation.
