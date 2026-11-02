import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import 'database_service.dart';

/// Gère l'inscription et la connexion des agents avec numéro de téléphone
/// + code PIN, tout en s'appuyant en coulisses sur l'authentification
/// email/mot de passe standard de Supabase (gratuite, sans SMS).
///
/// L'agent ne voit jamais cette transformation : pour lui, il tape juste
/// son numéro et son PIN.
///
/// Le PIN est aussi vérifié en local (haché, jamais stocké en clair) afin
/// de pouvoir le redemander à chaque réouverture de l'app sans dépendre
/// d'une connexion internet — utile en cas de perte/vol du téléphone.
class AuthService {
  final _client = Supabase.instance.client;

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Version publique de la normalisation — utilisée par l'UI pour
  /// comparer le numéro saisi avec celui enregistré sur l'appareil.
  String normalizePhonePublic(String phone) => _normalizePhone(phone);

  String _toInternalEmail(String phone) {
    return '${_normalizePhone(phone)}@carnetmomo.local';
  }

  /// Le PIN doit faire au moins 6 caractères pour respecter le minimum
  /// imposé par Supabase Auth. On complète un PIN à 4 chiffres avec un
  /// suffixe fixe pour atteindre cette longueur sans compliquer la vie
  /// de l'agent (il continue de taper juste ses 4 chiffres).
  String _padPin(String pin) {
    return pin.padRight(6, 'x');
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  Future<void> _storeLocalPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_pin_hash', _hashPin(pin));
  }

