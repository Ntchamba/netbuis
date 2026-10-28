
import 'package:flutter/material.dart';

import '../../../../core/utils/local_image.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';

/// Texte avec paramètres `{nom}` remplacés.
String fill(String template, Map<String, String> values) {
  var out = template;
  values.forEach((k, v) => out = out.replaceAll('{$k}', v));
  return out;
}

/// Carte du récapitulatif (maquette CreationBusiness-Recap) : fond carte, bord fin, 16 px
/// d'arrondi, 16 px de marge, éléments espacés de 12 px.
class RecapCard extends StatelessWidget {
  const RecapCard({super.key, required this.children, this.cardKey});

  final List<Widget> children;
  final Key? cardKey;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DecoratedBox(
      key: cardKey,
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Ligne « libellé … valeur » de la maquette (13 px, valeur en gras alignée à droite).
/// Le libellé et la valeur passent à la ligne quand la police est grande (pas de coupure).
class RecapRow extends StatelessWidget {
  const RecapRow({super.key, required this.label, required this.value, this.rowKey});

  final String label;
  final String value;
  final Key? rowKey;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      container: true,
      label: '$label : $value',
      excludeSemantics: true,
      child: Row(
        key: rowKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 2,
            child: Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary)),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne cliquable : la ligne entière ouvre l'écran qui permet de la modifier (≥ 48 dp).
/// Lue « {libellé} : {valeur}, modifier ».
class RecapEditableRow extends StatelessWidget {
  const RecapEditableRow({
    super.key,
    required this.label,
    required this.value,
    required this.onEdit,
  });

  final String label;
  final String value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final editLabel = l10n.t('business.recap.edit');
    return Semantics(
      button: true,
      label: fill(l10n.t('business.recap.editSemantics'), {'label': label, 'value': value}),
      onTap: onEdit,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onEdit,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                flex: 2,
                child: Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary)),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 3,
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit_outlined, size: 16, color: c.accentText, semanticLabel: editLabel),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lien « Modifier » d'une carte (≥ 48 dp), lu « Modifier : {section} ».
class RecapEditLink extends StatelessWidget {
  const RecapEditLink({super.key, required this.section, required this.onEdit});

  final String section;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Semantics(
        button: true,
        label: fill(l10n.t('business.recap.editSection'), {'section': section}),
        onTap: onEdit,
        excludeSemantics: true,
        child: TextButton.icon(
          onPressed: onEdit,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: Text(l10n.t('business.recap.edit')),
        ),
      ),
    );
  }
}

/// Pastille de la maquette (sous-catégories, rayons…).
class RecapChip extends StatelessWidget {
  const RecapChip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        child: Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Miniature d'une photo choisie (fichier local, en mémoire de l'appareil). Ne sert JAMAIS
/// pour la CNI, qui n'est jamais montrée.
class RecapThumb extends StatelessWidget {
  const RecapThumb({super.key, required this.path, required this.label});

  final String path;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      image: true,
      label: label,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 56,
          child: localImage(
            path,
            fit: BoxFit.cover,
            cacheWidth: 112,
            errorBuilder: (context, _, __) => ColoredBox(
              color: c.border,
              child: Icon(Icons.image_outlined, color: c.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
