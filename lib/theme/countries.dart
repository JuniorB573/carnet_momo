/// Liste des pays pris en charge par l'app.
/// Chaque pays a son indicatif, son format indicatif, et les longueurs attendues
/// pour le numéro national (après l'indicatif).
/// - Bénin (bj) : 10 chiffres (nouveau plan de numérotation ARCEP ex: 01xxxxxxxx)
/// - Togo (tg) : 8 chiffres
/// - Côte d'Ivoire (ci) : 10 chiffres
/// - Sénégal (sn) : 9 chiffres
/// - Burkina Faso (bf) : 8 chiffres
/// - Mali (ml) : 8 chiffres
const List<Map<String, dynamic>> kCountries = [
  {
    'id': 'bj',
    'name': 'Bénin',
    'flag': '🇧🇯',
    'indicatif': '+229',
    'nationalLengths': [8, 9, 10],
    'placeholder': '+229 01 XX XX XX XX',
    'description': '8 à 10 chiffres après +229 (ex: 01 XX XX XX XX ou XX XX XX XX)',
  },
  {
    'id': 'tg',
    'name': 'Togo',
    'flag': '🇹🇬',
    'indicatif': '+228',
    'nationalLengths': [8],
    'placeholder': '+228 XX XX XX XX',
    'description': '8 chiffres après +228',
  },
  {
    'id': 'ci',
    'name': "Côte d'Ivoire",
    'flag': '🇨🇮',
    'indicatif': '+225',
    'nationalLengths': [10],
    'placeholder': '+225 07 XX XX XX XX',
    'description': '10 chiffres après +225',
  },
  {
    'id': 'sn',
    'name': 'Sénégal',
    'flag': '🇸🇳',
    'indicatif': '+221',
    'nationalLengths': [9],
    'placeholder': '+221 77 XXX XX XX',
    'description': '9 chiffres après +221',
  },
  {
    'id': 'bf',
    'name': 'Burkina Faso',
    'flag': '🇧🇫',
    'indicatif': '+226',
    'nationalLengths': [8],
    'placeholder': '+226 XX XX XX XX',
    'description': '8 chiffres après +226',
  },
  {
    'id': 'ml',
    'name': 'Mali',
    'flag': '🇲🇱',
    'indicatif': '+223',
    'nationalLengths': [8],
    'placeholder': '+223 XX XX XX XX',
    'description': '8 chiffres après +223',
  },
];

Map<String, dynamic> countryById(String id) =>
    kCountries.firstWhere((c) => c['id'] == id, orElse: () => kCountries.first);

/// Détecte automatiquement l'identifiant du pays à partir d'un numéro de téléphone.
String detectCountryIdFromPhone(String rawPhone, {String fallback = 'bj'}) {
  final clean = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
  if (clean.isEmpty) return fallback;

  if (clean.startsWith('229')) return 'bj';
  if (clean.startsWith('228')) return 'tg';
  if (clean.startsWith('225')) return 'ci';
  if (clean.startsWith('221')) return 'sn';
  if (clean.startsWith('226')) return 'bf';
  if (clean.startsWith('223')) return 'ml';

  // Préfixes nationaux caractéristiques
  // 01 au Bénin (ARCEP plan 10 chiffres, ex: 014733535...)
  if (clean.startsWith('01')) return 'bj';
  // 07 ou 05 en Côte d'Ivoire
  if (clean.startsWith('07') || clean.startsWith('05')) return 'ci';

  return fallback;
}

/// Valide le numéro en fonction du pays.
/// Retourne null si valide, ou le message d'erreur si invalide.
String? validatePhoneForCountry(String rawPhone, String countryId, {bool isWhatsApp = false, String lang = 'fr'}) {
  final clean = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
  final country = countryById(countryId);
  final indicatif = (country['indicatif'] as String).replaceAll('+', '');
  final countryName = country['name'] as String;
  final validLengths = (country['nationalLengths'] as List<int>);

  if (clean.isEmpty) {
    return lang == 'en' ? "Please enter a valid phone number." : "Indique un numéro de téléphone valide.";
  }

  String nationalPart = clean;
  if (clean.startsWith(indicatif)) {
    nationalPart = clean.substring(indicatif.length);
  } else if (!validLengths.contains(clean.length)) {
    if (lang == 'en') {
      return isWhatsApp
          ? "The WhatsApp number must start with +$indicatif ($countryName)."
          : "The phone number must start with +$indicatif ($countryName).";
    }
    return isWhatsApp
        ? "Le numéro WhatsApp doit commencer par l'indicatif +$indicatif ($countryName)."
        : "Le numéro doit commencer par l'indicatif +$indicatif ($countryName).";
  }

  if (!validLengths.contains(nationalPart.length)) {
    final expectedStr = validLengths.join(' ou ');
    if (lang == 'en') {
      return isWhatsApp
          ? "WhatsApp number for $countryName must have $expectedStr digits (currently ${nationalPart.length})."
          : "Phone number for $countryName must have $expectedStr digits (currently ${nationalPart.length}).";
    }
    return isWhatsApp
        ? "Le numéro WhatsApp pour le $countryName doit comporter $expectedStr chiffres (actuellement ${nationalPart.length})."
        : "Le numéro pour le $countryName doit comporter $expectedStr chiffres (actuellement ${nationalPart.length}).";
  }

  return null;
}

/// Valide le numéro de l'opération (numéro du client) saisi dans l'onglet Saisie.
/// L'agent peut saisir le numéro avec ou sans l'indicatif (ex: 0196652850 ou +2290196652850).
String? validateOperationNumberForCountry(String rawNumber, String countryId, {String lang = 'fr'}) {
  final clean = rawNumber.replaceAll(RegExp(r'[^\d]'), '');
  final country = countryById(countryId);
  final indicatif = (country['indicatif'] as String).replaceAll('+', '');
  final countryName = country['name'] as String;
  final validLengths = (country['nationalLengths'] as List<int>);

  if (clean.isEmpty) {
    return lang == 'en' ? "Please enter the operation number." : "Indique le numéro de l'opération.";
  }

  // Si l'agent a inclus l'indicatif (ex: 229...)
  String nationalPart = clean;
  if (clean.startsWith(indicatif)) {
    nationalPart = clean.substring(indicatif.length);
  }

  if (!validLengths.contains(nationalPart.length)) {
    final expectedStr = validLengths.join(' ou ');
    if (lang == 'en') {
      return "For $countryName, the client number must have $expectedStr digits (currently ${nationalPart.length}).";
    }
    return "Pour le $countryName, le numéro client doit comporter $expectedStr chiffres (actuellement ${nationalPart.length}).";
  }

  return null;
}

