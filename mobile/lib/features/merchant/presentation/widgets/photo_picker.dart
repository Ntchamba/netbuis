import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../business/application/business_services.dart';
import '../../../business/data/photo_service.dart';
import '../../application/offers_controller.dart';

/// Photos d'un produit (4 au plus) : vignettes avec « Retirer », puis une case « Ajouter une
/// photo » (appareil photo ou galerie) tant que la limite n'est pas atteinte.
/// Une photo déjà enregistrée n'a pas d'adresse d'affichage : elle est montrée par une icône.
class OfferPhotoPicker extends ConsumerWidget {
  const OfferPhotoPicker({super.key, required this.photos, required this.onChanged});

  final List<OfferPhoto> photos;
  final ValueChanged<List<OfferPhoto>> onChanged;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('offer-photo-camera'),
              minTileHeight: 56,
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.t('business.create.photo.take')),
              onTap: () => Navigator.of(sheet).pop(PhotoSource.camera),
            ),
            ListTile(
              key: const ValueKey('offer-photo-gallery'),
              minTileHeight: 56,
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.t('business.create.photo.gallery')),
              onTap: () => Navigator.of(sheet).pop(PhotoSource.gallery),
            ),
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.close),
              title: Text(l10n.t('business.create.photo.cancel')),
              onTap: () => Navigator.of(sheet).pop(),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final path = await ref.read(photoPickerProvider).pick(source);
      if (path != null) onChanged([...photos, OfferPhoto.local(path)]);
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.t('business.create.photo.error'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('offers.form.photos').replaceAll('{max}', '$kMaxOfferPhotos'),
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < photos.length; i++)
              _Thumb(
                key: ValueKey('offer-photo-$i'),
                photo: photos[i],
                removeLabel: l10n.t('offers.form.photo.remove'),
                onRemove: () => onChanged([...photos]..removeAt(i)),
              ),
            if (photos.length < kMaxOfferPhotos)
              Semantics(
                button: true,
                label: l10n.t('offers.form.photo.add'),
                excludeSemantics: true,
                onTap: () => _add(context, ref),
                child: InkWell(
                  key: const ValueKey('offer-photo-add'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _add(context, ref),
                  child: Container(
                    width: 84,
                    // Au moins 100 ; plus haut quand la police du téléphone est agrandie.
                    constraints: const BoxConstraints(minHeight: 100),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: c.card,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 24, color: c.textSecondary),
                        const SizedBox(height: 4),
                        Text(
                          l10n.t('offers.form.photo.add'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({super.key, required this.photo, required this.removeLabel, required this.onRemove});

  final OfferPhoto photo;
  final String removeLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final path = photo.path;
    final placeholder = ColoredBox(
      color: c.border,
      child: Icon(Icons.image_outlined, color: c.textSecondary),
    );
    return SizedBox(
      width: 84,
      height: 104,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 84,
              height: 56,
              child: path == null
                  ? placeholder
                  : Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      cacheWidth: 168,
                      errorBuilder: (context, _, __) => placeholder,
                    ),
            ),
          ),
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: onRemove,
              style: TextButton.styleFrom(
                minimumSize: const Size(84, 48),
                padding: EdgeInsets.zero,
              ),
              child: Text(removeLabel, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
