# Carnet MoMo 📱💼

**Carnet MoMo** est une application mobile & cloud professionnelle conçue pour numériser, simplifier et fiabiliser la gestion quotidienne des points de vente et agents de Mobile Money en Afrique de l'Ouest.

L'application élimine définitivement les erreurs de calcul manuel des commissions grâce à un moteur dynamique par paliers, offre un suivi rigoureux des opérations (dépôts / retraits), assure une continuité d'activité 100% hors-ligne et intègre une supervision multi-kiosques pour les propriétaires.

---

## 🚀 Fonctionnalités Clés

### 1. Saisie Rapide & Moteur de Commission Dynamique
- Sélection immédiate du réseau et du type d'opération (**Dépôt** / **Retrait**).
- Calcul instantané de la commission selon les grilles officielles par paliers de chaque opérateur.
- Support du mode hors grille pour les transactions exceptionnelles.
- Historique chronologique complet avec bilans journaliers et mensuels.

### 2. Architecture Multi-Pays & Multi-Réseaux
Prise en charge native des configurations et opérateurs de 6 pays :
- 🇧🇯 **Bénin** : MTN Mobile Money, Moov Money, Celtiis Cash
- 🇹🇬 **Togo** : T-Money (Togocom), Moov Money Togo
- 🇨🇮 **Côte d'Ivoire** : Orange Money, MTN MoMo, Moov Money, Wave
- 🇸🇳 **Sénégal** : Orange Money, Wave Sénégal, Free Money
- 🇧🇫 **Burkina Faso** : Orange Money, Moov Money Burkina
- 🇲🇱 **Mali** : Orange Money, Moov Africa Malitel

### 3. Espace Propriétaire / Patron (Multi-Kiosques)
- **Liaison sécurisée** : Association d'un agent au tableau de bord du patron via un code d'accès confidentiel à 6 chiffres et le numéro de téléphone.
- **Normalisation intelligente** : Reconnaissance automatique des numéros internationaux (E.164) et locaux.
- **Suivi en temps réel** : Consultation consolidée des volumes de transactions, commissions et ventilations dépôts/retraits pour chaque kiosque.
- **Fiches récapitulatives** : Génération et partage de rapports certifiés par agent.

### 4. Résilience Hors-Ligne (Offline-First) & Cloud
- **Fonctionnement hors-ligne autonome** : Base locale SQLite chiffrée permettant d'enregistrer les opérations sans aucune connexion internet.
- **Synchronisation automatique** : Dès le retour du réseau, les données sont sauvegardées en arrière-plan sur Supabase.
- **Sécurité RLS (Row Level Security)** : Cloisonnement strict des données au niveau de la base PostgreSQL.

### 5. Modèle Économique & Passerelle de Paiement
- **Période d'essai** : 7 jours gratuits offerts dès l'activation du compte.
- **Abonnement** : 800 F CFA / mois.
- **Paiement intégré via SasPay** : Règlement sécurisé par Mobile Money ou carte bancaire avec activation immédiate en temps réel.

### 6. Espace Super-Admin
- Supervision globale du parc d'agents et de kiosques.
- Statistiques de performance macro-économiques.
- Prolongation manuelle d'abonnements et gestion des retours d'expérience.

---

## 🛠️ Stack Technique

- **Framework Mobile** : Flutter (Dart 3.x)
- **Base de données Locale** : SQLite (`sqflite`)
- **Backend & Authentification** : Supabase (PostgreSQL, Row Level Security, Edge Functions)
- **Passerelle de Paiement** : SasPay Checkout
- **Exports & Reporting** : Moteur PDF vectoriel (`pdf`, `printing`) & Tableurs Excel/CSV

---

## 📦 Installation & Démarrage

### Prérequis
- Flutter SDK (≥ 3.0.0)
- Android Studio / VS Code avec extensions Flutter & Dart
- Un appareil Android physique ou un émulateur

### Lancement en développement
1. Cloner le dépôt :
   ```bash
   git clone https://github.com/JuniorB573/carnet_momo.git
   cd carnet_momo
   ```
2. Installer les dépendances :
   ```bash
   flutter pub get
   ```
3. Lancer l'application :
   ```bash
   flutter run
   ```

### Compilation de l'APK Release
```bash
flutter build apk --release
```
L'APK généré sera disponible dans le dossier `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📄 Documentation

Le cahier des charges fonctionnel et technique détaillé du projet est consultable dans le document :
- **[Cahier_des_Charges_Carnet_MoMo.pdf](./Cahier_des_Charges_Carnet_MoMo.pdf)** (Version 2.1.0)
