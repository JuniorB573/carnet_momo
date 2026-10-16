# -*- coding: utf-8 -*-
"""
Générateur du Cahier des Charges - Carnet MoMo
Formaté selon le modèle académique et professionnel rigoureux du projet 'Assistant RAG Lois Numériques'.
Comprend :
- En-tête de présentation avec Porteurs et Projet
- Contexte & Problématique métier concrète
- Objectifs d'Impact (Général & Spécifiques)
- Périmètre d'Intervention (Inclus / Exclus)
- Utilisateurs Cibles & Prérequis
- Exigences Fonctionnelles (EF1 à EF12 avec Priorités et Réf.)
- Exigences Non Fonctionnelles (Fiabilité, Offline-First, Privacy, Sobriété)
- Architecture Technique en 6 étapes (Ingestion, Local DB, Cloud Sync, RLS, Paiement SasPay, UI)
- Évaluation et Critères d'Acceptation (Tableau métrique)
- Livrables (APK, Code GitHub, Supabase DB, Documentation)
- Planning Prévisionnel par Phases
- Gestion des Risques & Mesures d'Atténuation
- Contraintes Réglementaires & Techniques
- Évolutions Futures & Vision à Long Terme (Multi-caisses, Scan SMS, Imprimantes Bluetooth)
- Tableau de Validation & Signatures (Porteurs & Encadrant)
"""

import os
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfgen import canvas

# Palette de couleurs corporate élégante (Bleu marine professionnel, Vert MoMo, Gris doux)
C_PRIMARY = colors.HexColor("#0F2942")       # Bleu marine foncé / institutionnel
C_SECONDARY = colors.HexColor("#166534")     # Vert MoMo émeraude profond
C_ACCENT = colors.HexColor("#D97706")        # Doré ambré
C_DARK = colors.HexColor("#1E293B")          # Texte anthracite
C_MUTED = colors.HexColor("#64748B")         # Texte secondaire
C_LIGHT_BG = colors.HexColor("#F8FAFC")      # Fond alterné clair
C_BORDER = colors.HexColor("#CBD5E1")        # Bordures nettes
C_HEADER_BG = colors.HexColor("#0F2942")     # Fond entêtes tableau

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super(NumberedCanvas, self).__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super(NumberedCanvas, self).showPage()
        super(NumberedCanvas, self).save()

    def draw_page_decorations(self, page_count):
        self.saveState()
        self.setFont("Helvetica-Bold", 8)
        self.setFillColor(C_MUTED)
        
        # En-tête (sauf page 1)
        if self._pageNumber > 1:
            self.drawString(50, 802, "CARNET MOMO — CAHIER DES CHARGES FONCTIONNEL & TECHNIQUE")
            self.drawRightString(545, 802, "OCTOBRE 2026")
            self.setStrokeColor(C_BORDER)
            self.setLineWidth(0.6)
            self.line(50, 794, 545, 794)
        
        # Pied de page (sur toutes les pages)
        self.setStrokeColor(C_BORDER)
        self.setLineWidth(0.6)
        self.line(50, 42, 545, 42)
        self.setFont("Helvetica", 8)
        self.drawString(50, 30, "Carnet MoMo · Application Mobile & Cloud · Solution Pro pour Agents de Proximité")
        page_str = f"Page {self._pageNumber} / {page_count}"
        self.drawRightString(545, 30, page_str)
        self.restoreState()


