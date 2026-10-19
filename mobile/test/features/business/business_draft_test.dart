import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/business/application/business_creation_flow.dart';
import 'package:netbuis/features/business/application/business_draft_controller.dart';
import 'package:netbuis/features/business/data/models/business_draft.dart';

void main() {
  group('BusinessCreationFlow : étapes par type', () {
    test('Commerce, Particulier et Structure ont 4 étapes, Entreprise 5, Prestataire 3', () {
      expect(BusinessCreationFlow.total(BusinessAccountType.boutique), 4);
      expect(BusinessCreationFlow.total(BusinessAccountType.particulierVendeur), 4);
      expect(BusinessCreationFlow.total(BusinessAccountType.structure), 4);
      expect(BusinessCreationFlow.total(BusinessAccountType.entreprise), 5);
      expect(BusinessCreationFlow.total(BusinessAccountType.prestataireService), 3);
    });

    test('suites ordonnées selon la spec', () {
      expect(BusinessCreationFlow.stepsFor(BusinessAccountType.boutique), [
        BusinessStep.info,
        BusinessStep.sector,
        BusinessStep.details,
        BusinessStep.recap,
      ]);
      expect(BusinessCreationFlow.stepsFor(BusinessAccountType.entreprise), [
        BusinessStep.info,
        BusinessStep.legalForm,
        BusinessStep.sector,
        BusinessStep.details,
        BusinessStep.recap,
      ]);
      expect(BusinessCreationFlow.stepsFor(BusinessAccountType.prestataireService), [
        BusinessStep.info,
        BusinessStep.serviceCategory,
        BusinessStep.recap,
      ]);
      expect(BusinessCreationFlow.stepsFor(BusinessAccountType.structure), [
        BusinessStep.info,
        BusinessStep.structureType,
        BusinessStep.structureDetails,
        BusinessStep.recap,
      ]);
    });

    test('la forme juridique n\'existe que pour Entreprise', () {
      for (final type in BusinessAccountType.values) {
        final has = BusinessCreationFlow.stepsFor(type).contains(BusinessStep.legalForm);
        expect(has, type == BusinessAccountType.entreprise, reason: type.value);
      }
      expect(
        BusinessCreationFlow.position(BusinessAccountType.boutique, BusinessStep.legalForm),
        0,
      );
    });

    test('numéro, suivant et précédent', () {
      const t = BusinessAccountType.entreprise;
      expect(BusinessCreationFlow.position(t, BusinessStep.info), 1);
      expect(BusinessCreationFlow.position(t, BusinessStep.legalForm), 2);
      expect(BusinessCreationFlow.position(t, BusinessStep.recap), 5);
      expect(BusinessCreationFlow.next(t, BusinessStep.info), BusinessStep.legalForm);
      expect(BusinessCreationFlow.next(t, BusinessStep.recap), isNull);
      expect(BusinessCreationFlow.previous(t, BusinessStep.legalForm), BusinessStep.info);
      expect(BusinessCreationFlow.previous(t, BusinessStep.info), isNull);
      // Étape absente du parcours de ce type.
      expect(BusinessCreationFlow.next(BusinessAccountType.boutique, BusinessStep.legalForm),
          isNull);
    });

    test('nextRoute : le chemin de l\'étape suivante seulement si son écran existe', () {
      expect(
        BusinessCreationFlow.nextRoute(BusinessAccountType.entreprise, BusinessStep.info),
        Routes.createBusinessLegalForm,
      );
      for (final type in BusinessAccountType.values) {
        for (final step in BusinessCreationFlow.stepsFor(type)) {
          final next = BusinessCreationFlow.next(type, step);
          expect(
            BusinessCreationFlow.nextRoute(type, step),
            next != null && next.built ? next.path : null,
            reason: '${type.value} / ${step.name}',
          );
        }
      }
    });

    test('chaque étape a son propre chemin sous /create-business', () {
      final paths = BusinessStep.values.map((s) => s.path).toList();
      expect(paths.toSet().length, paths.length);
      expect(paths.every((p) => p.startsWith(Routes.createBusiness)), isTrue);
      expect(BusinessStep.info.path, '/create-business');
    });
  });

  group('BusinessDraft', () {
    test('brouillon neuf : Commerce, tout vide', () {
      const d = BusinessDraft();
      expect(d.typeCompte, BusinessAccountType.boutique);
      expect(d.typeCompte.value, 'boutique');
      expect(d.name, '');
      expect(d.formeJuridique, isNull);
      expect(d.infoIsValid, isFalse);
    });

    test('les codes envoyés au serveur', () {
      expect(BusinessAccountType.values.map((t) => t.value), [
        'boutique',
        'entreprise',
        'particulier_vendeur',
        'prestataire_service',
        'structure',
      ]);
      expect(LegalForm.values.map((f) => f.value), [
        'individuelle',
        'sarl',
        'sarlu',
        'sa',
        'gic_cooperative',
        'association',
        'etablissement_public',
        'autre',
      ]);
    });

    test('copyWith : null efface un champ vide-able, ne rien passer le conserve', () {
      final d = const BusinessDraft().copyWith(formeJuridique: LegalForm.sa, photoPath: '/a.jpg');
      expect(d.copyWith(name: 'X').formeJuridique, LegalForm.sa);
      expect(d.copyWith(name: 'X').photoPath, '/a.jpg');
      expect(d.copyWith(formeJuridique: null).formeJuridique, isNull);
      expect(d.copyWith(photoPath: null).photoPath, isNull);
    });

    test('validation : nom et représentant obligatoires, 150 caractères au plus', () {
      expect(validateBusinessName(''), FieldError.required);
      expect(validateBusinessName('   '), FieldError.required);
      expect(validateBusinessName('Boutique Mama Aïcha'), isNull);
      expect(validateBusinessName('a' * 150), isNull);
      expect(validateBusinessName('a' * 151), FieldError.tooLong);
      // Les espaces des bouts ne comptent pas ; un caractère accentué compte pour un.
      expect(validateBusinessName('  ${'é' * 150}  '), isNull);
      expect(validateRepresentantName(''), FieldError.required);
      expect(validateRepresentantName('Jeff N.'), isNull);
      expect(validateRepresentantName('b' * 151), FieldError.tooLong);
    });

    test('infoIsValid exige nom, représentant ET photo du représentant', () {
      const base = BusinessDraft(name: 'Chez Aïcha', representantNom: 'Aïcha B.');
      expect(base.infoIsValid, isFalse);
      expect(base.representantPhotoMissing, isTrue);
      expect(base.copyWith(representantPhotoPath: '/p.jpg').infoIsValid, isTrue);
      expect(base.copyWith(representantPhotoPath: '/p.jpg', name: ' ').infoIsValid, isFalse);
    });

    test('changer de type vide ce qui n\'a plus d\'objet et garde le commun', () {
      final full = const BusinessDraft(
        name: 'Chez Aïcha',
        repere: 'près du manguier',
        description: 'Texte',
        photoPath: '/c.jpg',
        representantNom: 'Aïcha B.',
        representantPhotoPath: '/r.jpg',
        zoneId: 16,
        formeJuridique: LegalForm.sarl,
        rccm: 'RC/1',
        secteurId: 3,
        sousCategorieIds: [1, 2],
        descriptionActivite: 'Vente',
        categorieServiceId: 4,
        cniPhotoPath: '/cni.jpg',
        diplomePhotoPath: '/d.jpg',
        structureTypeId: 5,
        rayons: ['boissons'],
        cuisine: 'fast_food',
        livraison: true,
        horaires: '8h-18h',
        standing: 'confort',
        nombreChambres: 12,
        equipements: ['wifi'],
        numeroAgrement: 'A1',
        specialites: ['pediatrie'],
        typeCompte: BusinessAccountType.entreprise,
      );

      // Entreprise -> Commerce : forme juridique et RCCM disparaissent, le secteur reste.
      final shop = full.withType(BusinessAccountType.boutique);
      expect(shop.formeJuridique, isNull);
      expect(shop.rccm, '');
      expect(shop.secteurId, 3);
      expect(shop.sousCategorieIds, [1, 2]);
      expect(shop.name, 'Chez Aïcha');
      expect(shop.repere, 'près du manguier');
      expect(shop.photoPath, '/c.jpg');
      expect(shop.representantNom, 'Aïcha B.');
      expect(shop.representantPhotoPath, '/r.jpg');
      expect(shop.zoneId, 16);
      // Les champs d'un autre type sont vides aussi (le serveur les refuserait).
      expect(shop.cniPhotoPath, isNull);
      expect(shop.categorieServiceId, isNull);
      expect(shop.structureTypeId, isNull);
      expect(shop.rayons, isEmpty);
      expect(shop.livraison, isNull);
      expect(shop.nombreChambres, isNull);

      // -> Prestataire : plus de secteur ni de description d'activité.
      final provider = full.withType(BusinessAccountType.prestataireService);
      expect(provider.secteurId, isNull);
      expect(provider.sousCategorieIds, isEmpty);
      expect(provider.descriptionActivite, '');
      expect(provider.formeJuridique, isNull);
      expect(provider.categorieServiceId, 4);
      expect(provider.cniPhotoPath, '/cni.jpg');
      expect(provider.structureTypeId, isNull);
      expect(provider.name, 'Chez Aïcha');

      // -> Structure : les champs d'établissement restent, le reste part.
      final venue = full.withType(BusinessAccountType.structure);
      expect(venue.structureTypeId, 5);
      expect(venue.nombreChambres, 12);
      expect(venue.specialites, ['pediatrie']);
      expect(venue.secteurId, isNull);
      expect(venue.categorieServiceId, isNull);
      expect(venue.diplomePhotoPath, isNull);
      expect(venue.rccm, '');

      // Même type : rien ne bouge.
      expect(identical(full.withType(BusinessAccountType.entreprise), full), isTrue);
    });
  });

  group('businessDraftProvider', () {
    test('garde l\'état tant qu\'il est écouté, repart neuf quand plus personne ne l\'écoute', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(businessDraftProvider, (_, __) {});
      final notifier = container.read(businessDraftProvider.notifier);
      notifier
        ..setName('Chez Aïcha')
        ..setType(BusinessAccountType.entreprise)
        ..setFormeJuridique(LegalForm.sarlu)
        ..setRccm('RC/1');
      expect(container.read(businessDraftProvider).name, 'Chez Aïcha');
      expect(container.read(businessDraftProvider).formeJuridique, LegalForm.sarlu);

      notifier.setType(BusinessAccountType.structure);
      expect(container.read(businessDraftProvider).formeJuridique, isNull);
      expect(container.read(businessDraftProvider).rccm, '');
      expect(container.read(businessDraftProvider).name, 'Chez Aïcha');

      notifier.update((d) => d.copyWith(zoneId: 7));
      expect(container.read(businessDraftProvider).zoneId, 7);

      sub.close();
      await container.pump();
      expect(container.read(businessDraftProvider).name, '');
    });
  });
}
