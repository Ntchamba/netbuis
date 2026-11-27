// Informations publiques propres au type de compte (forme juridique, diplôme, détails de structure)
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/public_business.dart';
import '../../data/models/structure_options.dart';

/// Codes de forme juridique connus (traduits par `business.create.legal.<code>`).
const List<String> kLegalFormCodes = [
  'individuelle', 'sarl', 'sarlu', 'sa', 'gic_cooperative', 'association',
  'etablissement_public', 'autre',
];

/// Lignes « libellé : valeur » de la fiche, dans l'ordre d'affichage. Fonction pure (testable).
List<MapEntry<String, String>> publicInfoRows(L10n l10n, PublicBusiness b) {
  final rows = <MapEntry<String, String>>[];
  void add(String labelKey, String value) {
    if (value.trim().isNotEmpty) rows.add(MapEntry(l10n.t(labelKey), value.trim()));
  }

  String one(List<StructureOption> options, String code) {
    for (final o in options) {
      if (o.code == code) return l10n.t(o.labelKey);
    }
    return '';
  }

  String many(List<StructureOption> options, List<String> codes) =>
      codes.map((c) => one(options, c)).where((s) => s.isNotEmpty).join(', ');

  if (b.formeJuridique.isNotEmpty && kLegalFormCodes.contains(b.formeJuridique)) {
    add('business.detail.legalForm', l10n.t('business.create.legal.${b.formeJuridique}'));
  }
  if (b.diplomeFourni) add('business.detail.diploma', l10n.t('business.detail.diplomaProvided'));
  add('business.detail.structureType', b.structureType);
  final d = b.details;
  add('business.detail.cuisine', one(kCuisineOptions, d.cuisine));
  if (d.livraison != null) {
    add('business.detail.delivery',
        l10n.t(d.livraison! ? 'business.create.structure.delivery.yes' : 'business.create.structure.delivery.no'));
  }
  add('business.detail.hours', d.horaires);
  add('business.detail.standing', one(kStandingOptions, d.standing));
  if (d.nombreChambres != null) add('business.detail.rooms', '${d.nombreChambres}');
  add('business.detail.amenities', many(kAmenityOptions, d.equipements));
  add('business.detail.aisles', many(kAisleOptions, d.rayons));
  add('business.detail.specialities', many(kSpecialityOptions, d.specialites));
  return rows;
}

class PublicInfoSection extends StatelessWidget {
  const PublicInfoSection({super.key, required this.rows});

  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      key: const Key('detail-info'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(L10n.of(context).t('business.detail.info'), style: text.titleMedium),
        const SizedBox(height: 8),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(r.key, style: TextStyle(fontSize: 13, color: c.textSecondary)),
                ),
                Expanded(child: Text(r.value, style: text.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}