def generate_cahier_des_charges_rag_style(output_path):
    doc = SimpleDocTemplate(
        output_path,
        pagesize=A4,
        leftMargin=50,
        rightMargin=50,
        topMargin=50,
        bottomMargin=50
    )
    
    styles = getSampleStyleSheet()
    
    # Styles
    doc_title = ParagraphStyle(
        'DocTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=20,
        leading=25,
        textColor=C_PRIMARY,
        spaceAfter=12
    )
    
    h1_style = ParagraphStyle(
        'H1_Custom',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=12,
        leading=16,
        textColor=C_PRIMARY,
        spaceBefore=14,
        spaceAfter=6,
        keepWithNext=True
    )
    
    body_style = ParagraphStyle(
        'Body_Custom',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13.5,
        textColor=C_DARK,
        spaceAfter=6
    )
    
    bullet_style = ParagraphStyle(
        'Bullet_Custom',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=C_DARK,
        leftIndent=14,
        firstLineIndent=-10,
        spaceAfter=3
    )
    
    t_header = ParagraphStyle(
        'THeader',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11,
        textColor=colors.white
    )
    
    t_cell = ParagraphStyle(
        'TCell',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8,
        leading=11,
        textColor=C_DARK
    )
    
    t_cell_bold = ParagraphStyle(
        'TCellBold',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8,
        leading=11,
        textColor=C_DARK
    )
    
    story = []
    
    # TITRE PRINCIPAL
    story.append(Paragraph("Cahier des Charges — Carnet MoMo", doc_title))
    story.append(Paragraph("<i>Plateforme mobile & cloud de gestion des commissions et opérations pour agents Mobile Money</i>", ParagraphStyle('Sub', fontName='Helvetica-Oblique', fontSize=10, textColor=C_SECONDARY, spaceAfter=12)))
    
    # TABLEAU EN-TÊTE PROJET (Exactement comme le modèle RAG)
    header_data = [
        [
            Paragraph("<b>Projet</b>", t_cell_bold),
            Paragraph("Application mobile & cloud tout-en-un pour agents Mobile Money : automatisation du calcul des commissions selon les grilles opérateurs (MTN, Moov, Orange, Wave, Celtiis, T-Money), journal de caisse étanche, résilience hors-ligne et micro-abonnement récurrent.", t_cell)
        ],
        [
            Paragraph("<b>Porteur du projet</b>", t_cell_bold),
            Paragraph("<b>BIAHOU Ahossou Junior Marie-Clémenceau</b>", t_cell)
        ],
        [
            Paragraph("<b>Version & Date</b>", t_cell_bold),
            Paragraph("v1.0 — Octobre 2026 (Version Initiale de Production)", t_cell)
        ]
    ]
    t_top = Table(header_data, colWidths=[120, 375])
    t_top.setStyle(TableStyle([
        ('BOX', (0,0), (-1,-1), 1, C_BORDER),
        ('INNERGRID', (0,0), (-1,-1), 0.5, C_BORDER),
        ('BACKGROUND', (0,0), (0,-1), C_LIGHT_BG),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(t_top)
    story.append(Spacer(1, 10))
    
    # 1. CONTEXTE
    story.append(Paragraph("1. Contexte & Problématique", h1_style))
    story.append(Paragraph(
        "En Afrique de l'Ouest (Bénin, Togo, Côte d'Ivoire, Sénégal), les agents de proximité et gérants de points de vente Mobile Money sont au cœur des échanges économiques. "
        "Chaque jour, un point de vente traite entre 50 et 300 transactions de dépôts et de retraits pour le compte de multiples opérateurs (MTN, Moov, Celtiis, Wave, Orange, T-Money). "
        "Pourtant, l'écrasante majorité de ces agents tient encore sa comptabilité sur des <b>cahiers physiques en papier</b> ou de simples calepins.",
        body_style
    ))
    story.append(Paragraph(
        "<b>Le problème :</b> Les grilles de commissions des opérateurs sont complexes et calculées par tranches non linéaires (ex : de 10 001 à 25 000 FCFA, commission fixe ou en pourcentage). "
        "En période de forte affluence, l'agent calcule manuellement de tête ou recherche la tranche sur une affiche déchirée :",
        body_style
    ))
    story.append(Paragraph("• <b>Erreurs de calcul systématiques :</b> Perte de revenus sur les commissions sous-évaluées ou litiges de caisse.", bullet_style))
    story.append(Paragraph("• <b>Confusion de trésorerie :</b> Mélange entre argent physique en caisse (espèces) et unités virtuelles (UV).", bullet_style))
    story.append(Paragraph("• <b>Vulnérabilité et perte de données :</b> Registre papier détérioré, volé, mouillé ou illisible rendant tout bilan mensuel impossible.", bullet_style))
    story.append(Paragraph("• <b>Absence d'historique fiable :</b> Incapacité de prouver sa solvabilité ou son volume d'affaires pour obtenir un crédit bancaire.", bullet_style))
    story.append(Spacer(1, 4))
    story.append(Paragraph(
        "<b>Notre solution :</b> L'application <b>Carnet MoMo</b> numérise et automatise l'intégralité du processus. Dès que l'agent saisit le montant d'une opération, le moteur calcule instantanément la commission exacte selon la tranche officielle du réseau sélectionné, enregistre l'opération localement en mode hors-ligne sans latence, et synchronise les données en arrière-plan sur un cloud sécurisé avec séparation stricte des comptes.",
        body_style
    ))
    
    # 2. OBJECTIFS D'IMPACT
    story.append(Paragraph("2. Objectifs d'Impact", h1_style))
    story.append(Paragraph(
        "<b>Objectif général :</b> Sécuriser, professionnaliser et maximiser la rentabilité des agents Mobile Money grâce à un carnet de caisse numérique infaillible, ultra-rapide et accessible à tous.",
        body_style
    ))
    story.append(Paragraph("<b>Objectifs spécifiques :</b>", body_style))
    story.append(Paragraph("• <b>Zéro erreur de commission :</b> Calcul automatique instantané via les barèmes officiels par pays et par réseau.", bullet_style))
    story.append(Paragraph("• <b>Saisie accélérée en guichet :</b> Enregistrement d'un dépôt ou retrait en moins de 5 secondes pour ne pas ralentir le flux client.", bullet_style))
    story.append(Paragraph("• <b>Résilience totale 100% Hors-Ligne (Offline-First) :</b> Travail continu même sans aucune connexion Internet.", bullet_style))
    story.append(Paragraph("• <b>Bilan & Traçabilité comptable :</b> Visibilité en direct sur les bénéfices journaliers/mensuels et export de rapports PDF officiels.", bullet_style))
    story.append(Paragraph("• <b>Modèle économique viable :</b> Essai gratuit de 7 jours suivi d'un micro-abonnement accessible de 800 F CFA / mois via SasPay.", bullet_style))
    
    story.append(PageBreak())
    
    # 3. PÉRIMÈTRE
    story.append(Paragraph("3. Périmètre d'Intervention", h1_style))
    story.append(Paragraph("<b>Inclus :</b>", body_style))
    story.append(Paragraph("• Opérateurs & réseaux gérés : <b>Bénin</b> (MTN MoMo, Moov Money, Celtiis Cash), <b>Togo</b> (T-Money, Moov Togo), <b>Côte d'Ivoire</b> (Orange, MTN, Moov, Wave), <b>Sénégal</b> (Orange, Wave, Free).", bullet_style))
    story.append(Paragraph("• Gestion séparée des flux : Dépôts (rechargement compte client) et Retraits (décaissement espèces).", bullet_style))
    story.append(Paragraph("• Archivage mensuel figé : Un classeur comptable dédié pour chaque mois de l'année.", bullet_style))
    story.append(Paragraph("• Authentification par numéro de téléphone et protection par code PIN à 4 chiffres.", bullet_style))
    story.append(Paragraph("• Sauvegarde automatique dans le Cloud Supabase dès le retour d'une connexion réseau.", bullet_style))
    story.append(Paragraph("• Paiement autonome de l'abonnement par Mobile Money via la passerelle SasPay.", bullet_style))
    story.append(Spacer(1, 4))
    story.append(Paragraph("<b>Exclus :</b>", body_style))
    story.append(Paragraph("• Exécution directe de transactions bancaires ou transfert direct d'UV (Carnet MoMo est un journal comptable et d'audit, pas un portefeuille bancaire).", bullet_style))
    story.append(Paragraph("• Octroi de crédit ou d'avances de trésorerie.", bullet_style))
    
    # 4. UTILISATEURS CIBLES
    story.append(Paragraph("4. Utilisateurs Cibles & Prérequis", h1_style))
    story.append(Paragraph("• <b>Agents & Exploitants de Guichet MoMo :</b> Gérants de kiosques de rue, boutiques de quartier, revendeurs de crédit et caissiers de points de vente multiservices.", bullet_style))
    story.append(Paragraph("• <b>Super-Administrateurs :</b> Équipe de gestion supervisant l'activité globale, les abonnements et le support technique.", bullet_style))
    story.append(Paragraph("• <b>Prérequis utilisateur :</b> Tout smartphone Android (version 5.0 ou supérieure). Aucune compétence en comptabilité requise.", bullet_style))
    
    # 5. EXIGENCES FONCTIONNELLES (TABLEAU COMPLET)
    story.append(Paragraph("5. Exigences Fonctionnelles", h1_style))
    
    ef_data = [
        [Paragraph("Réf.", t_header), Paragraph("Exigence Fonctionnelle", t_header), Paragraph("Priorité", t_header)],
        [
            Paragraph("<b>EF1</b>", t_cell_bold),
            Paragraph("<b>Authentification Téléphonique & Code PIN :</b> Connexion sécurisée par numéro de téléphone et déverrouillage par code PIN à 4 chiffres.", t_cell),
            Paragraph("Obligatoire", t_cell_bold)
        ],
        [
            Paragraph("<b>EF2</b>", t_cell_bold),
            Paragraph("<b>Sélection Réseau & Pays :</b> Prise en charge des réseaux officiels avec drapeaux et couleurs respectives par pays.", t_cell),
            Paragraph("Obligatoire", t_cell_bold)
        ],
        [
            Paragraph("<b>EF3</b>", t_cell_bold),
            Paragraph("<b>Moteur de Tranches Automatique :</b> Calcul immédiat de la commission en fonction du montant saisi selon la grille tarifaire active.", t_cell),
            Paragraph("Obligatoire", t_cell_bold)
        ],
        [
            Paragraph("<b>EF4</b>", t_cell_bold),
            Paragraph("<b>Saisie Hors-Grille :</b> Possibilité d'ajuster ou saisir manuellement une commission pour les opérations exceptionnelles.", t_cell),
            Paragraph("Obligatoire", t_cell_bold)
        ],
        [
            Paragraph("<b>EF5</b>", t_cell_bold),
            Paragraph("<b>Journal de Caisse Journalier :</b> Consultation chronologique de toutes les transactions du jour avec filtre Dépôt/Retrait et par réseau.", t_cell),
            Paragraph("Obligatoire", t_cell_bold)
        ],
        [
            Paragraph("<b>EF6</b>", t_cell_bold),
            Paragraph("<b>Droit à l'Erreur & Audit :</b> Modification ou suppression d'une opération erronée avec boîte de dialogue de confirmation explicite.", t_cell),
            Paragraph("Obligatoire", t_cell_bold)
        ],
        [
            Paragraph("<b>EF7</b>", t_cell_bold),
            Paragraph("<b>Synthèse en Direct :</b> Affichage des totaux de commission et volume d'affaires (Aujourd'hui & Ce Mois) ventilés par opérateur.", t_cell),
            Paragraph("Obligatoire", t_cell_bold)
        ],
        [
            Paragraph("<b>EF8</b>", t_cell_bold),
            Paragraph("<b>Génération de Bilans PDF :</b> Export en un clic d'un état récapitulatif formel prêt pour impression ou partage WhatsApp.", t_cell),
            Paragraph("Obligatoire", t_cell_bold)
        ],
        [
            Paragraph("<b>EF9</b>", t_cell_bold),
            Paragraph("<b>Archives Mensuelles Indépendantes :</b> Sauvegarde de chaque mois dans un classeur historique consultable sans altérer le mois en cours.", t_cell),
            Paragraph("Obligatoire", t_cell_bold)
        ],
        [
            Paragraph("<b>EF10</b>", t_cell_bold),
            Paragraph("<b>Gestion Abonnement (800 F) :</b> Période d'essai gratuite de 7 jours, puis verrouillage avec passerelle de paiement SasPay intégrée.", t_cell),
            Paragraph("Obligatoire", t_cell_bold)
        ],
        [
            Paragraph("<b>EF11</b>", t_cell_bold),
            Paragraph("<b>Notifications d'Activation & Rappels :</b> Alerte locale lors de l'activation/prolongation de l'abonnement et préavis avant expiration.", t_cell),
            Paragraph("Obligatoire", t_cell_bold)
        ],
        [
            Paragraph("<b>EF12</b>", t_cell_bold),
            Paragraph("<b>Console Super-Administrateur :</b> Supervision du parc d'agents, prolongation manuelle (+7j, +15j, +30j) et suivi des feedbacks.", t_cell),
            Paragraph("Obligatoire", t_cell_bold)
        ],
        [
            Paragraph("<b>EF13</b>", t_cell_bold),
            Paragraph("<b>Anti-Fraude Matérielle (Device ID) :</b> Blocage de la création de multiples comptes d'essai sur un seul et même smartphone.", t_cell),
            Paragraph("Souhaitable", t_cell)
        ],
        [
            Paragraph("<b>EF14</b>", t_cell_bold),
            Paragraph("<b>Contrôle de Version Automatique :</b> Détection des mises à jour disponibles au démarrage avec invitation au téléchargement.", t_cell),
            Paragraph("Souhaitable", t_cell)
        ]
    ]
    t_ef = Table(ef_data, colWidths=[40, 395, 60])
    t_ef.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), C_HEADER_BG),
        ('BOX', (0,0), (-1,-1), 1, C_BORDER),
        ('INNERGRID', (0,0), (-1,-1), 0.5, C_BORDER),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, C_LIGHT_BG])
    ]))
    story.append(t_ef)
    
    story.append(PageBreak())
    
    # 6. EXIGENCES NON FONCTIONNELLES
    story.append(Paragraph("6. Exigences Non Fonctionnelles (*)", h1_style))
    story.append(Paragraph("• <b>Fiabilité & Exactitude Mathématique :</b> Tolérance zéro sur les erreurs de commission. Les règles de tranches sont vérifiées par tests unitaires.", bullet_style))
    story.append(Paragraph("• <b>Résilience Hors-Ligne (Offline-First) :</b> Aucune dépendance réseau pour la saisie quotidienne. Écriture immédiate en base SQLite locale.", bullet_style))
    story.append(Paragraph("• <b>Vitesse & Ergonomie :</b> Temps de chargement de l'interface inférieur à 1 seconde ; calcul de tranche instantané (< 10 ms).", bullet_style))
    story.append(Paragraph("• <b>Confidentialité & Privacy by Design :</b> Étanchéité absolue des données entre agents via les politiques RLS PostgreSQL de Supabase.", bullet_style))
    story.append(Paragraph("• <b>Sécurité des Clés API :</b> Les clés secrètes marchandes SasPay sont cantonnées dans des Edge Functions côté serveur Deno, jamais dans l'APK.", bullet_style))
    story.append(Paragraph("• <b>Sobriété Énergétique & Données :</b> Consommation minimale de forfait Internet (synchronisations légères au format JSON compressé).", bullet_style))
    
    # 7. ARCHITECTURE TECHNIQUE
    story.append(Paragraph("7. Architecture Technique Détaillée", h1_style))
    story.append(Paragraph(
        "L'architecture de Carnet MoMo repose sur un pipeline moderne en 6 couches garantissant autonomie locale et robustesse cloud :",
        body_style
    ))
    story.append(Paragraph("1. <b>Interface Utilisateur (Flutter Mobile) :</b> Interface réactive compilée AOT pour Android, garantissant fluidité et faible consommation mémoire.", bullet_style))
    story.append(Paragraph("2. <b>Moteur Local (SQLite + SharedPreferences) :</b> Base relationnelle embarquée stockant transactions, tranches et paramètres hors-ligne.", bullet_style))
    story.append(Paragraph("3. <b>Service de Synchronisation (SyncService) :</b> Détection automatique de la connectivité et réconciliation bidirectionnelle avec le Cloud.", bullet_style))
    story.append(Paragraph("4. <b>Backend Cloud (Supabase PostgreSQL 15) :</b> Sauvegarde centralisée, authentification sécurisée et réplication temps réel (`RealtimeChannel`).", bullet_style))
    story.append(Paragraph("5. <b>Sécurité SQL (Row Level Security - RLS) :</b> Chaque enregistrement est lié au `auth.uid()` de l'agent. Aucun accès croisé possible.", bullet_style))
    story.append(Paragraph("6. <b>Paiement en Ligne (SasPay Edge Functions) :</b> Déclenchement de checkout externe et activation automatisée de l'abonnement par Webhook.", bullet_style))
    story.append(Spacer(1, 4))
    
    # 8. ÉVALUATION ET CRITÈRES D'ACCEPTATION
    story.append(Paragraph("8. Évaluation & Critères d'Acceptation", h1_style))
    
    eval_data = [
        [Paragraph("Critère", t_header), Paragraph("Méthode de Mesure & Validation", t_header), Paragraph("Objectif Visé", t_header)],
        [
            Paragraph("<b>Précision des Commissions</b>", t_cell_bold),
            Paragraph("Validation contre les grilles tarifaires officielles MTN, Moov, Wave, Celtiis, Orange, T-Money.", t_cell),
            Paragraph("100 % d'exactitude", t_cell_bold)
        ],
        [
            Paragraph("<b>Autonomie Hors-Ligne</b>", t_cell_bold),
            Paragraph("Test de saisie, consultation et archivage avec mode avion activé pendant 48 heures.", t_cell),
            Paragraph("0 perte de données", t_cell_bold)
        ],
        [
            Paragraph("<b>Réconciliation Cloud</b>", t_cell_bold),
            Paragraph("Restauration du compte sur un nouveau téléphone après désinstallation complète.", t_cell),
            Paragraph("Restauration intégrale à 100%", t_cell_bold)
        ],
        [
            Paragraph("<b>Activation SasPay</b>", t_cell_bold),
            Paragraph("Cycle complet de paiement test Mobile Money avec déclenchement du webhook.", t_cell),
            Paragraph("Déblocage instantané (< 5s)", t_cell_bold)
        ],
        [
            Paragraph("<b>Sécurité & Isolation RLS</b>", t_cell_bold),
            Paragraph("Tentative de requête API directe sur l'identifiant d'un agent tiers.", t_cell),
            Paragraph("Rejet 403 / 0 fuite", t_cell_bold)
        ]
    ]
    t_eval = Table(eval_data, colWidths=[130, 245, 120])
    t_eval.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), C_HEADER_BG),
        ('BOX', (0,0), (-1,-1), 1, C_BORDER),
        ('INNERGRID', (0,0), (-1,-1), 0.5, C_BORDER),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, C_LIGHT_BG])
    ]))
    story.append(t_eval)
    
    story.append(PageBreak())
    
    # 9. LIVRABLES
    story.append(Paragraph("9. Livrables du Projet", h1_style))
    story.append(Paragraph("• <b>Application Android Release (APK) :</b> Fichier binaire optimisé `app-release.apk` prêt pour installation directe et déploiement.", bullet_style))
    story.append(Paragraph("• <b>Code Source Complet :</b> Dépôt Git documenté avec structure Clean Architecture (écrans, services, modèles, thèmes).", bullet_style))
    story.append(Paragraph("• <b>Base de Données & Scripts SQL :</b> Schéma de production Supabase, tables relationnelles, déclencheurs et politiques RLS.", bullet_style))
    story.append(Paragraph("• <b>Edge Functions Deno :</b> Fonctions `create-saspay-checkout` et `saspay-webhook` pour le paiement sécurisé.", bullet_style))
    story.append(Paragraph("• <b>Documentation & Cahier des Charges :</b> Le présent document contractuel et technique de référence.", bullet_style))
    
    # 10. PLANNING PRÉVISIONNEL
    story.append(Paragraph("10. Planning Prévisionnel & Jalons", h1_style))
    
    plan_data = [
        [Paragraph("Phase", t_header), Paragraph("Détail des Travaux", t_header), Paragraph("Statut", t_header)],
        [Paragraph("<b>Phase 1</b>", t_cell_bold), Paragraph("Conception UI/UX, modèle SQLite local, moteur de calcul des commissions multi-opérateurs.", t_cell), Paragraph("Terminé ✓", t_cell_bold)],
        [Paragraph("<b>Phase 2</b>", t_cell_bold), Paragraph("Backend Supabase, authentification par téléphone, politique RLS et synchronisation Cloud.", t_cell), Paragraph("Terminé ✓", t_cell_bold)],
        [Paragraph("<b>Phase 3</b>", t_cell_bold), Paragraph("Modules de synthèse financière, génération de bilans PDF haute définition et archivage mensuel.", t_cell), Paragraph("Terminé ✓", t_cell_bold)],
        [Paragraph("<b>Phase 4</b>", t_cell_bold), Paragraph("Passerelle SasPay (800 F), notifications locales d'activation, console Super-Admin et anti-fraude.", t_cell), Paragraph("Terminé ✓", t_cell_bold)],
        [Paragraph("<b>Phase 5</b>", t_cell_bold), Paragraph("Compilation Release APK v1.0, tests de charge, déploiement sur le terrain et suivi des feedbacks.", t_cell), Paragraph("En cours (Actif)", t_cell_bold)]
    ]
    t_plan = Table(plan_data, colWidths=[65, 340, 90])
    t_plan.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), C_HEADER_BG),
        ('BOX', (0,0), (-1,-1), 1, C_BORDER),
        ('INNERGRID', (0,0), (-1,-1), 0.5, C_BORDER),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, C_LIGHT_BG])
    ]))
    story.append(t_plan)
    
    # 11. RISQUES ET MESURES D'ATTÉNUATION
    story.append(Paragraph("11. Gestion des Risques & Mesures d'Atténuation", h1_style))
    
    risk_data = [
        [Paragraph("Risque Identifié", t_header), Paragraph("Mesure d'Atténuation Mise en Œuvre", t_header)],
        [
            Paragraph("<b>Coupure Internet prolongée</b>", t_cell_bold),
            Paragraph("Fonctionnement 100% hors-ligne via SQLite. La synchronisation reprend automatiquement sans intervention dès que le réseau réapparaît.", t_cell)
        ],
        [
            Paragraph("<b>Modification des grilles opérateurs</b>", t_cell_bold),
            Paragraph("Table `commission_tiers` dynamique sur Supabase : mise à jour des barèmes à distance sans exiger de nouvelle version de l'APK.", t_cell)
        ],
        [
            Paragraph("<b>Fraude ou tentative de contournement d'essai</b>", t_cell_bold),
            Paragraph("Verrouillage par empreinte matérielle unique du smartphone (Device ID) et vérification côté serveur Supabase.", t_cell)
        ],
        [
            Paragraph("<b>Échec ou lenteur réseau sur SasPay</b>", t_cell_bold),
            Paragraph("Option de prolongation manuelle exceptionnelle par le Super-Admin (+7j, +15j, +30j) pour débloquer immédiatement un agent.", t_cell)
        ],
        [
            Paragraph("<b>Perte ou vol du smartphone de l'agent</b>", t_cell_bold),
            Paragraph("Protection par code PIN 4 chiffres. Restauration instantanée de l'intégralité des données sur le nouveau téléphone via le compte.", t_cell)
        ]
    ]
    t_risk = Table(risk_data, colWidths=[170, 325])
    t_risk.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), C_HEADER_BG),
        ('BOX', (0,0), (-1,-1), 1, C_BORDER),
        ('INNERGRID', (0,0), (-1,-1), 0.5, C_BORDER),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, C_LIGHT_BG])
    ]))
    story.append(t_risk)
    
    story.append(PageBreak())
    
    # 12. CONTRAINTES
    story.append(Paragraph("12. Contraintes Réglementaires & Techniques", h1_style))
    story.append(Paragraph("• <b>Respect strict des barèmes officiels :</b> Les taux et montants de commissions doivent être conformes aux directives des autorités de régulation (ARCEP) et des opérateurs.", bullet_style))
    story.append(Paragraph("• <b>Protection des données personnelles :</b> Conformité avec les lois sur la protection des données (APDP Bénin) : aucun numéro de client final n'est revendu ou exploité à des fins publicitaires.", bullet_style))
    story.append(Paragraph("• <b>Compatibilité matérielle :</b> Fonctionnement garanti sur les terminaux Android d'entrée de gamme couramment utilisés par les revendeurs (1 Go de RAM).", bullet_style))
    
    # 13. ÉVOLUTIONS FUTURES
    story.append(Paragraph("13. Évolutions Futures & Vision Long Terme", h1_style))
    story.append(Paragraph("• <b>Intégration d'imprimantes thermiques Bluetooth :</b> Sortie automatique de tickets de reçu physiques pour sécuriser le client final lors des retraits importants.", bullet_style))
    story.append(Paragraph("• <b>Lecture intelligente des SMS de confirmation :</b> Reconnaissance automatique par notification des SMS d'opérateurs pour pré-remplir les transactions sans aucune frappe.", bullet_style))
    story.append(Paragraph("• <b>Architecture Multi-Guichets (Master / Sub-agents) :</b> Permettre à un propriétaire de plusieurs points de vente de superviser ses caissiers sur un tableau de bord consolidé.", bullet_style))
    story.append(Paragraph("• <b>Scoring de Crédit & Partenariats Microfinance :</b> Valorisation de l'historique d'activité certifié pour faciliter l'obtention de fonds de roulement auprès d'institutions financières.", bullet_style))
    story.append(Spacer(1, 10))
    
    # 14. VALIDATION & SIGNATURES (Identique au modèle RAG avec les 4 porteurs et l'encadrant)
    story.append(Paragraph("14. Validation & Approbation", h1_style))
    
    val_data = [
        [Paragraph("Rôle", t_header), Paragraph("Nom complet & Prénoms", t_header), Paragraph("Signature & Mention", t_header)],
        [
            Paragraph("<b>Porteur du projet</b>", t_cell_bold),
            Paragraph("<b>BIAHOU Ahossou Junior Marie-Clémenceau</b>", t_cell),
            Paragraph("Concepteur, Développeur & Porteur unique<br/>Approuvé pour conformité technique et produit", t_cell)
        ]
    ]
    t_val = Table(val_data, colWidths=[120, 225, 150])
    t_val.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), C_HEADER_BG),
        ('BOX', (0,0), (-1,-1), 1, C_BORDER),
        ('INNERGRID', (0,0), (-1,-1), 0.5, C_BORDER),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('BACKGROUND', (0,1), (-1,1), colors.white),
    ]))
    story.append(t_val)
    
    # Compilation
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Document généré avec succès : {output_path}")

if __name__ == "__main__":
    out_dir = r"b:\carnet_momo_flutter"
    out_file = os.path.join(out_dir, "Cahier_des_Charges_Carnet_MoMo.pdf")
    generate_cahier_des_charges_rag_style(out_file)
