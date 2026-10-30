import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/account/data/models/me.dart';
import 'package:netbuis/features/auth/presentation/screens/login_screen.dart';
import 'package:netbuis/features/business/application/business_services.dart';
import 'package:netbuis/features/business/data/models/business.dart';
import 'package:netbuis/features/business/data/models/business_draft.dart';
import 'package:netbuis/features/business/data/repositories/business_repository.dart';
import 'package:netbuis/core/di/providers.dart';

import '../account/account_test_helpers.dart';
import 'business_submit_helpers.dart' show fakeJpeg;
import 'business_test_helpers.dart';

/// Dépôt « business » modifiable : applique les règles D-08 comme le serveur et note les envois.
class EditableBusinessRepository implements BusinessRepository {
  EditableBusinessRepository(this.current);

  MyBusiness current;
  final List<Map<String, Object?>> updates = [];
  final List<String> signedKinds = [];
  int getCalls = 0;

  /// Erreurs levées, dans l'ordre, par les prochains appels à `update` / `getMine` / `signUpload`.
  final List<ApiException> updateErrors = [];
  final List<ApiException> getErrors = [];
  final List<ApiException> signErrors = [];

  @override
  Future<MyBusiness> getMine() async {
    getCalls++;
    if (getErrors.isNotEmpty) throw getErrors.removeAt(0);
    return current;
  }

  @override
  Future<MyBusiness> update(Map<String, Object?> body) async {
    updates.add(Map.of(body));
    if (updateErrors.isNotEmpty) throw updateErrors.removeAt(0);
    final c = current;
    var status = c.status;
    var motif = c.motifRejet;
    if (status == BusinessStatus.rejected) {
      status = BusinessStatus.pending;
      motif = '';
    } else if (status == BusinessStatus.active &&
        (body.containsKey('name') && body['name'] != c.name ||
            body.containsKey('zone') && body['zone'] != c.zoneId)) {
      status = BusinessStatus.pending;
    }
    String text(String k, String old) => body[k] is String ? body[k]! as String : old;
    current = MyBusiness(
      status: status,
      name: text('name', c.name),
      motifRejet: motif,
      typeCompte: c.typeCompte,
      zoneId: body['zone'] is int ? body['zone']! as int : c.zoneId,
      repere: text('repere', c.repere),
      description: text('description', c.description),
      descriptionActivite: text('description_activite', c.descriptionActivite),
      representantNom: text('representant_nom', c.representantNom),
      hasPhoto: c.hasPhoto || body.containsKey('photo'),
      hasRepresentantPhoto: c.hasRepresentantPhoto,
      hasCni: c.hasCni,
      hasDiplome: c.hasDiplome,
    );
    return current;
  }

  @override
  Future<UploadTicket> signUpload(
      {required String kind, required String contentType, required int size}) async {
    signedKinds.add(kind);
    if (signErrors.isNotEmpty) throw signErrors.removeAt(0);
    return UploadTicket(key: 'u1/$kind/${signedKinds.length}', uploadUrl: '/x/', headers: const {});
  }

  @override
  Future<void> putFile(UploadTicket ticket, Uint8List bytes) async {}

  @override
  Future<MyBusiness> create(Map<String, Object?> body) => throw StateError('Non utilisé');
}

MyBusiness _shop({
  BusinessStatus status = BusinessStatus.active,
  BusinessAccountType type = BusinessAccountType.boutique,
  String motif = '',
}) =>
    MyBusiness(
      status: status,
      name: 'Boutique Mama Aïcha',
      motifRejet: motif,
      typeCompte: type,
      zoneId: 16, // Maroua dans les zones factices
      repere: 'Près du manguier',
      descriptionActivite: 'Fruits et légumes',
      description: 'Cadre climatisé',
      representantNom: 'Aïcha Oumarou',
      hasPhoto: true,
      hasRepresentantPhoto: true,
    );

final _me = Me(id: 1, name: 'Jeff N.', phoneMasked: '+237 6•• •• •• 12', hasBusiness: true);

Future<void> _open(
  WidgetTester tester,
  EditableBusinessRepository repo, {
  String start = Routes.profile,
  Me? me,
  FakePhotoPicker? photos,
}) =>
    pumpBusinessApp(
      tester,
      initialLocation: start,
      account: ScriptedAccountRepository(me: me ?? _me),
      photos: photos,
      overrides: [
        businessRepositoryProvider.overrideWithValue(repo),
        photoBytesReaderProvider.overrideWithValue((path) async => fakeJpeg(600)),
      ],
    );

