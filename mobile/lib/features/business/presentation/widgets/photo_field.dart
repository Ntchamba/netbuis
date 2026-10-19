import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/dashed_border.dart';
import '../../application/business_services.dart';
import '../../data/photo_service.dart';

/// Zone « Ajouter une photo » (maquette) : cadre en tirets ; un appui propose l'appareil
/// photo ou la galerie. Une fois la photo prise : petite vignette, « Photo ajoutée »
/// et « Changer la photo ». [onChanged] reçoit le chemin du fichier.
class PhotoField extends ConsumerWidget {
  const PhotoField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.icon,
    required this.path,
    required this.onChanged,
    this.labelSuffix,
    this.errorText,
    this.tapKey,
    this.compact = false,
    this.labelSuffixColor,
    this.helper,
    this.addedSemantics,
    this.onRemove,
    this.removeLabel,
    this.removeKey,
  });

  final String label;
  final String? labelSuffix;
  final String placeholder;
  final IconData icon;
  final String? path;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final Key? tapKey;

  /// Couleur de la mention [labelSuffix] (gris par défaut ; la couleur d'accent pour
  /// « · obligatoire » dans la maquette Prestataire).
  final Color? labelSuffixColor;

  /// Petite note sous la zone (confidentialité, « Facultatif… »).
  final String? helper;

  /// Texte lu par le lecteur d'écran quand la photo est ajoutée (ex. « Photo de la CNI
  /// ajoutée »). Par défaut : « {label}. Photo ajoutée ».
  final String? addedSemantics;

  /// Si fourni, un bouton [removeLabel] retire la photo choisie.
  final VoidCallback? onRemove;
  final String? removeLabel;
  final Key? removeKey;

  /// Disposition en ligne (icône à gauche) comme la photo du représentant.
  final bool compact;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('photo-camera'),
              minTileHeight: 56,
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.t('business.create.photo.take')),
              onTap: () => Navigator.of(sheet).pop(PhotoSource.camera),
            ),
            ListTile(
              key: const ValueKey('photo-gallery'),
              minTileHeight: 56,
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.t('business.create.photo.gallery')),
              onTap: () => Navigator.of(sheet).pop(PhotoSource.gallery),
            ),
            ListTile(
              key: const ValueKey('photo-cancel'),
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
      final picked = await ref.read(photoPickerProvider).pick(source);
      if (picked != null) onChanged(picked);
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.t('business.create.photo.error'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final error = Theme.of(context).colorScheme.error;
    final has = path != null;
    final dash = errorText != null
        ? error
        : (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF3A3A3E)
            : const Color(0xFFC9C9CE));
    final shownLabel = has ? l10n.t('business.create.photo.change') : placeholder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (labelSuffix != null)
                TextSpan(
                  text: ' $labelSuffix',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: labelSuffixColor ?? c.textSecondary,
                  ),
                ),
            ],
          ),
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        Semantics(
          button: true,
          label: has
              ? '${addedSemantics ?? '$label. ${l10n.t('business.create.photo.added')}'}. $shownLabel'
              : '$label. $shownLabel',
          onTap: () => _pick(context, ref),
          excludeSemantics: true,
          child: InkWell(
            key: tapKey,
            borderRadius: BorderRadius.circular(12),
            onTap: () => _pick(context, ref),
            child: DashedBorderBox(
              color: dash,
              background: c.card,
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 14 : 18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: has
                    ? Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: Image.file(
                                File(path!),
                                fit: BoxFit.cover,
                                cacheWidth: 112,
                                errorBuilder: (context, _, __) => ColoredBox(
                                  color: c.border,
                                  child: Icon(Icons.image_outlined, color: c.textSecondary),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.check_circle, size: 16, color: c.accentText),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        l10n.t('business.create.photo.added'),
                                        style: const TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  shownLabel,
                                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : (compact
                        ? Row(
                            children: [
                              Icon(icon, size: 22, color: c.textSecondary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  placeholder,
                                  style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, size: 24, color: c.textSecondary),
                              const SizedBox(height: 6),
                              Text(
                                placeholder,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: c.textSecondary),
                              ),
                            ],
                          )),
              ),
            ),
          ),
        ),
        if (has && onRemove != null && removeLabel != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: removeKey,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(removeLabel!),
            ),
          ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(helper!, style: TextStyle(fontSize: 11, height: 1.4, color: c.textSecondary)),
        ],
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    errorText!,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: error),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
