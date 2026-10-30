import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/phone_formatter.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../application/auth_controller.dart';
import '../../application/auth_state.dart';
import '../../../settings/presentation/widgets/legal_links.dart';
import '../widgets/auth_messages.dart';
import '../widgets/auth_page.dart';
import '../widgets/phone_input.dart';

/// Les 9 chiffres du numéro saisi (sans l'indicatif), gardés en mémoire seulement
/// pour l'écran du code (affichage masqué, « Renvoyer le code »). Jamais écrits sur le disque ni dans un journal.
final loginPhoneProvider = NotifierProvider<LoginPhone, String>(LoginPhone.new);

class LoginPhone extends Notifier<String> {
  @override
  String build() => '';

  void set(String digits) => state = digits;
}

/// Étape 1 de la connexion (maquette Connexion) : numéro de téléphone.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// Erreur renvoyée par la demande de code (texte déjà traduit) ; effacée dès que l'on retape.
  String? _serverError;

  @override
  void initState() {
    super.initState();
    // Retour depuis l'écran du code : on retrouve le numéro déjà saisi.
    _controller.text = formatPhoneDigits(ref.read(loginPhoneProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _digits => phoneDigitsOf(_controller.text);

  void _submit() {
    final digits = _digits;
    if (!isValidCameroonMobile(digits)) return;
    if (ref.read(authControllerProvider) is AuthLoading) return;
    ref.read(loginPhoneProvider.notifier).set(digits);
    setState(() => _serverError = null);
    FocusScope.of(context).unfocus();
    ref.read(authControllerProvider.notifier).requestOtp('+237$digits');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final auth = ref.watch(authControllerProvider);

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthCodeSent) {
        context.go(Routes.otp);
      } else if (next is AuthFailure && !next.hasPendingCode) {
        setState(() => _serverError = authFailureMessage(l10n, next));
      }
    });

    final digits = _digits;
    final wrongStart = startsWrongForCameroonMobile(digits);
    final errorText = wrongStart ? l10n.t('auth.error.phone') : _serverError;

    return AuthPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeading(
            title: l10n.t('auth.phone.title'),
            subtitle: l10n.t('auth.phone.subtitle'),
          ),
          const SizedBox(height: 22),
          PhoneInput(
            controller: _controller,
            focusNode: _focus,
            hasError: errorText != null,
            onChanged: (_) => setState(() => _serverError = null),
            onSubmitted: _submit,
          ),
          if (errorText != null) ...[
            const SizedBox(height: 10),
            AuthErrorText(errorText),
          ],
          const SizedBox(height: 22),
          PrimaryButton(
            label: l10n.t('auth.phone.submit'),
            loading: auth is AuthLoading,
            onPressed: isValidCameroonMobile(digits) ? _submit : null,
          ),
          const SizedBox(height: 22),
          Text(
            l10n.t('auth.phone.terms'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, height: 1.5, color: c.textSecondary),
          ),
          const LegalLinks(),
        ],
      ),
    );
  }
}
