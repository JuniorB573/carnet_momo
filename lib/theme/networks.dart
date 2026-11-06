import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Tous les réseaux Mobile Money connus par l'app, tous pays confondus.
/// Chaque réseau est rattaché à un pays via 'country' — c'est ce qui
/// permet de ne proposer à l'agent que les réseaux de son propre pays
/// (voir countriesById / networksForCountry ci-dessous et dans
/// theme/countries.dart).
///
/// 'prefixes' : liste des 2 premiers chiffres du numéro national
/// qui appartiennent à ce réseau. Permet de vérifier qu'un numéro
/// client correspond bien au réseau sélectionné.
const List<Map<String, dynamic>> kAllNetworks = [
  // Bénin
  {
    'id': 'mtn',
    'label': 'MTN MoMo',
    'color': AppColors.mtn,
    'country': 'bj',
    // Nouveau plan ARCEP : 01XXXXXXXX → préfixes avec "01" inclus dans les 10 chiffres
    // MTN Bénin (10 chiffres) : 0196, 0197, 0161, 0162, 0167, 0166, 0165, 0163, 0164, 0191, 0192
    // Anciens préfixes 8 chiffres : 96, 97, 61, 62, 67, 66, 65, 63, 64, 91, 92
    'prefixes': ['96', '97', '61', '62', '67', '66', '65', '63', '64', '91', '92',
                 '0196', '0197', '0161', '0162', '0167', '0166', '0165', '0163', '0164', '0191', '0192'],
  },
  {
    'id': 'moov',
    'label': 'Moov Money',
    'color': AppColors.moov,
    'country': 'bj',
    // Moov Bénin : 99, 94, 95, 93, 90, 98, 64 (partagé), 52, 53
    // Nouveaux : 0199, 0194, 0195, 0193, 0190, 0198
    'prefixes': ['99', '94', '95', '93', '90', '98', '52', '53',
                 '0199', '0194', '0195', '0193', '0190', '0198', '0152', '0153'],
  },
  {
    'id': 'celtiis',
    'label': 'Celtiis Cash',
    'color': AppColors.celtiis,
    'country': 'bj',
    // Celtiis Bénin : 98 (partagé avec Moov), 01 (fixe), anciens: 23, 24
    'prefixes': ['23', '24', '0123', '0124'],
  },
  // Togo
  {
    'id': 'tmoney',
    'label': 'T-Money',
    'color': Color(0xFFF5A623),
    'country': 'tg',
    'prefixes': ['90', '91', '92', '93', '70', '71', '72', '79'],
  },
  {
    'id': 'moov_tg',
    'label': 'Moov Money',
    'color': AppColors.moov,
    'country': 'tg',
    'prefixes': ['96', '97', '98', '99', '22', '93'],
  },
  // Côte d'Ivoire
  {
    'id': 'orange_ci',
    'label': 'Orange Money',
    'color': Color(0xFFFF7900),
    'country': 'ci',
    'prefixes': ['07', '08', '09', '0709', '0708'],
  },
  {
    'id': 'mtn_ci',
    'label': 'MTN MoMo',
    'color': AppColors.mtn,
    'country': 'ci',
    'prefixes': ['05', '04', '25', '45', '65', '85'],
  },
  {
    'id': 'moov_ci',
    'label': 'Moov Money',
    'color': AppColors.moov,
    'country': 'ci',
    'prefixes': ['01', '02', '03', '06'],
  },
  // Sénégal
  {
    'id': 'orange_sn',
    'label': 'Orange Money',
    'color': Color(0xFFFF7900),
    'country': 'sn',
    'prefixes': ['77', '78'],
  },
  {
    'id': 'free_sn',
    'label': 'Free Money',
    'color': Color(0xFFE30613),
    'country': 'sn',
    'prefixes': ['76', '70', '75'],
  },
  // Burkina Faso
  {
    'id': 'orange_bf',
    'label': 'Orange Money',
    'color': Color(0xFFFF7900),
    'country': 'bf',
    'prefixes': ['70', '71', '72', '73', '74', '75', '76', '77', '78', '79'],
  },
  {
    'id': 'moov_bf',
    'label': 'Moov Money',
    'color': AppColors.moov,
    'country': 'bf',
    'prefixes': ['60', '61', '62', '63', '64', '65', '66', '67', '68', '69'],
  },
  // Mali
  {
    'id': 'orange_ml',
    'label': 'Orange Money',
    'color': Color(0xFFFF7900),
    'country': 'ml',
    'prefixes': ['70', '72', '73', '74', '75', '76'],
  },
  {
    'id': 'malitel',
    'label': 'Moov Africa Malitel',
    'color': AppColors.moov,
    'country': 'ml',
    'prefixes': ['60', '61', '62', '65', '66', '67', '68', '69', '71', '78', '79'],
  },
];

