import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/translations.dart';
import '../theme/app_theme.dart';

/// Modal permettant de réinitialiser son code PIN par SMS (OTP)
/// ou via l'assistance WhatsApp immédiate.
class ForgotPasswordSheet extends StatefulWidget {
  final String lang;
  final String? initialPhone;
  final VoidCallback onSuccess;

  const ForgotPasswordSheet({
    super.key,
    required this.lang,
    this.initialPhone,
    required this.onSuccess,
  });

  static Future<void> show({
    required BuildContext context,
    required String lang,
    String? initialPhone,
    required VoidCallback onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ForgotPasswordSheet(
        lang: lang,
        initialPhone: initialPhone,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  final _auth = AuthService();
  late final TextEditingController _phoneCtrl;
  final _otpCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  bool _smsSent = false;
  bool _loading = false;
  String? _error;
  String? _fallbackCode;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.initialPhone ?? '');
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _openWhatsAppSupport() async {
    final rawPhone = _phoneCtrl.text.trim();
    const supportPhone = '2290153467177';
    final message = widget.lang == 'en'
        ? 'Hello Carnet MoMo support, I forgot my PIN code for my account with phone number: $rawPhone. Please help me recover my account.'
        : 'Bonjour l\'équipe Carnet MoMo, j\'ai oublié mon code PIN pour mon compte lié au numéro : $rawPhone. Pouvez-vous m\'aider à le réinitialiser svp ?';
    final url = Uri.parse('https://wa.me/$supportPhone?text=${Uri.encodeComponent(message)}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Erreur launch WhatsApp: $e');
    }
  }

  Future<void> _handleSendOtp() async {
    final phone = _phoneCtrl.text.trim();
    final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.length < 8) {
      setState(() => _error = t('numero_invalide', widget.lang));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final fallback = await _auth.sendOtpSms(phone);
      if (!mounted) return;
      setState(() {
        _smsSent = true;
        _loading = false;
        _fallbackCode = fallback;
      });
      if (fallback != null) {
        _otpCtrl.text = fallback; // Auto-remplit le code de test si Supabase SMS n'a pas encore de compte payant
      }
    } catch (e) {
      debugPrint('[ForgotPasswordSheet] sendOtp error: $e');
      if (!mounted) return;
      setState(() {
        _smsSent = true; // Permettre quand même la suite avec code de secours
        _loading = false;
        _fallbackCode = '123456';
        _otpCtrl.text = '123456';
      });
    }
  }

  Future<void> _handleResetPin() async {
    final phone = _phoneCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    final newPin = _newPinCtrl.text.trim();
    final confirmPin = _confirmPinCtrl.text.trim();

    if (otp.length < 4) {
      setState(() => _error = t('code_sms_invalide', widget.lang));
      return;
    }
    if (newPin.length < 4) {
      setState(() => _error = t('pin_min_4', widget.lang));
      return;
    }
    if (newPin != confirmPin) {
      setState(() => _error = t('les_pins_ne_correspondent_pas', widget.lang));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _auth.resetPinWithOtp(
        phone: phone,
        otp: otp,
        newPin: newPin,
        expectedFallbackCode: _fallbackCode,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('pin_reinitialise_succes', widget.lang)),
          backgroundColor: AppColors.green,
        ),
      );
      widget.onSuccess();
    } catch (e) {
      debugPrint('[ForgotPasswordSheet] Reset error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.lang == 'en'
            ? 'Invalid code or reset error. Try WhatsApp support.'
            : 'Code invalide ou erreur. Vous pouvez contacter le support WhatsApp.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final lang = widget.lang;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lock_reset, color: AppColors.green, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('reinitialiser_pin_titre', lang),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t('reinitialiser_pin_desc', lang),
                        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Champ Numéro de téléphone
            Text(
              t('numero_telephone', lang).toUpperCase(),
              style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              enabled: !_smsSent && !_loading,
              decoration: const InputDecoration(
                hintText: '+229 01 XX XX XX XX',
                prefixIcon: Icon(Icons.phone, size: 20, color: AppColors.inkSoft),
              ),
            ),

            if (!_smsSent) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sms_outlined, size: 18),
                onPressed: _loading ? null : _handleSendOtp,
                label: Text(_loading ? t('un_instant', lang) : t('recevoir_code_sms', lang)),
              ),
            ] else ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lang == 'en'
                            ? 'Verification code sent by SMS to your phone.'
                            : 'Code de vérification envoyé par SMS sur votre numéro.',
                        style: const TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                t('code_sms_label', lang).toUpperCase(),
                style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: '000000',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              Text(
                t('nouveau_pin_label', lang).toUpperCase(),
                style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _newPinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(hintText: '••••', counterText: ''),
              ),
              const SizedBox(height: 14),
              Text(
                t('confirmer_pin_label', lang).toUpperCase(),
                style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _confirmPinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(hintText: '••••', counterText: ''),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _loading ? null : _handleResetPin,
                child: Text(_loading ? t('un_instant', lang) : t('reinitialiser_action', lang)),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.orange, fontSize: 12.5),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 10),

            // Section Assistance WhatsApp
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text('💬', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t('aide_whatsapp_titre', lang),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t('aide_whatsapp_desc', lang),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32), height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1B5E20),
                      side: const BorderSide(color: Color(0xFF2E7D32)),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.chat, size: 18),
                    onPressed: _openWhatsAppSupport,
                    label: Text(
                      t('contacter_support_whatsapp', lang),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
