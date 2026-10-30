// Bandeau d'écoute de la maquette `Main` : « 🎤 Je vous écoute... dites le nom d'un produit »
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';

class VoiceListeningBanner extends StatelessWidget {
  const VoiceListeningBanner({super.key, required this.onCancel});

  /// Touche sur le bandeau : arrêter l'écoute.
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Semantics(
      liveRegion: true,
      button: true,
      label: l10n.t('voice.listening'),
      hint: l10n.t('voice.listening.stop'),
      excludeSemantics: true,
      child: Material(
        key: const Key('voice-banner'),
        color: AppColors.accent,
        elevation: 8,
        shadowColor: const Color(0x59000000),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onCancel,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text('🎤', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.t('voice.listening'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