/// Réseaux disponibles pour le pays choisi par l'agent. C'est cette
/// fonction qu'utilisent les écrans de saisie/historique/réglages pour
/// n'afficher que les réseaux pertinents, au lieu d'une liste fixe.
List<Map<String, dynamic>> networksForCountry(String countryId) {
  final list = kAllNetworks.where((n) => n['country'] == countryId).toList();
  return list.isEmpty ? kAllNetworks.where((n) => n['country'] == 'bj').toList() : list;
}

/// Vérifie si un numéro client appartient au réseau sélectionné.
/// Retourne null si valide (ou si le réseau n'a pas de préfixes configurés),
/// ou le message d'erreur si le numéro n'appartient pas à ce réseau.
String? validatePhoneForNetwork(
  String rawNumber,
  String networkId,
  String countryId, {
  String lang = 'fr',
}) {
  // Trouver le réseau
  final networks = kAllNetworks.where(
    (n) => n['id'] == networkId && n['country'] == countryId,
  ).toList();
  if (networks.isEmpty) return null; // Réseau inconnu → pas de validation

  final network = networks.first;
  final prefixes = network['prefixes'] as List<dynamic>?;
  if (prefixes == null || prefixes.isEmpty) return null; // Pas de préfixes → pas de validation

  final networkLabel = network['label'] as String;

  // Extraire la partie nationale du numéro
  final clean = rawNumber.replaceAll(RegExp(r'[^\d]'), '');
  if (clean.isEmpty) return null;

  // Retirer l'indicatif pays si présent (ex: 229 pour Bénin)
  final List<String> indicatifs = ['229', '228', '225', '221', '226', '223'];
  String national = clean;
  for (final ind in indicatifs) {
    if (clean.startsWith(ind) && clean.length > ind.length) {
      national = clean.substring(ind.length);
      break;
    }
  }

  // Vérifier si le numéro national commence par l'un des préfixes du réseau
  for (final prefix in prefixes) {
    if (national.startsWith(prefix as String)) {
      return null; // Valide !
    }
  }

  // Aucun préfixe correspondant trouvé
  if (lang == 'en') {
    return 'This number does not appear to belong to $networkLabel. Please check the selected network.';
  }
  return 'Ce numéro ne semble pas appartenir à $networkLabel. Vérifie le réseau sélectionné.';
}

/// Conservé pour compatibilité avec du code existant qui importait encore
/// kNetworks directement : correspond par défaut aux réseaux du Bénin.
/// Les écrans doivent progressivement migrer vers networksForCountry().
const List<Map<String, dynamic>> kNetworks = [
  {'id': 'mtn', 'label': 'MTN MoMo', 'color': AppColors.mtn, 'country': 'bj'},
  {'id': 'moov', 'label': 'Moov Money', 'color': AppColors.moov, 'country': 'bj'},
  {'id': 'celtiis', 'label': 'Celtiis Cash', 'color': AppColors.celtiis, 'country': 'bj'},
];
