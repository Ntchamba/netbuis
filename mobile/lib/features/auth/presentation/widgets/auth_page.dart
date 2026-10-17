import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';

/// Gabarit des deux étapes de connexion : bouton retour (étape du code seulement)
/// puis le contenu, défilant verticalement si le clavier ou une grande police le demande.
class AuthPage extends StatelessWidget {
  const AuthPage({super.key, required this.child, this.onBack});

  final Widget child;

  /// Montre le bouton retour quand il est fourni.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 48,
                child: onBack == null
                    ? null
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: Semantics(
                          button: true,
                          label: l10n.t('auth.back'),
                          excludeSemantics: true,
                          child: InkResponse(
                            key: const ValueKey('auth-back'),
                            onTap: onBack,
                            radius: 24,
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: c.card,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: c.border),
                                  ),
                                  child: Icon(Icons.chevron_left, size: 22, color: c.textPrimary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Titre + phrase d'aide de l'écran (maquette : 23 px gras, puis 13,5 px).
class AuthHeading extends StatelessWidget {
  const AuthHeading({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: TextStyle(fontSize: 13.5, height: 1.5, color: c.textSecondary)),
      ],
    );
  }
}

/// Message d'erreur court : icône + texte (jamais la couleur seule), annoncé par le lecteur d'écran.
class AuthErrorText extends StatelessWidget {
  const AuthErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: error),
            ),
          ),
        ],
      ),
    );
  }
}
