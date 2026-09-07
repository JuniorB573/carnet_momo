/// Liste des pays pris en charge par l'app. L'indicatif est utilisé pour
/// pré-remplir automatiquement le numéro de téléphone dès que l'agent
/// choisit son pays, à l'inscription comme dans les Réglages.
const List<Map<String, String>> kCountries = [
  {'id': 'bj', 'name': 'Bénin', 'flag': '🇧🇯', 'indicatif': '+229'},
  {'id': 'tg', 'name': 'Togo', 'flag': '🇹🇬', 'indicatif': '+228'},
  {'id': 'ci', 'name': "Côte d'Ivoire", 'flag': '🇨🇮', 'indicatif': '+225'},
  {'id': 'sn', 'name': 'Sénégal', 'flag': '🇸🇳', 'indicatif': '+221'},
  {'id': 'bf', 'name': 'Burkina Faso', 'flag': '🇧🇫', 'indicatif': '+226'},
  {'id': 'ml', 'name': 'Mali', 'flag': '🇲🇱', 'indicatif': '+223'},
];

Map<String, String> countryById(String id) =>
    kCountries.firstWhere((c) => c['id'] == id, orElse: () => kCountries.first);
