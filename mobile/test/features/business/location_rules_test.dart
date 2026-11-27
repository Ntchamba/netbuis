import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/data/zones/zone.dart';
import 'package:netbuis/core/storage/prefs.dart';
import 'package:netbuis/features/business/application/business_draft_controller.dart';
import 'package:netbuis/features/business/application/business_zone_rules.dart';
import 'package:netbuis/features/business/data/models/business_draft.dart';

// Zones des tests : mêmes identifiants que le dépôt factice (Maroua = 16, Hardé = 17).
const _maroua = Zone(id: 16, name: 'Maroua', level: ZoneLevel.villeVillage, parent: 12);
const _harde = Zone(id: 17, name: 'Hardé', level: ZoneLevel.quartier, parent: 16);
const _dougoi = Zone(id: 18, name: 'Dougoï', level: ZoneLevel.quartier, parent: 16);
// Autre ville, pour les tests de changement de ville (donnée de test seulement).
const _garoua = Zone(id: 30, name: 'Garoua', level: ZoneLevel.villeVillage, parent: 13);

Zone _zoneOf(ZoneLevel level) => Zone(id: 99, name: 'Zone ${level.value}', level: level, parent: 1);

void main() {
  group('règle de niveau (une seule fonction pure)', () {
    test('2 niveaux acceptés : ville_village et quartier', () {
      expect(isBusinessZoneLevel(ZoneLevel.villeVillage), isTrue);
      expect(isBusinessZoneLevel(ZoneLevel.quartier), isTrue);
    });

    test('5 niveaux refusés : pays, région, département, arrondissement, repère', () {
      for (final level in [
        ZoneLevel.pays,
        ZoneLevel.region,
        ZoneLevel.departement,
        ZoneLevel.arrondissement,
        ZoneLevel.repere,
      ]) {
        expect(isBusinessZoneLevel(level), isFalse, reason: level.value);
      }
      // Les 7 niveaux sont couverts.
      expect(ZoneLevel.values.length, 7);
    });

    test('le brouillon refuse chaque niveau non accepté, avec une erreur typée', () {
      for (final level in ZoneLevel.values.where((l) => !isBusinessZoneLevel(l))) {
        const draft = BusinessDraft();
        expect(() => draft.withCity(_zoneOf(level)),
            throwsA(isA<InvalidBusinessZoneException>().having((e) => e.level, 'level', level)),
            reason: level.value);
        expect(() => draft.withQuartier(_zoneOf(level)),
            throwsA(isA<InvalidBusinessZoneException>().having((e) => e.level, 'level', level)),
            reason: level.value);
      }
    });

    test('un quartier ne se range pas à la place de la ville, ni l\'inverse', () {
      expect(() => const BusinessDraft().withCity(_harde),
          throwsA(isA<InvalidBusinessZoneException>()));
      expect(() => const BusinessDraft().withCity(_maroua).withQuartier(_maroua),
          throwsA(isA<InvalidBusinessZoneException>()));
    });

    test('le contrôleur laisse le brouillon intact quand la zone est refusée', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(businessDraftProvider, (_, __) {});
      final notifier = container.read(businessDraftProvider.notifier)..setCity(_maroua);
      for (final level in ZoneLevel.values.where((l) => !isBusinessZoneLevel(l))) {
        expect(() => notifier.setCity(_zoneOf(level)), throwsA(isA<InvalidBusinessZoneException>()));
      }
      final d = container.read(businessDraftProvider);
      expect(d.zoneId, 16);
      expect(d.ville, _maroua);
    });

    test('le message de refus existe en français et en anglais', () {
      for (final lang in ['fr', 'en']) {
        final map = json.decode(File('assets/l10n/$lang.json').readAsStringSync()) as Map;
        expect(map['business.create.error.locationLevel'], isA<String>(), reason: lang);
        expect(map['business.create.error.locationRequired'], isA<String>(), reason: lang);
      }
      final fr = json.decode(File('assets/l10n/fr.json').readAsStringSync()) as Map;
      expect(fr['business.create.error.locationLevel'],
          'Choisissez votre ville ou votre quartier, pas seulement une région ou un département.');
    });
  });

  group('lieu dans le brouillon', () {
    test('brouillon neuf : pas de lieu', () {
      const d = BusinessDraft();
      expect(d.zoneId, isNull);
      expect(d.locationLabel, isNull);
      expect(d.locationMissing, isTrue);
    });

    test('ville seule : zone = la ville, libellé « Maroua »', () {
      final d = const BusinessDraft().withCity(_maroua);
      expect(d.zoneId, 16);
      expect(d.locationLabel, 'Maroua');
      expect(d.locationMissing, isFalse);
    });

    test('quartier choisi : zone = le quartier, libellé « Maroua, Hardé »', () {
      final d = const BusinessDraft().withCity(_maroua).withQuartier(_harde);
      expect(d.zoneId, 17);
      expect(d.ville, _maroua);
      expect(d.quartier, _harde);
      expect(d.locationLabel, 'Maroua, Hardé');
    });

    test('« Je ne trouve pas mon quartier » : retour à la ville seule', () {
      final d = const BusinessDraft().withCity(_maroua).withQuartier(_harde).withQuartier(null);
      expect(d.zoneId, 16);
      expect(d.quartier, isNull);
      expect(d.locationLabel, 'Maroua');
      // Sans ville, effacer le quartier ne change rien.
      expect(const BusinessDraft().withQuartier(null).zoneId, isNull);
    });

    test('changer de ville vide le quartier ; garder la même ville le conserve', () {
      final withDistrict = const BusinessDraft().withCity(_maroua).withQuartier(_harde);
      final same = withDistrict.withCity(_maroua);
      expect(same.quartier, _harde);
      expect(same.zoneId, 17);
      final other = withDistrict.withCity(_garoua);
      expect(other.quartier, isNull);
      expect(other.zoneId, 30);
      expect(other.locationLabel, 'Garoua');
    });

    test('un quartier d\'une autre ville, ou sans ville, est refusé', () {
      expect(() => const BusinessDraft().withQuartier(_harde), throwsStateError);
      expect(() => const BusinessDraft().withCity(_garoua).withQuartier(_harde), throwsStateError);
    });

    test('changer de type de compte garde le lieu', () {
      final d = const BusinessDraft().withCity(_maroua).withQuartier(_dougoi);
      final other = d.withType(BusinessAccountType.structure);
      expect(other.locationLabel, 'Maroua, Dougoï');
      expect(other.zoneId, 18);
    });

    test('le contrôleur reprend la ville mémorisée seulement si aucun lieu n\'est choisi', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(businessDraftProvider, (_, __) {});
      final notifier = container.read(businessDraftProvider.notifier);

      notifier.prefillCity(null);
      expect(container.read(businessDraftProvider).zoneId, isNull);

      notifier.prefillCity(const SelectedCity(id: 16, name: 'Maroua'));
      expect(container.read(businessDraftProvider).zoneId, 16);
      expect(container.read(businessDraftProvider).locationLabel, 'Maroua');

      // Un lieu déjà choisi n'est jamais écrasé.
      notifier
        ..setQuartier(_harde)
        ..prefillCity(const SelectedCity(id: 30, name: 'Garoua'));
      expect(container.read(businessDraftProvider).zoneId, 17);
      expect(container.read(businessDraftProvider).locationLabel, 'Maroua, Hardé');
    });
  });

  group('recherche par nom', () {
    test('minuscules et accents ignorés', () {
      expect(normalizeForSearch('  Hardé '), 'harde');
      expect(normalizeForSearch('DOUGOÏ'), 'dougoi');
      expect(normalizeForSearch('Ngaoundéré'), 'ngaoundere');
      expect(normalizeForSearch('cœur'), 'coeur');
      expect(normalizeForSearch('Çà et là'), 'ca et la');
    });

    test('filtre : casse, accents, morceau de nom, aucun résultat, recherche vide', () {
      const zones = [
        _maroua,
        _garoua,
        Zone(id: 31, name: 'Ngaoundéré', level: ZoneLevel.villeVillage, parent: 13),
      ];
      expect(filterZonesByName(zones, 'MAROUA').map((z) => z.id), [16]);
      expect(filterZonesByName(zones, 'ngaoundere').map((z) => z.id), [31]);
      expect(filterZonesByName(zones, 'NGAOUNDÉ').map((z) => z.id), [31]);
      expect(filterZonesByName(zones, 'oua').map((z) => z.id), [16, 30]);
      expect(filterZonesByName(zones, 'xyz'), isEmpty);
      expect(filterZonesByName(zones, '   ').length, 3);
      expect(filterZonesByName(zones, '').length, 3);
    });
  });
}
