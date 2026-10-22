// Photos du commerce : une en pleine largeur, plusieurs en grille qui passe à la ligne ;
// une photo illisible est remplacée par une icône
import 'package:flutter/material.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/upload_url.dart';
import '../../../../core/theme/app_colors.dart';

class PhotoGallery extends StatelessWidget {
  const PhotoGallery({super.key, required this.photos});

  /// Adresses données par le serveur (complètes ou chemins `/media/…`).
  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    final urls = <String>[];
    for (final p in photos) {
      try {
        urls.add(resolveUploadUrl(Env.apiUrl, p));
      } on ApiException {
        // adresse inutilisable : photo ignorée
      }
    }
    if (urls.isEmpty) return const SizedBox.shrink();
    final c = AppColors.of(context);
    // Pas de défilement horizontal : une photo en pleine largeur, plusieurs sur deux colonnes
    // qui passent à la ligne.
    return LayoutBuilder(
      builder: (context, constraints) {
        final single = urls.length == 1;
        final width = single ? constraints.maxWidth : (constraints.maxWidth - 10) / 2;
        final height = single ? 180.0 : 130.0;
        return Wrap(
          key: const Key('photo-gallery'),
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final url in urls)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  url,
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                  // Décodage limité (perf T122) : pas de photo d'appareil décodée en pleine taille.
                  cacheWidth: 780,
                  excludeFromSemantics: true,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Container(width: width, height: height, color: c.border),
                  errorBuilder: (_, __, ___) => Container(
                    width: width,
                    height: height,
                    color: c.border,
                    child: Icon(Icons.image_not_supported_outlined, color: c.textSecondary),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
