import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/widgets/auth_page.dart';
import '../../application/account_controller.dart';
import '../../data/models/me.dart';

/// Saisie du prénom/nom, proposée une seule fois après la première connexion
/// (pas de maquette). Facultatif : « Passer » ou un champ vide mènent à l'Accueil
/// sans rien envoyer. Un échec réseau ne bloque pas : réessayer ou passer.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _errorKey;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skip() => context.go(Routes.home);

  Future<void> _submit() async {
    if (_sending) return;
    final name = cleanName(_controller.text);
    if (name == null) return _skip();
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _errorKey = null;
    });
    final error =
        await ref.read(accountControllerProvider.notifier).updateName(name);
    if (!mounted) return;
    if (error == null) return _skip();
    setState(() {
      _sending = false;
      _errorKey = switch (error.code) {
        ApiErrorCode.network => 'name.error.network',
        ApiErrorCode.accountBlocked ||
        ApiErrorCode.accountDeleted =>
          'name.error.support',
        _ => 'name.error.unknown',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    // Garde l'état du profil vivant pendant l'envoi et le précharge pour l'onglet Profil.
    ref.watch(accountControllerProvider);
    final errorKey = _errorKey;

    return AuthPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeading(
              title: l10n.t('name.title'), subtitle: l10n.t('name.subtitle')),
          const SizedBox(height: 22),
          TextField(
            key: const ValueKey('name-field'),
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            inputFormatters: [LengthLimitingTextInputFormatter(maxNameLength)],
            onChanged: (_) => setState(() => _errorKey = null),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.t('name.label'),
              hintText: l10n.t('name.hint'),
            ),
          ),
          if (errorKey != null) ...[
            const SizedBox(height: 10),
            AuthErrorText(l10n.t(errorKey)),
          ],
          const SizedBox(height: 22),
          PrimaryButton(
            label: l10n.t(errorKey == null ? 'name.submit' : 'name.retry'),
            loading: _sending,
            icon: Icons.arrow_forward,
            onPressed: _submit,
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey('name-skip'),
            onPressed: _sending ? null : _skip,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(l10n.t('name.skip')),
          ),
        ],
      ),
    );
  }
}
