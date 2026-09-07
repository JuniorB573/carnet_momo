import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/country_controller.dart';
import '../services/translations.dart';
import 'admin_dashboard_screen.dart';
import 'home_shell.dart';

/// Point d'entrée après connexion : vérifie le rôle de l'agent connecté
/// auprès de Supabase (jamais en local, voir AuthService.isCurrentUserAdmin)
/// et affiche le tableau de bord admin ou l'app normale en conséquence.
class RoleGate extends StatefulWidget {
  final LanguageController languageController;
  final CountryController countryController;
  final VoidCallback onSignOut;
  const RoleGate({
    super.key,
    required this.languageController,
    required this.countryController,
    required this.onSignOut,
  });

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  final _auth = AuthService();
  bool _loading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final isAdmin = await _auth.isCurrentUserAdmin();
    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isAdmin) {
      return AdminDashboardScreen(
        languageController: widget.languageController,
        countryController: widget.countryController,
        onSignOut: widget.onSignOut,
      );
    }
    return HomeShell(
      languageController: widget.languageController,
      countryController: widget.countryController,
    );
  }
}
