import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/speech_providers.dart';
import '../../data/speech_output.dart';

/// Bouton « 🔊 Écouter » : lit [text] à voix haute. Il est **masqué** (rien à l'écran)
/// tant qu'on ne sait pas qu'une voix existe pour la langue courante de l'application
/// (français : fr-FR ; anglais : en-US ou en-*), et si la détection échoue.
/// Un second appui, un changement de texte, de langue ou d'écran arrête la lecture.
class ListenButton extends ConsumerStatefulWidget {
  const ListenButton({super.key, required this.text});

  final String text;

  @override
  ConsumerState<ListenButton> createState() => _ListenButtonState();
}

class _ListenButtonState extends ConsumerState<ListenButton> {
  late final SpeechOutput _speech;

  @override
  void initState() {
    super.initState();
    // Gardé dans un champ dès le départ : `ref` n'est plus utilisable dans dispose().
    _speech = ref.read(speechOutputProvider);
  }

  @override
  void didUpdateWidget(ListenButton old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _stopSoon();
  }

  @override
  void dispose() {
    _stopSoon();
    super.dispose();
  }

  /// Arrêt différé : on ne modifie pas l'état de lecture pendant que l'arbre est verrouillé.
  void _stopSoon() => scheduleMicrotask(_speech.stop);

  void _toggle() {
    if (_speech.speaking.value) {
      _speech.stop();
      return;
    }
    _speech.speak(widget.text, languageTag: ref.read(speechLanguageTagProvider));
  }

  @override
  Widget build(BuildContext context) {
    final tag = ref.watch(speechLanguageTagProvider);
    final available = ref.watch(voiceAvailableProvider(tag)).value ?? false;
    if (!available) return const SizedBox.shrink();
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: _speech.speaking,
      builder: (context, speaking, _) => Semantics(
        button: true,
        label: l10n.t(speaking ? 'speech.stop.label' : 'speech.listen.label'),
        excludeSemantics: true,
        onTap: _toggle,
        child: TextButton.icon(
          key: const ValueKey('listen-button'),
          onPressed: _toggle,
          style: TextButton.styleFrom(
            foregroundColor: c.accentText,
            minimumSize: const Size(48, 48),
          ),
          icon: Icon(speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined, size: 20),
          label: Text(l10n.t(speaking ? 'speech.stop' : 'speech.listen')),
        ),
      ),
    );
  }
}
