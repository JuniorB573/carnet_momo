import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Tous les réseaux Mobile Money connus par l'app, tous pays confondus.
/// Chaque réseau est rattaché à un pays via 'country' — c'est ce qui
/// permet de ne proposer à l'agent que les réseaux de son propre pays
/// (voir countriesById / networksForCountry ci-dessous et dans
/// theme/countries.dart).
const List<Map<String, dynamic>> kAllNetworks = [
  // Bénin
  {'id': 'mtn', 'label': 'MTN MoMo', 'color': AppColors.mtn, 'country': 'bj'},
  {'id': 'moov', 'label': 'Moov Money', 'color': AppColors.moov, 'country': 'bj'},
  {'id': 'celtiis', 'label': 'Celtiis Cash', 'color': AppColors.celtiis, 'country': 'bj'},
  // Togo
  {'id': 'tmoney', 'label': 'T-Money', 'color': Color(0xFFF5A623), 'country': 'tg'},
  {'id': 'moov_tg', 'label': 'Moov Money', 'color': AppColors.moov, 'country': 'tg'},
  // Côte d'Ivoire
  {'id': 'orange_ci', 'label': 'Orange Money', 'color': Color(0xFFFF7900), 'country': 'ci'},
  {'id': 'mtn_ci', 'label': 'MTN MoMo', 'color': AppColors.mtn, 'country': 'ci'},
  {'id': 'moov_ci', 'label': 'Moov Money', 'color': AppColors.moov, 'country': 'ci'},
  // Sénégal
  {'id': 'orange_sn', 'label': 'Orange Money', 'color': Color(0xFFFF7900), 'country': 'sn'},
  {'id': 'free_sn', 'label': 'Free Money', 'color': Color(0xFFE30613), 'country': 'sn'},
  // Burkina Faso
  {'id': 'orange_bf', 'label': 'Orange Money', 'color': Color(0xFFFF7900), 'country': 'bf'},
  {'id': 'moov_bf', 'label': 'Moov Money', 'color': AppColors.moov, 'country': 'bf'},
  // Mali
  {'id': 'orange_ml', 'label': 'Orange Money', 'color': Color(0xFFFF7900), 'country': 'ml'},
  {'id': 'malitel', 'label': 'Moov Africa Malitel', 'color': AppColors.moov, 'country': 'ml'},
];

/// Réseaux disponibles pour le pays choisi par l'agent. C'est cette
/// fonction qu'utilisent les écrans de saisie/historique/réglages pour
/// n'afficher que les réseaux pertinents, au lieu d'une liste fixe.
List<Map<String, dynamic>> networksForCountry(String countryId) {
  final list = kAllNetworks.where((n) => n['country'] == countryId).toList();
  return list.isEmpty ? kAllNetworks.where((n) => n['country'] == 'bj').toList() : list;
}

/// Conservé pour compatibilité avec du code existant qui importait encore
/// kNetworks directement : correspond par défaut aux réseaux du Bénin.
/// Les écrans doivent progressivement migrer vers networksForCountry().
const List<Map<String, dynamic>> kNetworks = [
  {'id': 'mtn', 'label': 'MTN MoMo', 'color': AppColors.mtn, 'country': 'bj'},
  {'id': 'moov', 'label': 'Moov Money', 'color': AppColors.moov, 'country': 'bj'},
  {'id': 'celtiis', 'label': 'Celtiis Cash', 'color': AppColors.celtiis, 'country': 'bj'},
];
