// Démarrage de la recherche vocale depuis le micro : explication, puis écoute.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../application/voice_search_controller.dart';

/// Explique pourquoi le micro est utile (une fois par session), puis lance l'écoute.
/// Android affiche ensuite lui-même la demande d'autorisation, la première fois.
Future<void> startVoiceSearch(BuildContext context, WidgetRef ref) async {
  if (!ref.read(voiceRationaleSeenProvider)) {
    final l10n = L10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('voice.rationale.title')),
        content: Text(l10n.t('voice.rationale.body')),
        actions: [
          TextButton(
            key: const Key('voice-rationale-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.t('voice.rationale.cancel')),
          ),
          FilledButton(
            key: const Key('voice-rationale-ok'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.t('voice.rationale.ok')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    ref.read(voiceRationaleSeenProvider.notifier).markSeen();
  }
  await ref.read(voiceSearchControllerProvider.notifier).start();
}