Finder _k(String key) => find.byKey(ValueKey(key));

String _path(WidgetTester tester) => GoRouter.of(tester.element(find.byType(Scaffold).first))
    .routerDelegate
    .currentConfiguration
    .last
    .matchedLocation;

Future<void> _enter(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(_k(key));
  await tester.enterText(_k(key), text);
  await tester.pump();
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(_k('business-edit-save'));
  await tester.pumpAndSettle();
}

Future<void> _openFromProfile(WidgetTester tester, EditableBusinessRepository repo) async {
  await _open(tester, repo);
  await tester.ensureVisible(_k('profile-edit-business'));
  await tester.pumpAndSettle();
  await tester.tap(_k('profile-edit-business'));
  await tester.pumpAndSettle();
}

void main() {
  group('navigation depuis Profil', () {
    testWidgets('« Modifier ma boutique » ouvre l\'écran avec les valeurs enregistrées',
        (tester) async {
      await _openFromProfile(tester, EditableBusinessRepository(_shop()));
      expect(_path(tester), Routes.editBusiness);
      expect(find.text('Modifier ma boutique'), findsWidgets);
      expect(tester.widget<TextField>(_k('business-edit-name')).controller!.text,
          'Boutique Mama Aïcha');
      expect(tester.widget<TextField>(_k('business-edit-owner')).controller!.text, 'Aïcha Oumarou');
      expect(tester.widget<TextField>(_k('business-edit-repere')).controller!.text,
          'Près du manguier');
      expect(tester.widget<TextField>(_k('business-edit-description')).controller!.text,
          'Fruits et légumes');
      // Le lieu enregistré est lu depuis le serveur, le numéro reste masqué et non modifiable.
      expect(find.text('Maroua'), findsOneWidget);
      expect(find.text('+237 6•• •• •• 12'), findsOneWidget);
      // Rien n'a changé : rien à enregistrer.
      expect(tester.widget<FilledButton>(find.descendant(
              of: _k('business-edit-save'), matching: find.byType(FilledButton))).onPressed,
          isNull);
      expect(find.text('Aucune modification pour l\'instant.'), findsOneWidget);
    });

    testWidgets('sans compte business : aucune entrée « Modifier ma boutique »', (tester) async {
      await _open(tester, EditableBusinessRepository(_shop()),
          me: Me(id: 1, name: 'Jeff N.', phoneMasked: '+237 6•• •• •• 12'));
      expect(_k('profile-edit-business'), findsNothing);
      expect(find.text('Modifier ma boutique'), findsNothing);
    });

    testWidgets('l\'écran est protégé par la garde de connexion', (tester) async {
      await _open(tester, EditableBusinessRepository(_shop()),
          start: Routes.editBusiness, me: _me);
      expect(_path(tester), Routes.editBusiness);
    });

    testWidgets('déconnecté : l\'adresse mène à la connexion, pas à l\'écran', (tester) async {
      await pumpBusinessApp(
        tester,
        initialLocation: Routes.editBusiness,
        signedIn: false,
        overrides: [
          businessRepositoryProvider.overrideWithValue(EditableBusinessRepository(_shop())),
        ],
      );
      expect(_k('business-edit-name'), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('champs non sensibles', () {
    testWidgets('description et repère : enregistrés sans avertissement ni re-validation',
        (tester) async {
      final repo = EditableBusinessRepository(_shop());
      await _openFromProfile(tester, repo);
      await _enter(tester, 'business-edit-description', 'Fruits, légumes et épices');
      await _enter(tester, 'business-edit-repere', 'Face au marché');
      await _save(tester);

      expect(_k('business-edit-warning'), findsNothing);
      expect(repo.updates, [
        {'repere': 'Face au marché', 'description_activite': 'Fruits, légumes et épices'},
      ]);
      // Retour au Profil, message, le compte reste actif.
      expect(_path(tester), Routes.profile);
      expect(find.text('Modifications enregistrées.'), findsOneWidget);
      expect(repo.current.status, BusinessStatus.active);
      expect(find.text('Actif'), findsOneWidget);
    });

    testWidgets('structure : la description est le champ `description`', (tester) async {
      final repo = EditableBusinessRepository(_shop(type: BusinessAccountType.structure));
      await _openFromProfile(tester, repo);
      expect(tester.widget<TextField>(_k('business-edit-description')).controller!.text,
          'Cadre climatisé');
      await _enter(tester, 'business-edit-description', 'Salle pour événements');
      await _save(tester);
      expect(repo.updates.single, {'description': 'Salle pour événements'});
    });

    testWidgets('prestataire : pas de description, CNI et diplôme proposés', (tester) async {
      final repo =
          EditableBusinessRepository(_shop(type: BusinessAccountType.prestataireService));
      await _openFromProfile(tester, repo);
      expect(_k('business-edit-description'), findsNothing);
      await tester.ensureVisible(_k('business-edit-cni'));
      expect(_k('business-edit-cni'), findsOneWidget);
      expect(_k('business-edit-diploma'), findsOneWidget);
    });

    testWidgets('nouvelle photo : envoyée (signature) puis sa clé part dans le PATCH',
        (tester) async {
      final repo = EditableBusinessRepository(_shop());
      await _openFromProfile(tester, repo);
      expect(find.text('Une photo est déjà enregistrée. Choisissez-en une nouvelle pour la remplacer.'),
          findsWidgets);
      await tester.ensureVisible(_k('business-edit-photo'));
      await tester.tap(_k('business-edit-photo'));
      await tester.pumpAndSettle();
      await tester.tap(_k('photo-gallery'));
      await tester.pumpAndSettle();
      await _save(tester);

      expect(repo.signedKinds, ['photo']);
      expect(repo.updates.single, {'photo': 'u1/photo/1'});
      expect(_k('business-edit-warning'), findsNothing);
      expect(repo.current.status, BusinessStatus.active);
    });

    testWidgets('photo refusée par le serveur : message sur la photo, rien n\'est perdu',
        (tester) async {
      final repo = EditableBusinessRepository(_shop())
        ..signErrors.add(const ApiException(ApiErrorCode.unknown,
            statusCode: 400, serverCode: ServerCodes.invalidType));
      await _openFromProfile(tester, repo);
      await _enter(tester, 'business-edit-repere', 'Autre repère');
      await tester.ensureVisible(_k('business-edit-photo'));
      await tester.tap(_k('business-edit-photo'));
      await tester.pumpAndSettle();
      await tester.tap(_k('photo-gallery'));
      await tester.pumpAndSettle();
      await _save(tester);

      expect(repo.updates, isEmpty);
      expect(_path(tester), Routes.editBusiness);
      expect(find.textContaining('Une photo est refusée'), findsWidgets);
      expect(tester.widget<TextField>(_k('business-edit-repere')).controller!.text, 'Autre repère');
    });
  });

  group('champs sensibles (D-08)', () {
    testWidgets('compte actif, nom changé : avertissement AVANT l\'envoi ; accepté -> enregistré',
        (tester) async {
      final repo = EditableBusinessRepository(_shop());
      await _openFromProfile(tester, repo);
      await _enter(tester, 'business-edit-name', 'Chez Aïcha');
      await tester.tap(_k('business-edit-save'));
      await tester.pumpAndSettle();

      expect(_k('business-edit-warning'), findsOneWidget);
      expect(find.text('Nouvelle validation nécessaire'), findsOneWidget);
      expect(find.textContaining('Vous changez le nom.'), findsOneWidget);
      expect(find.textContaining('en attente de validation'), findsOneWidget);
      // Rien n'est parti tant que la personne n'a pas confirmé.
      expect(repo.updates, isEmpty);

      await tester.tap(_k('business-edit-warning-confirm'));
      await tester.pumpAndSettle();
      expect(repo.updates.single, {'name': 'Chez Aïcha'});
      expect(_path(tester), Routes.profile);
      expect(
          find.text('Modifications enregistrées. Votre compte est en attente de validation.'),
          findsOneWidget);
      expect(find.text('En attente de validation'), findsOneWidget);
    });

    testWidgets('avertissement refusé : rien n\'est envoyé et la saisie est gardée',
        (tester) async {
      final repo = EditableBusinessRepository(_shop());
      await _openFromProfile(tester, repo);
      await _enter(tester, 'business-edit-name', 'Chez Aïcha');
      await tester.tap(_k('business-edit-save'));
      await tester.pumpAndSettle();
      await tester.tap(_k('business-edit-warning-cancel'));
      await tester.pumpAndSettle();

      expect(repo.updates, isEmpty);
      expect(_path(tester), Routes.editBusiness);
      expect(_k('business-edit-warning'), findsNothing);
      expect(tester.widget<TextField>(_k('business-edit-name')).controller!.text, 'Chez Aïcha');
      expect(repo.current.status, BusinessStatus.active);
    });

    testWidgets('lieu changé : avertissement « le lieu » ; nom et lieu : « le nom et le lieu »',
        (tester) async {
      final repo = EditableBusinessRepository(_shop());
      await _openFromProfile(tester, repo);
      await tester.ensureVisible(_k('business-edit-location'));
      await tester.tap(_k('business-edit-location'));
      await tester.pumpAndSettle();
      await tester.tap(_k('edit-city-16'));
      await tester.pumpAndSettle();
      await tester.tap(_k('edit-district-17'));
      await tester.pumpAndSettle();
      expect(find.text('Maroua, Hardé'), findsOneWidget);

      await tester.tap(_k('business-edit-save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Vous changez le lieu.'), findsOneWidget);
      await tester.tap(_k('business-edit-warning-cancel'));
      await tester.pumpAndSettle();

      await _enter(tester, 'business-edit-name', 'Chez Aïcha');
      await tester.tap(_k('business-edit-save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Vous changez le nom et le lieu.'), findsOneWidget);
      await tester.tap(_k('business-edit-warning-confirm'));
      await tester.pumpAndSettle();
      expect(repo.updates.single, {'name': 'Chez Aïcha', 'zone': 17});
    });

    testWidgets('une ville seule (« Je ne trouve pas mon quartier ») donne la zone de la ville',
        (tester) async {
      final repo = EditableBusinessRepository(
          MyBusiness(status: BusinessStatus.active, name: 'X', typeCompte: BusinessAccountType.boutique, zoneId: 17, representantNom: 'Y'));
      await _openFromProfile(tester, repo);
      await tester.ensureVisible(_k('business-edit-location'));
      await tester.tap(_k('business-edit-location'));
      await tester.pumpAndSettle();
      await tester.tap(_k('edit-city-16'));
      await tester.pumpAndSettle();
      await tester.tap(_k('edit-district-none'));
      await tester.pumpAndSettle();
      expect(find.text('Maroua'), findsOneWidget);
      await tester.tap(_k('business-edit-save'));
      await tester.pumpAndSettle();
      await tester.tap(_k('business-edit-warning-confirm'));
      await tester.pumpAndSettle();
      expect(repo.updates.single, {'zone': 16});
    });

    testWidgets('fermer le choix du lieu ne change rien', (tester) async {
      final repo = EditableBusinessRepository(_shop());
      await _openFromProfile(tester, repo);
      await tester.ensureVisible(_k('business-edit-location'));
      await tester.tap(_k('business-edit-location'));
      await tester.pumpAndSettle();
      await tester.tap(_k('edit-location-close'));
      await tester.pumpAndSettle();
      expect(find.text('Aucune modification pour l\'instant.'), findsOneWidget);
    });

    testWidgets('compte en attente : le nom se change sans avertissement', (tester) async {
      final repo = EditableBusinessRepository(_shop(status: BusinessStatus.pending));
      await _openFromProfile(tester, repo);
      await _enter(tester, 'business-edit-name', 'Chez Aïcha');
      await _save(tester);
      expect(_k('business-edit-warning'), findsNothing);
      expect(repo.updates.single, {'name': 'Chez Aïcha'});
    });

    testWidgets('le corps ne contient jamais le numéro ni le type', (tester) async {
      final repo = EditableBusinessRepository(_shop());
      await _openFromProfile(tester, repo);
      await _enter(tester, 'business-edit-owner', 'Aïcha O.');
      await _save(tester);
      final body = repo.updates.single;
      expect(body.keys, ['representant_nom']);
      expect(body.containsKey('phone_anchor'), isFalse);
      expect(body.containsKey('type_compte'), isFalse);
    });
  });

  group('profil rejeté (T026.6)', () {
    testWidgets('Profil : motif et « Corriger » -> écran de correction -> renvoi',
        (tester) async {
      final repo = EditableBusinessRepository(
          _shop(status: BusinessStatus.rejected, motif: 'Photo du propriétaire floue'));
      await _open(tester, repo);
      expect(find.text('Motif : Photo du propriétaire floue'), findsOneWidget);
      await tester.ensureVisible(_k('profile-business-correct'));
      await tester.pumpAndSettle();
      expect(find.text('Corriger'), findsOneWidget);
      await tester.tap(_k('profile-business-correct'));
      await tester.pumpAndSettle();

      expect(_path(tester), Routes.editBusiness);
      expect(find.text('Corriger ma demande'), findsOneWidget);
      expect(find.text('Votre demande a été rejetée'), findsOneWidget);
      expect(find.text('Motif : Photo du propriétaire floue'), findsOneWidget);
      expect(find.text('Corriger et renvoyer'), findsOneWidget);
      // Sans correction, on ne peut pas renvoyer.
      expect(tester.widget<FilledButton>(find.descendant(
              of: _k('business-edit-save'), matching: find.byType(FilledButton))).onPressed,
          isNull);

      await tester.ensureVisible(_k('business-edit-owner-photo'));
      await tester.tap(_k('business-edit-owner-photo'));
      await tester.pumpAndSettle();
      await tester.tap(_k('photo-camera'));
      await tester.pumpAndSettle();
      await _save(tester);

      // Pas d'avertissement D-08 (le compte n'est pas actif) ; renvoyé en attente.
      expect(_k('business-edit-warning'), findsNothing);
      expect(repo.signedKinds, ['representant_photo']);
      expect(repo.updates.single, {'representant_photo': 'u1/representant_photo/1'});
      expect(repo.current.status, BusinessStatus.pending);
      expect(repo.current.motifRejet, '');
      expect(_path(tester), Routes.profile);
      expect(find.text('Demande corrigée et renvoyée. L\'équipe NetBuis va l\'examiner de nouveau.'),
          findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('En attente de validation'), findsOneWidget);
      expect(find.text('Motif : Photo du propriétaire floue'), findsNothing);
      expect(_k('profile-business-correct'), findsNothing);
    });

    testWidgets('« Corriger » n\'existe que pour un compte rejeté', (tester) async {
      for (final status in [BusinessStatus.active, BusinessStatus.pending]) {
        await _open(tester, EditableBusinessRepository(_shop(status: status)));
        expect(_k('profile-business-correct'), findsNothing, reason: '$status');
        expect(find.text('Corriger'), findsNothing, reason: '$status');
        expect(_k('profile-edit-business'), findsOneWidget, reason: '$status');
      }
    });
  });

  group('erreurs', () {
    testWidgets('réseau coupé à l\'enregistrement : message, saisie gardée, nouvel essai réussit',
        (tester) async {
      final repo = EditableBusinessRepository(_shop())
        ..updateErrors.add(const ApiException(ApiErrorCode.network));
      await _openFromProfile(tester, repo);
      await _enter(tester, 'business-edit-repere', 'Nouveau repère');
      await _save(tester);

      expect(_path(tester), Routes.editBusiness);
      expect(find.text('Pas de connexion. Vos modifications sont conservées : réessayez.'),
          findsOneWidget);
      expect(tester.widget<TextField>(_k('business-edit-repere')).controller!.text, 'Nouveau repère');

      await _save(tester);
      expect(repo.updates.length, 2);
      expect(_path(tester), Routes.profile);
    });

    testWidgets('validation serveur par champ : erreur sous le champ, effacée à la saisie',
        (tester) async {
      final repo = EditableBusinessRepository(_shop(status: BusinessStatus.pending))
        ..updateErrors.add(const ApiException(ApiErrorCode.invalid,
            statusCode: 400, serverCode: 'invalid', fieldNames: ['name', 'zone']));
      await _openFromProfile(tester, repo);
      await _enter(tester, 'business-edit-name', 'Nom refusé');
      await _save(tester);

      expect(_path(tester), Routes.editBusiness);
      expect(find.text('Certains champs sont refusés. Corrigez ceux qui sont signalés en rouge.'),
          findsOneWidget);
      expect(find.text('Ce champ est refusé par le serveur. Corrigez-le puis réessayez.'),
          findsNWidgets(2));
      await _enter(tester, 'business-edit-name', 'Nom accepté');
      expect(find.text('Ce champ est refusé par le serveur. Corrigez-le puis réessayez.'),
          findsOneWidget);
    });

    testWidgets('plafond sans abonnement (SUBSCRIPTION_REQUIRED) : message clair', (tester) async {
      final repo = EditableBusinessRepository(_shop())
        ..updateErrors.add(const ApiException(ApiErrorCode.invalid,
            statusCode: 400, serverCode: ServerCodes.subscriptionRequired));
      await _openFromProfile(tester, repo);
      await _enter(tester, 'business-edit-repere', 'x');
      await _save(tester);
      expect(find.text('Limite atteinte : cette modification demande un abonnement.'),
          findsOneWidget);
    });

    testWidgets('autre erreur du serveur : message court, jamais le texte du serveur',
        (tester) async {
      final repo = EditableBusinessRepository(_shop())
        ..updateErrors.add(const ApiException(ApiErrorCode.unknown,
            statusCode: 500, message: 'Traceback secret'));
      await _openFromProfile(tester, repo);
      await _enter(tester, 'business-edit-repere', 'x');
      await _save(tester);
      expect(find.text('L\'enregistrement a échoué. Vos modifications sont conservées : réessayez.'),
          findsOneWidget);
      expect(find.textContaining('Traceback'), findsNothing);
    });

    testWidgets('nom vidé : erreur locale, aucun envoi', (tester) async {
      final repo = EditableBusinessRepository(_shop());
      await _openFromProfile(tester, repo);
      await _enter(tester, 'business-edit-name', '   ');
      await _save(tester);
      expect(find.text('Entrez un nom.'), findsOneWidget);
      expect(repo.updates, isEmpty);
      expect(_k('business-edit-warning'), findsNothing);
    });

    testWidgets('lecture impossible (réseau) : message et « Réessayer »', (tester) async {
      final repo = EditableBusinessRepository(_shop())
        ..getErrors.add(const ApiException(ApiErrorCode.network));
      await _open(tester, repo, start: Routes.editBusiness);
      expect(find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'), findsOneWidget);
      await tester.tap(_k('business-edit-retry'));
      await tester.pumpAndSettle();
      expect(_k('business-edit-name'), findsOneWidget);
    });
  });

  group('changements non enregistrés', () {
    testWidgets('retour sans modification : on quitte tout de suite', (tester) async {
      await _openFromProfile(tester, EditableBusinessRepository(_shop()));
      await tester.tap(_k('business-edit-back'));
      await tester.pumpAndSettle();
      expect(_k('business-edit-leave'), findsNothing);
      expect(_path(tester), Routes.profile);
    });

    testWidgets('retour avec modification : confirmation ; « Continuer » garde la saisie',
        (tester) async {
      final repo = EditableBusinessRepository(_shop());
      await _openFromProfile(tester, repo);
      await _enter(tester, 'business-edit-repere', 'Autre repère');
      await tester.tap(_k('business-edit-back'));
      await tester.pumpAndSettle();
      expect(find.text('Quitter sans enregistrer ?'), findsOneWidget);

      await tester.tap(_k('business-edit-leave-stay'));
      await tester.pumpAndSettle();
      expect(_path(tester), Routes.editBusiness);
      expect(tester.widget<TextField>(_k('business-edit-repere')).controller!.text, 'Autre repère');

      await tester.tap(_k('business-edit-back'));
      await tester.pumpAndSettle();
      await tester.tap(_k('business-edit-leave-confirm'));
      await tester.pumpAndSettle();
      expect(_path(tester), Routes.profile);
      expect(repo.updates, isEmpty);
    });

    testWidgets('geste « retour » du système : même confirmation', (tester) async {
      await _openFromProfile(tester, EditableBusinessRepository(_shop()));
      await _enter(tester, 'business-edit-repere', 'Autre repère');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_k('business-edit-leave'), findsOneWidget);
      expect(_path(tester), Routes.editBusiness);
    });

    testWidgets('revenir à la valeur d\'origine n\'est pas une modification', (tester) async {
      await _openFromProfile(tester, EditableBusinessRepository(_shop()));
      await _enter(tester, 'business-edit-repere', 'Autre repère');
      await _enter(tester, 'business-edit-repere', 'Près du manguier');
      await tester.tap(_k('business-edit-back'));
      await tester.pumpAndSettle();
      expect(_path(tester), Routes.profile);
    });
  });

  testWidgets('360 px, police 130 %, clair et sombre : écran sans débordement', (tester) async {
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      await pumpBusinessApp(
        tester,
        initialLocation: Routes.editBusiness,
        account: ScriptedAccountRepository(me: _me),
        overrides: [
          businessRepositoryProvider.overrideWithValue(
              EditableBusinessRepository(_shop(status: BusinessStatus.rejected, motif: 'Photo floue'))),
        ],
        textScale: 1.3,
        mode: mode,
      );
      expect(_k('business-edit-name'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$mode');
    }
  });
}

