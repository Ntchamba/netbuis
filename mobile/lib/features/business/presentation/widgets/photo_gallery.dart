// Photos du commerce : bande défilante ; une photo illisible est remplacée par une icône
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
    return SizedBox(
      height: 180,
      child: ListView.separated(
        key: const Key('photo-gallery'),
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            urls[i],
            width: urls.length == 1 ? MediaQuery.sizeOf(context).width - 40 : 240,
            height: 180,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (_, __, ___) => Container(
              width: 240,
              height: 180,
              color: c.border,
              child: Icon(Icons.image_not_supported_outlined, color: c.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
