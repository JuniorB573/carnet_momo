# -*- coding: utf-8 -*-
"""
Générateur du Cahier des Charges - Carnet MoMo
Design professionnel, soigné, avec palette corporate moderne (Emerald / Dark Slate / Gold).
"""

import os
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfgen import canvas

# Palette de couleurs corporate
C_PRIMARY = colors.HexColor("#0D47A1")      # Bleu roi profond
C_SECONDARY = colors.HexColor("#1B5E20")    # Vert émeraude / MoMo
C_ACCENT = colors.HexColor("#FF8F00")       # Orange chaleureux
C_DARK = colors.HexColor("#1A202C")         # Texte sombre
C_MUTED = colors.HexColor("#718096")        # Gris secondaire
C_LIGHT_BG = colors.HexColor("#F7FAFC")     # Fond de tableau
C_BORDER = colors.HexColor("#E2E8F0")       # Bordure douce
C_HEADER_BG = colors.HexColor("#0F172A")    # Fond entêtes tableau

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
        if self._pageNumber == 1:
            # Page de garde : pas d'entête ni pied de page standard
            return
        
        self.saveState()
        self.setFont("Helvetica", 8)
        self.setFillColor(C_MUTED)
        
        # Entête
        self.drawString(54, 800, "CARNET MOMO — CAHIER DES CHARGES FONCTIONNEL & TECHNIQUE")
        self.setStrokeColor(C_BORDER)
        self.setLineWidth(0.5)
        self.line(54, 792, 541, 792)
        
        # Pied de page
        self.line(54, 45, 541, 45)
        self.drawString(54, 34, "Document Confidentiel — Version 2.1 (Novembre 2026)")
        page_str = f"Page {self._pageNumber} sur {page_count}"
        self.drawRightString(541, 34, page_str)
        self.restoreState()


