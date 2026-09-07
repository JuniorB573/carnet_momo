import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pays choisi par l'agent (Bénin par défaut). Détermine à la fois
/// l'indicatif téléphonique proposé et la liste des réseaux Mobile Money
/// affichés dans toute l'application (voir theme/networks.dart).
class CountryController extends ValueNotifier<String> {
  CountryController() : super('bj') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getString('country') ?? 'bj';
  }

  Future<void> setCountry(String id) async {
    value = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('country', id);

    // Répercuté sur Supabase (table `agents`) pour que le pays de chaque
    // agent reste visible côté tableau de bord admin, y compris quand
    // l'agent le change plus tard depuis les Réglages. Best-effort : si
    // hors ligne, l'agent continue de travailler normalement, la
    // synchronisation se refera au prochain changement de pays.
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.from('agents').update({'country': id}).eq('id', user.id);
      } catch (_) {}
    }
  }
}
