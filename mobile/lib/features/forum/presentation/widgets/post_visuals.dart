// Éléments communs du fil et de la page d'une publication : pastille du commerce, média,
// étiquette produit. Tout texte venant du serveur est affiché en texte simple (Text).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/upload_url.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/forum_services.dart';
import '../../data/models/post.dart';

/// Adresse complète d'un média (ou null si elle est absente ou refusée).
String? resolveForumUrl(String? url) {
  if (url == null) return null;
  try {
    return resolveUploadUrl(Env.apiUrl, url);
  } on ApiException {
    return null;
  }
}

/// Initiales sur fond d'accent, ou photo du commerce si elle existe.
class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar({
    super.key,
    required this.initials,
    this.photo,
    this.size = 34,
    this.fontSize = 13,
    this.highlighted = true,
  });

  final String initials;
  final String? photo;
  final double size;
  final double fontSize;

  /// Vrai : fond d'accent (commerce, fil) ; faux : pastille discrète (commentaires).
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final url = resolveForumUrl(photo);
    final letters = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlighted ? AppColors.accent : c.card,
        border: highlighted ? null : Border.all(color: c.border),
      ),
      child: ExcludeSemantics(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: highlighted ? FontWeight.w800 : FontWeight.w700,
            color: highlighted ? AppColors.onAccent : c.textSecondary,
          ),
        ),
      ),
    );
    if (url == null) return letters;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          cacheWidth: 120,
          errorBuilder: (context, _, __) => letters,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : letters,
        ),
      ),
    );
  }
}

/// Étiquette du produit associé (pastille de la maquette).
class ProductTag extends StatelessWidget {
  const ProductTag({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = AppColors.of(context).accentText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF262620) : const Color(0xFFFEF3E2),
        border: Border.all(
            color: dark ? const Color(0xFF3A3A2E) : const Color(0xFFF0D6A3)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(name,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: text)),
    );
  }
}

/// Média d'une publication. Photo : chargée seulement quand la carte est affichée (liste
/// paresseuse). Vidéo : JAMAIS chargée ni lancée toute seule ; un bouton « Voir la vidéo »
/// l'ouvre à la demande, hors de l'application.
class PostMedia extends ConsumerWidget {
  const PostMedia(
      {super.key, required this.type, required this.url, this.height = 180});

  final PostMediaType type;
  final String? url;
  final double height;

  Future<void> _openVideo(
      BuildContext context, WidgetRef ref, String address) async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await ref.read(externalUrlOpenerProvider)(Uri.parse(address));
    } on Object {
      ok = false;
    }
    if (!ok) {
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.t('forum.video.error'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF15151A) : const Color(0xFFEFEFF2);
    final muted = dark ? const Color(0xFF3A3A40) : const Color(0xFFC8C8CE);
    final address = resolveForumUrl(url);
    final icon = Icon(Icons.image_outlined, size: 34, color: muted);
    if (type == PostMediaType.video) {
      return Container(
        key: const ValueKey('post-video'),
        height: height,
        width: double.infinity,
        color: bg,
        alignment: Alignment.center,
        child: address == null
            ? Icon(Icons.videocam_outlined, size: 34, color: muted)
            : FilledButton.icon(
                key: const ValueKey('post-video-play'),
                onPressed: () => _openVideo(context, ref, address),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.t('forum.video.play'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: address == null
          ? ColoredBox(color: bg, child: Center(child: icon))
          : Image.network(
              address,
              key: const ValueKey('post-image'),
              fit: BoxFit.cover,
              cacheWidth: 780,
              errorBuilder: (context, _, __) =>
                  ColoredBox(color: bg, child: Center(child: icon)),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : ColoredBox(color: bg, child: Center(child: icon)),
            ),
    );
  }
}