def create_cahier_des_charges(output_path):
    doc = SimpleDocTemplate(
        output_path,
        pagesize=A4,
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
    )
    
    styles = getSampleStyleSheet()
    
    # Styles personnalisés
    title_style = ParagraphStyle(
        'CoverTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=28,
        leading=34,
        textColor=C_PRIMARY,
        alignment=0
    )
    
    subtitle_style = ParagraphStyle(
        'CoverSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=13,
        leading=18,
        textColor=C_SECONDARY,
        alignment=0
    )
    
    meta_label = ParagraphStyle(
        'MetaLabel',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=9,
        leading=13,
        textColor=C_PRIMARY
    )
    
    meta_val = ParagraphStyle(
        'MetaVal',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=C_DARK
    )
    
    h1_style = ParagraphStyle(
        'Heading1_Custom',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=16,
        leading=22,
        textColor=C_PRIMARY,
        spaceBefore=14,
        spaceAfter=8,
        keepWithNext=True
    )
    
    h2_style = ParagraphStyle(
        'Heading2_Custom',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=12,
        leading=16,
        textColor=C_SECONDARY,
        spaceBefore=10,
        spaceAfter=5,
        keepWithNext=True
    )
    
    body_style = ParagraphStyle(
        'Body_Custom',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9.5,
        leading=14,
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
        leftIndent=15,
        firstLineIndent=-10,
        spaceAfter=3
    )
    
    table_cell = ParagraphStyle(
        'TableCell',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=11,
        textColor=C_DARK
    )
    
    table_cell_bold = ParagraphStyle(
        'TableCellBold',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11,
        textColor=C_DARK
    )
    
    table_header = ParagraphStyle(
        'TableHeader',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11,
        textColor=colors.white
    )
    
    callout_text = ParagraphStyle(
        'CalloutText',
        parent=styles['Normal'],
        fontName='Helvetica-Oblique',
        fontSize=9,
        leading=13,
        textColor=C_DARK
    )
    
    story = []
    
    # ================= PAGE DE GARDE =================
    story.append(Spacer(1, 40))
    story.append(Paragraph("CAHIER DES CHARGES FONCTIONNEL & TECHNIQUE", ParagraphStyle('Badge', fontName='Helvetica-Bold', fontSize=10, textColor=C_SECONDARY, spaceAfter=10)))
    story.append(Paragraph("CARNET MOMO", title_style))
    story.append(Spacer(1, 8))
    story.append(Paragraph("Plateforme mobile & cloud de gestion intégrée des opérations et commissions pour agents de Mobile Money en Afrique de l'Ouest", subtitle_style))
    story.append(Spacer(1, 20))
    story.append(HRFlowable(width="100%", thickness=3, color=C_PRIMARY, spaceAfter=30))
    
    # Boîte de métadonnées de couverture
    meta_data = [
        [Paragraph("Projet :", meta_label), Paragraph("Carnet MoMo (Android & Cloud)", meta_val), Paragraph("Version :", meta_label), Paragraph("2.1.0 — Production", meta_val)],
        [Paragraph("Statut :", meta_label), Paragraph("Validé & En exploitation", meta_val), Paragraph("Date :", meta_label), Paragraph("Novembre 2026", meta_val)],
        [Paragraph("Périmètre géographique :", meta_label), Paragraph("Bénin, Togo, Côte d'Ivoire, Sénégal, Burkina Faso, Mali", meta_val), Paragraph("Sécurité :", meta_label), Paragraph("Chiffrement PIN + RLS Supabase", meta_val)],
        [Paragraph("Modèle économique :", meta_label), Paragraph("Essai 7j + Abonnement 800 F CFA/mois", meta_val), Paragraph("Paiement & Gestion :", meta_label), Paragraph("SasPay + Espace Multi-Kiosques", meta_val)]
    ]
    t_meta = Table(meta_data, colWidths=[100, 150, 80, 157])
    t_meta.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), C_LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 1, C_BORDER),
        ('INNERGRID', (0,0), (-1,-1), 0.5, C_BORDER),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(t_meta)
    
    story.append(Spacer(1, 40))
    
    # Résumé exécutif encadré
    resume_box = [
        [Paragraph("<b>RÉSUMÉ EXÉCUTIF DU PROJET</b>", ParagraphStyle('HRes', fontName='Helvetica-Bold', fontSize=10, textColor=C_PRIMARY))],
        [Paragraph(
            "Le <b>Carnet MoMo</b> est une solution applicative tout-en-un conçue pour numériser, fiabiliser et professionnaliser l'activité quotidienne des agents et points de vente Mobile Money (MTN MoMo, Moov Money, Orange Money, Wave, Celtiis Cash, etc.). "
            "L'application élimine définitivement les erreurs de calcul manuel des commissions grâce à une grille tarifaire dynamique par paliers, offre un suivi journalier et mensuel étanche (séparation dépôts / retraits), assure la continuité hors-ligne avec synchronisation cloud sécurisée, et intègre un modèle d'abonnement automatisé à 800 F CFA / mois après 7 jours d'essai.",
            callout_text
        )]
    ]
    t_resume = Table(resume_box, colWidths=[487])
    t_resume.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#EFF6FF")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#BFDBFE")),
        ('LEFTPADDING', (0,0), (-1,-1), 12),
        ('RIGHTPADDING', (0,0), (-1,-1), 12),
        ('TOPPADDING', (0,0), (-1,-1), 10),
        ('BOTTOMPADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(t_resume)
    
    story.append(PageBreak())
    
    # ================= SOMMAIRE / TABLE DES MATIERES =================
    story.append(Paragraph("TABLE DES MATIÈRES", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=C_PRIMARY, spaceAfter=15))
    
    toc_data = [
        [Paragraph("<b>1. Contexte & Objectifs Stratégiques</b>", table_cell_bold), Paragraph("Page 3", table_cell)],
        [Paragraph("<b>2. Acteurs & Profils Utilisateurs</b>", table_cell_bold), Paragraph("Page 3", table_cell)],
        [Paragraph("<b>3. Architecture & Spécifications Techniques</b>", table_cell_bold), Paragraph("Page 4", table_cell)],
        [Paragraph("<b>4. Modules Fonctionnels Détaillés</b>", table_cell_bold), Paragraph("Page 5", table_cell)],
        [Paragraph("   4.1 Authentification, Code PIN & Anti-Fraude Appareil", table_cell), Paragraph("Page 5", table_cell)],
        [Paragraph("   4.2 Moteur de Saisie & Calcul Automatique des Commissions", table_cell), Paragraph("Page 5", table_cell)],
        [Paragraph("   4.3 Historique, Journal d'Audit & Correction d'Opérations", table_cell), Paragraph("Page 6", table_cell)],
        [Paragraph("   4.4 Synthèse en Direct & Export PDF / Excel des Rapports", table_cell), Paragraph("Page 6", table_cell)],
        [Paragraph("   4.5 Gestion des Archives Mensuelles Indépendantes", table_cell), Paragraph("Page 7", table_cell)],
        [Paragraph("   4.6 Modèle d'Abonnement (SasPay 800 F) & Notifications Locales", table_cell), Paragraph("Page 7", table_cell)],
        [Paragraph("   4.7 Espace Super-Admin & Supervision Globale", table_cell), Paragraph("Page 8", table_cell)],
        [Paragraph("<b>5. Sécurité, RLS & Continuité Hors-Ligne (Offline-First)</b>", table_cell_bold), Paragraph("Page 9", table_cell)],
        [Paragraph("<b>6. Plan de Déploiement & Maintenance Évolutive</b>", table_cell_bold), Paragraph("Page 10", table_cell)],
    ]
    t_toc = Table(toc_data, colWidths=[400, 87])
    t_toc.setStyle(TableStyle([
        ('LINEBELOW', (0,0), (-1,-1), 0.5, C_BORDER),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(t_toc)
    story.append(PageBreak())
    
    # ================= SECTION 1 & 2 =================
    story.append(Paragraph("1. Contexte & Objectifs Stratégiques", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=C_PRIMARY, spaceAfter=10))
    story.append(Paragraph(
        "En Afrique de l'Ouest (Bénin, Togo, Côte d'Ivoire, Sénégal), les agents de proximité Mobile Money constituent l'épine dorsale de l'inclusion financière. "
        "Pourtant, la vaste majorité gère encore ses flux financiers sur des carnets physiques papier ou des registres informels. "
        "Cette gestion archaïque engendre des pertes financières substantielles (mauvais calcul des commissions par tranches, oublis d'enregistrement, vols ou erreurs de caisse).",
        body_style
    ))
    story.append(Paragraph(
        "<b>Objectifs clés du projet Carnet MoMo :</b>", body_style
    ))
    story.append(Paragraph("• <b>Calcul automatique et infaillible des commissions</b> selon les grilles officielles de chaque opérateur et pays.", bullet_style))
    story.append(Paragraph("• <b>Séparation comptable stricte</b> entre Dépôts (sorties d'UV) et Retraits (entrées d'UV/espèces).", bullet_style))
    story.append(Paragraph("• <b>Fonctionnement Offline-First</b> garantissant l'enregistrement même sans réseau Internet sur le terrain.", bullet_style))
    story.append(Paragraph("• <b>Génération instantanée de rapports d'activité</b> au format PDF professionnel et feuille de calcul.", bullet_style))
    story.append(Paragraph("• <b>Rentabilité pérenne</b> via un micro-abonnement mensuel de 800 F CFA démarrant après 7 jours d'essai gratuit.", bullet_style))
    
    story.append(Spacer(1, 10))
    story.append(Paragraph("2. Acteurs & Profils Utilisateurs", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=C_PRIMARY, spaceAfter=10))
    
    acteurs_data = [
        [Paragraph("Rôle", table_header), Paragraph("Profil & Responsabilités", table_header), Paragraph("Périmètre d'Accès", table_header)],
        [
            Paragraph("<b>Agent MoMo (Utilisateur Standard)</b>", table_cell_bold),
            Paragraph("Gérant de point de vente ou caissier. Saisit les dépôts et retraits, consulte ses commissions en direct, exporte ses rapports et gère son abonnement.", table_cell),
            Paragraph("Application mobile personnelle, données strictement isolées par RLS.", table_cell)
        ],
        [
            Paragraph("<b>Super-Administrateur</b>", table_cell_bold),
            Paragraph("Gestionnaire de la plateforme. Supervise les statistiques globales d'activité, le parc d'agents, prolonge manuellement les abonnements et consulte les retours d'expérience.", table_cell),
            Paragraph("Tableau de bord Admin sécurisé dédié, accès analytique consolidé.", table_cell)
        ],
        [
            Paragraph("<b>Passerelle SasPay (Système Tiers)</b>", table_cell_bold),
            Paragraph("Passerelle de paiement Mobile Money & carte bancaire traitant les transactions d'abonnement de 800 F CFA.", table_cell),
            Paragraph("Edge Functions Supabase sécurisées (Signature & Webhook).", table_cell)
        ]
    ]
    t_acteurs = Table(acteurs_data, colWidths=[120, 240, 127])
    t_acteurs.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), C_HEADER_BG),
        ('BOX', (0,0), (-1,-1), 1, C_BORDER),
        ('INNERGRID', (0,0), (-1,-1), 0.5, C_BORDER),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, C_LIGHT_BG])
    ]))
    story.append(t_acteurs)
    
    story.append(PageBreak())
    
    # ================= SECTION 3 : ARCHITECTURE TECHNIQUE =================
    story.append(Paragraph("3. Architecture & Spécifications Techniques", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=C_PRIMARY, spaceAfter=10))
    story.append(Paragraph(
        "L'application repose sur une architecture hybride moderne combinant la puissance native d'un moteur mobile cross-platform avec un backend Cloud temps réel haute disponibilité.",
        body_style
    ))
    
    tech_data = [
        [Paragraph("Composant", table_header), Paragraph("Technologies Utilisées", table_header), Paragraph("Rôle & Justification", table_header)],
        [
            Paragraph("<b>Framework Mobile</b>", table_cell_bold),
            Paragraph("Flutter 3.x / Dart (Android / iOS)", table_cell),
            Paragraph("Performance native 60fps, compilation AOT, rendu graphique cohérent multi-écrans.", table_cell)
        ],
        [
            Paragraph("<b>Stockage Local</b>", table_cell_bold),
            Paragraph("SQLite (sqflite) + SharedPreferences", table_cell),
            Paragraph("Fonctionnement 100% hors-ligne. Les opérations sont stockées localement sans latence.", table_cell)
        ],
        [
            Paragraph("<b>Backend Cloud & DB</b>", table_cell_bold),
            Paragraph("Supabase (PostgreSQL 15, Auth, Realtime, Edge Functions Deno)", table_cell),
            Paragraph("Sauvegarde automatique, authentification téléphonique sécurisée, notifications temps réel.", table_cell)
        ],
        [
            Paragraph("<b>Sécurité & RLS</b>", table_cell_bold),
            Paragraph("Row Level Security (RLS) PostgreSQL", table_cell),
            Paragraph("Étanchéité cryptographique totale : aucun agent ne peut lire ou modifier les données d'un tiers.", table_cell)
        ],
        [
            Paragraph("<b>Notifications</b>", table_cell_bold),
            Paragraph("flutter_local_notifications", table_cell),
            Paragraph("Alertes d'abonnement et confirmations d'activation fiables, sans dépendance lourde à FCM.", table_cell)
        ],
        [
            Paragraph("<b>Génération Documentaire</b>", table_cell_bold),
            Paragraph("Package Dart 'pdf' + printing", table_cell),
            Paragraph("Génération côté client de bilans PDF complets aux normes comptables sans appel serveur.", table_cell)
        ],
        [
            Paragraph("<b>Paiement en Ligne</b>", table_cell_bold),
            Paragraph("SasPay API REST v1 (XOF / Mobile Money)", table_cell),
            Paragraph("Paiement instantané des 800 F CFA d'abonnement avec callback webhook sécurisé.", table_cell)
        ]
    ]
    t_tech = Table(tech_data, colWidths=[110, 160, 217])
    t_tech.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), C_HEADER_BG),
        ('BOX', (0,0), (-1,-1), 1, C_BORDER),
        ('INNERGRID', (0,0), (-1,-1), 0.5, C_BORDER),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, C_LIGHT_BG])
    ]))
    story.append(t_tech)
    
    story.append(Spacer(1, 12))
    story.append(Paragraph("3.1 Matrice des Réseaux & Pays Pris en Charge", h2_style))
    story.append(Paragraph(
        "L'application intègre nativement les configurations réseau et grilles de commission par pays :",
        body_style
    ))
    
    pays_data = [
        [Paragraph("Pays", table_header), Paragraph("Code ISO & Devise", table_header), Paragraph("Réseaux Mobile Money Déployés", table_header)],
        [Paragraph("<b>Bénin 🇧🇯</b>", table_cell_bold), Paragraph("BJ · FCFA (XOF)", table_cell), Paragraph("MTN Mobile Money, Moov Money Bénin, Celtiis Cash", table_cell)],
        [Paragraph("<b>Togo 🇹🇬</b>", table_cell_bold), Paragraph("TG · FCFA (XOF)", table_cell), Paragraph("T-Money (Togocom), Moov Money Togo", table_cell)],
        [Paragraph("<b>Côte d'Ivoire 🇨🇮</b>", table_cell_bold), Paragraph("CI · FCFA (XOF)", table_cell), Paragraph("Orange Money CI, MTN MoMo CI, Moov Money CI, Wave CI", table_cell)],
        [Paragraph("<b>Sénégal 🇸🇳</b>", table_cell_bold), Paragraph("SN · FCFA (XOF)", table_cell), Paragraph("Orange Money SN, Wave Sénégal, Free Money", table_cell)],
        [Paragraph("<b>Burkina Faso 🇧🇫</b>", table_cell_bold), Paragraph("BF · FCFA (XOF)", table_cell), Paragraph("Orange Money BF, Moov Money Burkina", table_cell)],
        [Paragraph("<b>Mali 🇲🇱</b>", table_cell_bold), Paragraph("ML · FCFA (XOF)", table_cell), Paragraph("Orange Money Mali, Moov Africa Malitel", table_cell)]
    ]
    t_pays = Table(pays_data, colWidths=[100, 110, 277])
    t_pays.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), C_HEADER_BG),
        ('BOX', (0,0), (-1,-1), 1, C_BORDER),
        ('INNERGRID', (0,0), (-1,-1), 0.5, C_BORDER),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, C_LIGHT_BG])
    ]))
    story.append(t_pays)
    
    story.append(PageBreak())
    
    # ================= SECTION 4 : MODULES FONCTIONNELS =================
    story.append(Paragraph("4. Modules Fonctionnels Détaillés", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=C_PRIMARY, spaceAfter=10))
    
    story.append(Paragraph("4.1 Authentification, Code PIN & Anti-Fraude Appareil", h2_style))
    story.append(Paragraph(
        "• <b>Connexion & Inscription par Téléphone</b> : Authentification via le numéro de téléphone de l'agent sans mot de passe complexe inutile.",
        bullet_style
    ))
    story.append(Paragraph(
        "• <b>Verrouillage par Code PIN à 4 Chiffres</b> : Clavier numérique sécurisé sur mesure pour déverrouiller l'application à chaque lancement.",
        bullet_style
    ))
    story.append(Paragraph(
        "• <b>Modification du PIN</b> : Écran sécurisé avec saisie de l'ancien code, du nouveau code et confirmation.",
        bullet_style
    ))
    story.append(Paragraph(
        "• <b>Protection Anti-Fraude Monoposte</b> : Détection de l'identifiant matériel de l'appareil (Device ID). Un agent ne peut pas créer plusieurs comptes sur le même smartphone pour contourner l'essai gratuit.",
        bullet_style
    ))
    
    story.append(Spacer(1, 8))
    story.append(Paragraph("4.2 Moteur de Saisie & Calcul Automatique des Commissions", h2_style))
    story.append(Paragraph(
        "• <b>Saisie Ultra-Rapide</b> : Conçue pour les guichets à forte affluence. Sélection rapide du réseau, bascule Dépôt / Retrait en 1 clic.",
        bullet_style
    ))
    story.append(Paragraph(
        "• <b>Moteur de Tranches Dynamique</b> : Dès que le montant est tapé, l'application recherche instantanément la commission exacte correspondante dans la grille tarifaire active.",
        bullet_style
    ))
    story.append(Paragraph(
        "• <b>Gestion Hors Grille</b> : Si un montant exceptionnel ne correspond à aucun palier prédéfini, un champ permet la saisie manuelle d'une commission ajustée.",
        bullet_style
    ))
    story.append(Paragraph(
        "• <b>Confirmation Visuelle & Sonore</b> : Affichage instantané du badge de succès et notification locale confirmant l'enregistrement de l'opération.",
        bullet_style
    ))
    
    story.append(Spacer(1, 8))
    story.append(Paragraph("4.3 Historique, Journal d'Audit & Correction d'Opérations", h2_style))
    story.append(Paragraph(
        "• <b>Journal Chronologique Étanche</b> : Liste ordonnée de toutes les opérations de la journée avec heure, montant, commission générée et type.",
        bullet_style
    ))
    story.append(Paragraph(
        "• <b>Filtres Multi-Critères</b> : Filtrage instantané par réseau (ex : MTN uniquement) et par sens de transaction (Dépôts / Retraits).",
        bullet_style
    ))
    story.append(Paragraph(
        "• <b>Correction & Droit à l'Erreur</b> : Possibilité de corriger un montant saisi par mégarde ou de supprimer une transaction erronée avec confirmation explicite.",
        bullet_style
    ))
    
    story.append(Spacer(1, 8))
    story.append(Paragraph("4.4 Synthèse en Direct & Export PDF / Excel des Rapports", h2_style))
    story.append(Paragraph(
        "• <b>Tableau de Bord 'Aujourd'hui' & 'Ce mois'</b> : Calcul en temps réel du volume total traité et de la commission nette perçue par l'agent, avec sous-totaux par opérateur.",
        bullet_style
    ))
    story.append(Paragraph(
        "• <b>Génération PDF Haute Définition</b> : Export d'une fiche récapitulative professionnelle prête à être imprimée ou transmise à un supérieur.",
        bullet_style
    ))
    story.append(Paragraph(
        "• <b>Export Tableur CSV / Excel</b> : Exportation brute des données pour archivage ou audit comptable approfondi.",
        bullet_style
    ))
    
    story.append(PageBreak())
    
    # ================= SECTION 4 (SUITE) =================
    story.append(Paragraph("4.5 Gestion des Archives Mensuelles Indépendantes", h2_style))
    story.append(Paragraph(
        "• <b>Dossier Dédié par Mois</b> : À la fin de chaque mois, les opérations sont automatiquement consolidées dans un dossier mensuel figé (ex : Septembre 2026, Octobre 2026).",
        bullet_style
    ))
    story.append(Paragraph(
        "• <b>Consultation Rétrospective</b> : L'agent peut rouvrir à tout moment n'importe quel mois passé, examiner le détail des journées et réexporter le PDF du mois concerné.",
        bullet_style
    ))
    story.append(Paragraph(
        "• <b>Préservation de l'Historique</b> : Même après réinstallation de l'application, les archives mensuelles sont restaurées depuis le Cloud.",
        bullet_style
    ))
    
    story.append(Spacer(1, 10))
    story.append(Paragraph("4.6 Modèle d'Abonnement (SasPay 800 F CFA) & Notifications Locales", h2_style))
    story.append(Paragraph(
        "Le modèle d'accès a été spécialement calibré pour maximiser l'adoption tout en garantissant un revenu récurrent :",
        body_style
    ))
    
    abo_table_data = [
        [Paragraph("Paramètre", table_header), Paragraph("Spécification Technique & Fonctionnelle", table_header)],
        [Paragraph("<b>Essai Gratuit</b>", table_cell_bold), Paragraph("<b>7 jours offerts</b> dès la création du compte. Accès complet sans restriction.", table_cell)],
        [Paragraph("<b>Tarif Mensuel</b>", table_cell_bold), Paragraph("<b>800 F CFA / mois</b> (au lieu de 1 000 F CFA précédemment).", table_cell)],
        [Paragraph("<b>Passerelle de Paiement</b>", table_cell_bold), Paragraph("<b>SasPay</b> (Mobile Money MTN/Moov/Orange/Wave et Cartes). Déclenché via Edge Function.", table_cell)],
        [Paragraph("<b>Activation Automatique</b>", table_cell_bold), Paragraph("Dès confirmation SasPay, le webhook met à jour <code>paid_until</code> (+30 jours). Déblocage instantané via <code>ValueNotifier</code> et synchronisation forcée (zéro redémarrage requis).", table_cell)],
        [Paragraph("<b>Prolongation Manuelle</b>", table_cell_bold), Paragraph("Le Super-Admin peut accorder +7, +15 ou +30 jours d'office depuis son tableau de bord.", table_cell)],
        [Paragraph("<b>Notifications d'Activation</b>", table_cell_bold), Paragraph("Notification locale instantanée : <i>'🎉 Abonnement activé ! Vous pouvez continuer à travailler.'</i>", table_cell)],
        [Paragraph("<b>Gestion du Verrouillage</b>", table_cell_bold), Paragraph("Écran <code>_ExpiredGate</code> avec cadenas bloquant les saisies à l'expiration, laissant l'accès aux réglages.", table_cell)],
        [Paragraph("<b>Alignement Fuseau Horaire</b>", table_cell_bold), Paragraph("Stockage serveur UTC, conversion automatique <code>.toLocal()</code> pour la date d'échéance de l'agent.", table_cell)]
    ]
    t_abo = Table(abo_table_data, colWidths=[150, 337])
    t_abo.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), C_HEADER_BG),
        ('BOX', (0,0), (-1,-1), 1, C_BORDER),
        ('INNERGRID', (0,0), (-1,-1), 0.5, C_BORDER),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, C_LIGHT_BG])
    ]))
    story.append(t_abo)
    
    story.append(Spacer(1, 10))
    story.append(Paragraph("4.7 Espace Propriétaire / Patron & Supervision Multi-Kiosques", h2_style))
    story.append(Paragraph(
        "• <b>Liaison Sécurisée Patron ↔ Agents</b> : L'agent génère un code d'accès confidentiel à 6 chiffres depuis ses Réglages (régénérable en 1 clic pour révoquer un accès). Le propriétaire renseigne ce code et le numéro pour lier le kiosque à son tableau de bord.",
        bullet_style
    ))
    story.append(Paragraph(
        "• <b>Normalisation Intelligente des Numéros</b> : Prise en charge automatique des formats internationaux E.164 (+229, +228, +225, +221, +226, +223) et des numéros locaux (01XXXXXXXX, 8 ou 10 chiffres selon les pays).",
        bullet_style
    ))
    story.append(Paragraph(
        "• <b>Monitoring Financier en Temps Réel</b> : Vue consolidée par kiosque (dépôts, retraits, volume total, commissions nettes perçues) avec filtrage par période (aujourd'hui, semaine, mois).",
        bullet_style
    ))
    story.append(Paragraph(
        "• <b>Synchronisation Cloud & Cache Hors-Ligne</b> : Enregistrement sur la table <code>owner_kiosks</code> avec réplication locale SQLite/SharedPreferences garantissant la consultation même sans réseau.",
        bullet_style
    ))
    story.append(Paragraph(
        "• <b>Export PDF Fiche Kiosque Dédiée</b> : Possibilité pour le patron de générer et partager via WhatsApp le bilan financier certifié de chaque agent.",
        bullet_style
    ))
    
    story.append(Spacer(1, 10))
    story.append(Paragraph("4.8 Espace Super-Admin & Supervision Globale", h2_style))
    story.append(Paragraph(
        "• <b>Vue d'Ensemble du Parc d'Agents</b> : Tableau consolidé recensant tous les agents inscrits, leur pays, statut d'abonnement et date d'expiration.",
        bullet_style
    ))
    story.append(Paragraph(
        "• <b>Statistiques Financières Globales</b> : Cumul du volume de transactions et des commissions générées sur l'ensemble du réseau d'agents.",
        bullet_style
    ))
    story.append(Paragraph(
        "• <b>Fiche Détail Agent</b> : Inspection approfondie de l'historique d'un agent donné, bouton de prolongation d'abonnement en 1 clic et suppression de compte si nécessaire.",
        bullet_style
    ))
    story.append(Paragraph(
        "• <b>Module Retours d'Expérience (Feedbacks)</b> : Collecte des notes étoilées et avis des agents pour le pilotage de l'amélioration continue.",
        bullet_style
    ))
    
    story.append(PageBreak())
    
    # ================= SECTION 5 & 6 =================
    story.append(Paragraph("5. Sécurité, RLS & Continuité Hors-Ligne (Offline-First)", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=C_PRIMARY, spaceAfter=10))
    
    secu_data = [
        [Paragraph("Domaine", table_header), Paragraph("Dispositif Mis en Place", table_header), Paragraph("Garantie de Sécurité", table_header)],
        [
            Paragraph("<b>Cloisonnement Données</b>", table_cell_bold),
            Paragraph("PostgreSQL Row Level Security (RLS) sur les tables <code>transactions</code>, <code>commission_tiers</code>, <code>subscriptions</code>.", table_cell),
            Paragraph("Étanchéité mathématique garantie au niveau moteur SQL. Impossible de requêter les données d'un autre agent.", table_cell)
        ],
        [
            Paragraph("<b>Stockage Local Sécurisé</b>", table_cell_bold),
            Paragraph("Base SQLite sandboxée Android, hachage SHA-256 du code PIN.", table_cell),
            Paragraph("Aucune fuite possible en cas de perte ou consultation physique du téléphone déverrouillé.", table_cell)
        ],
        [
            Paragraph("<b>Résilience Hors-Ligne</b>", table_cell_bold),
            Paragraph("Pattern 'Offline-First' : écriture locale immédiate, file d'attente de synchronisation et réconciliation automatique.", table_cell),
            Paragraph("L'agent travaille sans interruption même dans les zones rurales à connectivité instable.", table_cell)
        ],
        [
            Paragraph("<b>Paiement Sécurisé</b>", table_cell_bold),
            Paragraph("Edge Function Supabase faisant office de proxy sécurisé vers SasPay. Clé secrète jamais embarquée dans l'APK.", table_cell),
            Paragraph("Zéro risque de rétro-ingénierie des clés API marchandes.", table_cell)
        ]
    ]
    t_secu = Table(secu_data, colWidths=[110, 190, 187])
    t_secu.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), C_HEADER_BG),
        ('BOX', (0,0), (-1,-1), 1, C_BORDER),
        ('INNERGRID', (0,0), (-1,-1), 0.5, C_BORDER),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, C_LIGHT_BG])
    ]))
    story.append(t_secu)
    
    story.append(Spacer(1, 14))
    story.append(Paragraph("6. Plan de Déploiement & Maintenance Évolutive", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=C_PRIMARY, spaceAfter=10))
    
    story.append(Paragraph(
        "<b>Phase 1 : Déploiement Actuel (Version 2.1 - Stabilisée)</b>", body_style
    ))
    story.append(Paragraph("• Application Android release compilée et prête pour distribution directe (APK) ou Play Store.", bullet_style))
    story.append(Paragraph("• Base de données Supabase de production avec politiques RLS et fonctions Edge actives.", bullet_style))
    story.append(Paragraph("• Système d'alerte de mise à jour intégré (vérification automatique de version avec invite de téléchargement).", bullet_style))
    
    story.append(Spacer(1, 6))
    story.append(Paragraph(
        "<b>Phase 2 : Perspectives Évolutives Recommandées</b>", body_style
    ))
    story.append(Paragraph("• <b>Support multi-caisses / multi-guichets</b> : Permettre à un propriétaire de point de vente d'avoir plusieurs téléphones synchronisés sur une même caisse.", bullet_style))
    story.append(Paragraph("• <b>Rapprochement bancaire automatisé</b> : Scan ou lecture par notification SMS des messages d'opérateurs pour pré-remplir les transactions.", bullet_style))
    story.append(Paragraph("• <b>Intégration d'imprimantes thermiques Bluetooth</b> : Impression immédiate de reçus clients à chaque dépôt/retrait.", bullet_style))
    
    story.append(Spacer(1, 20))
    # Signature / Validation
    sign_box = [
        [Paragraph("<b>Validation de la Spécification :</b>", table_cell_bold), Paragraph("<b>Équipe Technique & Produit :</b>", table_cell_bold)],
        [Paragraph("Direction de Projet Carnet MoMo<br/>Approuvé pour conformité fonctionnelle & technique", table_cell), Paragraph("Lead Developer & Architecte Solutions Mobile<br/>Version APK 2.1.0 prête pour diffusion", table_cell)]
    ]
    t_sign = Table(sign_box, colWidths=[240, 247])
    t_sign.setStyle(TableStyle([
        ('BOX', (0,0), (-1,-1), 1, C_BORDER),
        ('BACKGROUND', (0,0), (-1,-1), C_LIGHT_BG),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(t_sign)
    
    # Construction du document avec le NumberedCanvas
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Cahier des charges généré avec succès : {output_path}")

if __name__ == "__main__":
    out_dir = r"b:\carnet_momo_flutter"
    out_file = os.path.join(out_dir, "Cahier_des_Charges_Carnet_MoMo.pdf")
    create_cahier_des_charges(out_file)