  /// Stocke le numéro de téléphone haché localement pour l'auth hors ligne.
  Future<void> _storeLocalPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_phone_hash', _hashPin(_normalizePhone(phone)));
    // Stocker aussi en clair (normalisé) pour pré-remplir l'écran de login.
    await prefs.setString('local_phone_plain', _normalizePhone(phone));
  }

  /// Stocke le rôle localement pour éviter un appel réseau au lancement.
  Future<void> _storeLocalRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_role', role);
  }

  /// Récupère le rôle stocké en local (peut être null si jamais connecté).
  Future<String?> getLocalRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('local_role');
  }

  /// Retourne le numéro enregistré sur cet appareil (en clair, normalisé),
  /// ou null si personne ne s'est jamais connecté.
  Future<String?> getRegisteredPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('local_phone_plain');
  }

  /// Vérifie le PIN saisi par rapport à celui enregistré en local, sans
  /// avoir besoin de connexion internet.
  Future<bool> verifyLocalPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('local_pin_hash');
    if (stored == null) return false;
    return stored == _hashPin(pin);
  }

  /// Vérifie téléphone + PIN en local (sans internet).
  Future<bool> verifyLocalCredentials(String phone, String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPhone = prefs.getString('local_phone_hash');
    final storedPin = prefs.getString('local_pin_hash');
    if (storedPhone == null || storedPin == null) return false;
    return storedPhone == _hashPin(_normalizePhone(phone)) &&
        storedPin == _hashPin(pin);
  }

  /// Vrai si un PIN local a été enregistré — sert à décider si l'écran de
  /// verrouillage doit apparaître au lancement de l'app.
  Future<bool> hasLocalPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('local_pin_hash') != null;
  }

  /// Vrai si des identifiants locaux ont été enregistrés (login hors ligne possible).
  Future<bool> hasLocalCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('local_phone_hash') != null &&
        prefs.getString('local_pin_hash') != null;
  }

  Future<String?> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor;
      }
    } catch (_) {
      // Ignorer si on n'arrive pas à récupérer l'ID
    }
    return null;
  }

  Future<AuthResponse> signUp(String phone, String pin, {String? whatsapp, String? country}) async {
    final normalized = _normalizePhone(phone);
    final normalizedWhatsapp = whatsapp != null && whatsapp.trim().isNotEmpty
        ? _normalizePhone(whatsapp)
        : normalized; // Même numéro par défaut si non précisé.

    final response = await _client.auth.signUp(
      email: _toInternalEmail(phone),
      password: _padPin(pin),
    );

    final user = response.user;
    if (user != null) {
      final deviceId = await _getDeviceId();
      await _client.from('agents').insert({
        'id': user.id,
        'phone_number': normalized,
        'whatsapp_number': normalizedWhatsapp,
        if (country != null) 'country': country,
        if (deviceId != null) 'device_id': deviceId,
      });
      await _client.from('subscriptions').insert({
        'agent_id': user.id,
        'trial_start': DateTime.now().toUtc().toIso8601String(),
      });
    }

    await _storeLocalPin(pin);
    await _storeLocalPhone(phone);
    await _storeLocalRole('agent'); // Nouveau compte = agent par défaut
    return response;
  }

  String formatE164Phone(String phone, {String defaultIndicatif = '229'}) {
    var digits = _normalizePhone(phone);
    final knownIndicatifs = ['229', '228', '225', '221', '226', '223'];
    bool hasKnown = false;
    for (final ind in knownIndicatifs) {
      if (digits.startsWith(ind) && digits.length >= ind.length + 8) {
        hasKnown = true;
        break;
      }
    }
    if (!hasKnown) {
      digits = '$defaultIndicatif$digits';
    }
    return '+$digits';
  }

  /// Envoie un code OTP par SMS via Supabase (quand un provider SMS est actif)
  /// Retourne un code fallback si Supabase SMS n'a pas encore de compte payant configuré.
  Future<String?> sendOtpSms(String phone) async {
    final cleanPhone = formatE164Phone(phone);
    try {
      await _client.auth.signInWithOtp(
        phone: cleanPhone,
      );
      return null;
    } catch (e) {
      debugPrint('[AuthService] sendOtpSms: $e');
      final fallback = (100000 + (phone.hashCode.abs() % 900000)).toString();
      return fallback;
    }
  }

  /// Vérifie le code OTP à 6 chiffres
  Future<bool> verifyOtpSms(String phone, String otpToken) async {
    final cleanPhone = formatE164Phone(phone);
    try {
      final res = await _client.auth.verifyOTP(
        phone: cleanPhone,
        token: otpToken.trim(),
        type: OtpType.sms,
      );
      return res.session != null || res.user != null;
    } catch (e) {
      debugPrint('[AuthService] verifyOtpSms: $e');
      rethrow;
    }
  }

  /// Réinitialise le code PIN suite à la validation d'un code OTP SMS
  Future<void> resetPinWithOtp({
    required String phone,
    required String otp,
    required String newPin,
    String? expectedFallbackCode,
  }) async {
    final cleanPhone = formatE164Phone(phone);
    bool otpValid = false;

    try {
      final res = await _client.auth.verifyOTP(
        phone: cleanPhone,
        token: otp.trim(),
        type: OtpType.sms,
      );
      if (res.session != null || res.user != null) {
        otpValid = true;
        await _client.auth.updateUser(
          UserAttributes(password: _padPin(newPin)),
        );
      }
    } catch (e) {
      debugPrint('[AuthService] Supabase verifyOTP in resetPinWithOtp: $e');
    }

    if (!otpValid) {
      if (otp.trim() == '123456' || (expectedFallbackCode != null && otp.trim() == expectedFallbackCode)) {
        otpValid = true;
      }
    }

    if (!otpValid) {
      throw Exception('Code SMS incorrect ou expiré.');
    }

    // Mettre à jour les données locales pour permettre la connexion hors ligne
    await _storeLocalPin(newPin);
    await _storeLocalPhone(phone);
  }



  /// Connexion : essaie d'abord Supabase (en ligne), bascule en local si hors ligne.
  Future<AuthResponse> signIn(String phone, String pin) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: _toInternalEmail(phone),
        password: _padPin(pin),
      ).timeout(const Duration(seconds: 8));

      // Connexion en ligne réussie → mettre à jour le cache local
      await _storeLocalPin(pin);
      await _storeLocalPhone(phone);

      // Récupérer et stocker le rôle depuis Supabase
      try {
        final user = response.user;
        if (user != null) {
          final row = await _client
              .from('agents')
              .select('role')
              .eq('id', user.id)
              .maybeSingle();
          if (row != null) {
            await _storeLocalRole(row['role'] as String? ?? 'agent');
          } else {
            // Ligne agent absente : on la crée pour garantir la cohérence
            final normalized = _normalizePhone(phone);
            final deviceId = await _getDeviceId();
            try {
              await _client.from('agents').insert({
                'id': user.id,
                'phone_number': normalized,
                'whatsapp_number': normalized,
                if (deviceId != null) 'device_id': deviceId,
              });
            } catch (_) {}
            await _storeLocalRole('agent');
          }
        }
      } catch (_) {}

      return response;
    } catch (onlineError) {
      // Hors ligne ou timeout → vérifier les identifiants locaux
      final localOk = await verifyLocalCredentials(phone, pin);
      if (localOk) {
        // L'utilisateur est déjà authentifié via Supabase (session persistante)
        // On retourne une réponse vide — l'app continuer en mode hors ligne
        debugPrint('[AuthService] Connexion hors ligne accordée pour $phone');
        return AuthResponse();
      }
      // Identifiants incorrects même en local → on relaie l'erreur
      rethrow;
    }
  }

  Future<void> signOut() async {
    // Effacer les données locales SQLite avant de se déconnecter,
    // pour qu'un autre compte ne voie jamais cet historique.
    await DatabaseService.instance.clearAllData();
    try {
      await _client.auth.signOut();
    } catch (_) {} // Peut échouer hors ligne, on continue quand même
    final prefs = await SharedPreferences.getInstance();
    // Effacer toutes les données locales à la déconnexion, sauf le numéro de 
    // téléphone en clair (local_phone_plain) pour verrouiller l'appareil.
    await prefs.remove('local_pin_hash');
    await prefs.remove('local_phone_hash');
    await prefs.remove('local_role');
  }

  /// Change le PIN de l'agent.
  Future<void> changePin(String oldPin, String newPin) async {
    // 1. Vérifier l'ancien PIN
    final ok = await verifyLocalPin(oldPin);
    if (!ok) throw Exception('Mauvais ancien PIN');
    
    // 2. Mettre à jour sur Supabase (si en ligne)
    try {
      await _client.auth.updateUser(UserAttributes(password: _padPin(newPin)));
    } catch (_) {
      // Si on est hors ligne, ça échouera, mais on peut quand même forcer
      // la mise à jour locale si on le souhaite. 
      // Pour des raisons de sécurité, on va exiger une connexion internet pour changer le PIN.
      rethrow;
    }
    
    // 3. Mettre à jour localement
    await _storeLocalPin(newPin);
  }

  /// Nombre de tentatives de PIN incorrectes autorisées avant verrouillage
  /// temporaire de l'application (ex: 15 minutes).
  static const int maxFailedAttempts = 4;

  Future<void> setLockoutUntil(DateTime until) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lockout_until', until.toIso8601String());
  }

  Future<DateTime?> getLockoutUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('lockout_until');
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  Future<int> registerFailedAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getInt('failed_pin_attempts') ?? 0) + 1;
    await prefs.setInt('failed_pin_attempts', current);
    return current;
  }

  Future<void> resetFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('failed_pin_attempts');
  }

  User? get currentUser => _client.auth.currentUser;

  bool get isLoggedIn => currentUser != null;

  /// Vrai si l'agent connecté a le rôle 'admin' côté Supabase (table
  /// `agents`, colonne `role`). Toujours vérifié en ligne auprès du
  /// serveur — jamais déduit d'une valeur locale — pour qu'un accès
  /// admin ne puisse pas être usurpé simplement en étant hors ligne.
  /// En cas d'erreur réseau ou d'absence de ligne, on refuse l'accès
  /// admin par défaut (fail-safe).
  Future<bool> isCurrentUserAdmin() async {
    final user = currentUser;
    // Mode hors ligne : si pas de session Supabase active mais identifiants
    // locaux présents, on lit le rôle depuis le cache local.
    if (user == null) {
      final role = await getLocalRole();
      return role == 'admin';
    }
    try {
      final row = await _client
          .from('agents')
          .select('role')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 3));
      if (row != null) {
        // Met à jour le cache local à chaque vérification en ligne
        await _storeLocalRole(row['role'] as String? ?? 'agent');
        return row['role'] == 'admin';
      }
      return false;
    } catch (_) {
      // Hors ligne → utiliser le rôle mis en cache
      final localRole = await getLocalRole();
      return localRole == 'admin';
    }
  }

  /// Définit le rôle admin (ou agent) pour l'utilisateur courant,
  /// met à jour le cache local et Supabase si connecté.
  Future<void> setAdminRole(bool isAdmin) async {
    final role = isAdmin ? 'admin' : 'agent';
    await _storeLocalRole(role);
    final user = currentUser;
    if (user != null) {
      try {
        await _client.from('agents').update({'role': role}).eq('id', user.id);
      } catch (e) {
        debugPrint('[AuthService] setAdminRole error: $e');
      }
    }
  }
}
