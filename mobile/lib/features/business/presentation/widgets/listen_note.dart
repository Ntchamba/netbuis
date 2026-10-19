import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/business_services.dart';
import '../../data/speech_service.dart';

/// Encart explicatif de la maquette : une icône, un texte, et le bouton « Écouter » qui
/// lit ce texte à voix haute (synthèse vocale du téléphone). Un second appui, un changement
/// de texte ou la sortie de l'écran arrête la lecture. Le texte lu est exactement
/// le texte affiché. Si la synthèse est indisponible, rien ne s'affiche de plus.
class ListenNote extends ConsumerStatefulWidget {
  const ListenNote({super.key, required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  ConsumerState<ListenNote> createState() => _ListenNoteState();
}

class _ListenNoteState extends ConsumerState<ListenNote> {
  late final SpeechService _speech = ref.read(speechServiceProvider);

  @override
  void didUpdateWidget(ListenNote old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _speech.stop();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  String get _languageTag =>
      Localizations.localeOf(context).languageCode == 'en' ? 'en-US' : 'fr-FR';

  void _toggle() {
    if (_speech.speaking.value) {
      _speech.stop();
    } else {
      _speech.speak(widget.text, languageTag: _languageTag);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: _speech.speaking,
      builder: (context, speaking, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.card,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Text(widget.icon, style: const TextStyle(fontSize: 18, height: 1.2)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          widget.text,
                          key: const ValueKey('business-note-text'),
                          style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _ListenButton(
                      speaking: speaking,
                      label: l10n.t('business.create.listen'),
                      semanticsLabel: l10n.t(
                        speaking ? 'business.create.listen.stopLabel' : 'business.create.listen.label',
                      ),
                      onTap: _toggle,
                    ),
                  ],
                ),
              ),
            ),
            if (speaking)
              Semantics(
                liveRegion: true,
                child: Container(
                  key: const ValueKey('business-listening'),
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Text('🔊', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.t('business.create.listen.playing'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ListenButton extends StatelessWidget {
  const _ListenButton({
    required this.speaking,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
  });

  final bool speaking;
  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: const ValueKey('business-listen'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64, minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                    size: 22,
                    color: AppColors.onAccent,
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onAccent,
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
