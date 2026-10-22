import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/speech_providers.dart';
import '../../data/speech_output.dart';

/// Bouton « 🔊 Écouter » : lit [text] à voix haute. Il est **masqué** (rien à l'écran)
/// tant qu'on ne sait pas qu'une voix française est installée, et si la détection échoue.
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
    if (old.text != widget.text) _speech.stop();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  void _toggle() {
    if (_speech.speaking.value) {
      _speech.stop();
      return;
    }
    final english = Localizations.localeOf(context).languageCode == 'en';
    _speech.speak(widget.text, languageTag: english ? 'en-US' : FlutterTtsSpeechOutput.frenchTag);
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(frenchVoiceAvailableProvider).value ?? false;
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
