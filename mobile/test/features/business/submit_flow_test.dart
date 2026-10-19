import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/account/data/models/me.dart';
import 'package:netbuis/features/account/data/repositories/account_repository_fake.dart';
import 'package:netbuis/features/business/application/business_draft_controller.dart';
import 'package:netbuis/features/business/application/business_services.dart';
import 'package:netbuis/features/business/data/models/business.dart';
import 'package:netbuis/features/business/data/models/business_draft.dart';
import 'package:netbuis/features/business/data/repositories/business_repository.dart';
import 'package:netbuis/features/business/data/repositories/business_repository_fake.dart';

import '../account/account_test_helpers.dart';
import 'business_submit_helpers.dart';
import 'business_test_helpers.dart';

Finder get _submit => find.text('Publier ma demande');
Finder get _retry => find.text('Réessayer');
Finder get _error => find.byKey(const ValueKey('recap-error'));

const _sentBody =
    "Nous examinons votre dossier. Vous pourrez suivre l'état de votre demande dans Profil — généralement sous 24 heures.";

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

Me _meWithBusiness() => const Me(
    id: 1, name: 'Jeff N.', phoneMasked: '+237 6•• •• •• 12', hasBusiness: true);

/// Dépôt « business » scénarisé pour la carte d'état du Profil.
class ScriptedBusinessRepository implements BusinessRepository {
  ScriptedBusinessRepository(this.script);

  /// Chaque lecture consomme un élément : un [MyBusiness] ou une [ApiException].
  final List<Object> script;
  int getCalls = 0;

  @override
  Future<MyBusiness> getMine() async {
    getCalls++;
    final next = script.length > 1 ? script.removeAt(0) : script.first;
    if (next is ApiException) throw next;
    return next as MyBusiness;
  }

  @override
  Future<UploadTicket> signUpload(
          {required String kind, required String contentType, required int size}) =>
      throw StateError('Non utilisé par ces tests');

  @override
  Future<void> putFile(UploadTicket ticket, Uint8List bytes) => throw StateError('Non utilisé par ces tests');

  @override
  Future<MyBusiness> create(Map<String, Object?> body) => throw StateError('Non utilisé par ces tests');
}

Future<void> _openProfile(
  WidgetTester tester, {
  required ScriptedAccountRepository account,
  required BusinessRepository business,
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.dark,
}) =>
    pumpBusinessApp(
      tester,
      initialLocation: Routes.profile,
      account: account,
      textScale: textScale,
      mode: mode,
      overrides: [businessRepositoryProvider.overrideWithValue(business)],
    );

void main() {
  group('envoi depuis l\'écran', () {
    testWidgets('succès : progression, « Demande envoyée » (24 heures), brouillon vidé, Profil',
        (tester) async {
      final server = MockBusinessServer();
      final account = ScriptedAccountRepository(me: meWith(name: 'Jeff N.'));
      server.script = (event, req) {
        if (event == 'post') account.me = _meWithBusiness();
        return null;
      };
      final container = await openRecap(
        tester,
        await completeDraft(BusinessAccountType.boutique),
        overrides: server.overrides(),
        account: account,
      );
      expect(container.read(businessDraftProvider).name, isNotEmpty);

      await tester.tap(_submit);
      await tester.pumpAndSettle();

      // Ordre : sign -> PUT pour chaque photo, puis la demande.
      expect(server.events,
          ['sign:photo', 'put:photo', 'sign:representant_photo', 'put:representant_photo', 'post']);
      // Écran « Demande envoyée » (maquette), « Vous recevrez une notification » remplacé.
      expect(find.text('Demande envoyée'), findsOneWidget);
      expect(find.text(_sentBody), findsOneWidget);
      expect(find.textContaining('notification'), findsNothing);
      expect(find.textContaining('24 heures'), findsOneWidget);
      expect(find.text("Retour à l'accueil"), findsOneWidget);
      expect(find.text('Voir mon profil'), findsOneWidget);
      expect(_submit, findsNothing);

      // Brouillon vidé : nom, photos locales et clés envoyées ont disparu.
      final draft = container.read(businessDraftProvider);
      expect(draft.name, '');
      expect(draft.photoPath, isNull);
      expect(draft.representantPhotoPath, isNull);
      expect(draft.uploaded, isEmpty);
      expect(draft.zoneId, isNull);

      // Retour au Profil : l'état « en attente » remplace l'invitation.
      await tester.tap(find.text('Voir mon profil'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-business-status')), findsOneWidget);
      expect(find.text('COMPTE BUSINESS'), findsOneWidget);
      expect(find.text('En attente de validation'), findsOneWidget);
      expect(find.text('Activer mon compte Business'), findsNothing);
      expect(find.byKey(const ValueKey('profile-create-business')), findsNothing);
      expect(server.events.last, 'get-me');
    });

    testWidgets('« Retour à l\'accueil » mène à l\'Accueil ; le retour système mène au Profil',
        (tester) async {
      final server = MockBusinessServer();
      await openRecap(tester, await completeDraft(BusinessAccountType.boutique),
          overrides: server.overrides());
      await tester.tap(_submit);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sent-home')));
      await tester.pumpAndSettle();
      expect(onHome(), isTrue);
      expect(find.text('Demande envoyée'), findsNothing);

      await openRecap(tester, await completeDraft(BusinessAccountType.boutique),
          overrides: MockBusinessServer().overrides());
      await tester.tap(_submit);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Demande envoyée'), findsNothing);
      expect(find.text('Mon profil'), findsOneWidget);
    });

    testWidgets('progression visible et annoncée ; retour bloqué pendant l\'envoi', (tester) async {
      final handle = tester.ensureSemantics();
      final server = MockBusinessServer()..putGate = Completer<void>();
      await openRecap(tester, await completeDraft(BusinessAccountType.boutique),
          overrides: server.overrides());

      await tester.tap(_submit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const ValueKey('recap-progress')), findsOneWidget);
      expect(find.text('Envoi des photos (1 sur 2)…'), findsOneWidget);
      expect(find.bySemanticsLabel('Envoi en cours, étape 1 sur 3'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // Le bouton est remplacé par un indicateur : pas de double envoi.
      expect(_submit, findsNothing);
      // Le retour (bouton et geste système) est bloqué pendant l'envoi.
      await tester.tap(find.byKey(const ValueKey('business-back')));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Récapitulatif'), findsOneWidget);

      server.putGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Demande envoyée'), findsOneWidget);
      expect(server.accepted, {'photo': 1, 'representant_photo': 1});
      handle.dispose();
    });

    testWidgets('coupure réseau : message simple, « Réessayer » reprend où on s\'est arrêté',
        (tester) async {
      final server = MockBusinessServer();
      var cut = true;
      server.script = (event, req) {
        if (event == 'put:representant_photo' && cut) {
          cut = false;
          throw server.cut(req);
        }
        return null;
      };
      final container = await openRecap(tester, await completeDraft(BusinessAccountType.boutique),
          overrides: server.overrides());

      await tester.tap(_submit);
      await tester.pumpAndSettle();

      expect(find.text("Pas de connexion. Rien n'est perdu : réessayez quand le réseau est revenu."),
          findsOneWidget);
      expect(_retry, findsOneWidget);
      expect(_submit, findsNothing);
      expect(find.text('Récapitulatif'), findsOneWidget);
      // Rien n'est perdu à l'écran ni en mémoire.
      expect(find.text('Boutique Mama Aïcha'), findsOneWidget);
      expect(container.read(businessDraftProvider).photoPath, '/fictif/commerce.png');
      expect(container.read(businessDraftProvider).uploaded.keys, ['photo']);
      expect(tester.getSize(find.ancestor(of: _retry, matching: find.byType(FilledButton)).first)
              .height,
          greaterThanOrEqualTo(48));

      server.events.clear();
      await tester.tap(_retry);
      await tester.pumpAndSettle();
      expect(server.events, ['sign:representant_photo', 'put:representant_photo', 'post']);
      expect(find.text('Demande envoyée'), findsOneWidget);
    });

    testWidgets('quitter le parcours après un échec vide le brouillon, les photos et les clés',
        (tester) async {
      final server = MockBusinessServer();
      server.script = (event, req) {
        if (event == 'post') throw server.cut(req);
        return null;
      };
      final container = await openRecap(tester, await completeDraft(BusinessAccountType.boutique),
          overrides: server.overrides());
      await tester.tap(_submit);
      await tester.pumpAndSettle();
      expect(container.read(businessDraftProvider).uploaded, isNotEmpty);

      GoRouter.of(tester.element(find.byType(Scaffold).first)).go(Routes.profile);
      await tester.pumpAndSettle();

      final fresh = _container(tester).read(businessDraftProvider);
      expect(fresh.name, '');
      expect(fresh.photoPath, isNull);
      expect(fresh.representantPhotoPath, isNull);
      expect(fresh.uploaded, isEmpty);
    });

    testWidgets('400 par champ : message général puis « Corriger » ouvre l\'écran concerné',
        (tester) async {
      final server = MockBusinessServer();
      server.script = (event, req) => event == 'post'
          ? MockBusinessServer.reply(400, {
              'code': 'invalid',
              'message': 'MESSAGE-BRUT-DU-SERVEUR',
              'fields': {'zone': ['MESSAGE-BRUT-DU-CHAMP']},
            })
          : null;
      await openRecap(tester, await completeDraft(BusinessAccountType.boutique),
          overrides: server.overrides());
      await tester.tap(_submit);
      await tester.pumpAndSettle();

      expect(find.text('Certaines informations sont à corriger.'), findsOneWidget);
      expect(find.textContaining('MESSAGE-BRUT'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('recap-fix')));
      await tester.pumpAndSettle();
      expect(find.text('Choisir le lieu de votre commerce'), findsOneWidget);
    });

    testWidgets('champ « name » refusé : « Corriger » mène aux Informations', (tester) async {
      final server = MockBusinessServer();
      server.script = (event, req) => event == 'post'
          ? MockBusinessServer.reply(400, {
              'code': 'invalid',
              'message': 'x',
              'fields': {'name': ['x']},
            })
          : null;
      await openRecap(tester, await completeDraft(BusinessAccountType.boutique),
          overrides: server.overrides());
      await tester.tap(_submit);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('recap-fix')));
      await tester.pumpAndSettle();
      expect(find.text('Informations de base'), findsOneWidget);
    });

    testWidgets('SUBSCRIPTION_REQUIRED : message court et renvoi à l\'écran Détails', (tester) async {
      final server = MockBusinessServer();
      server.script = (event, req) => event == 'post'
          ? MockBusinessServer.reply(400, {
              'code': 'SUBSCRIPTION_REQUIRED',
              'message': 'MESSAGE-BRUT-DU-SERVEUR',
            })
          : null;
      await openRecap(tester, await completeDraft(BusinessAccountType.boutique),
          overrides: server.overrides());
      await tester.tap(_submit);
      await tester.pumpAndSettle();

      expect(
          find.text(
              'Vous avez choisi plus de 3 éléments : retirez-en pour envoyer, ou abonnez-vous plus tard.'),
          findsOneWidget);
      expect(find.textContaining('MESSAGE-BRUT'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('recap-fix')));
      await tester.pumpAndSettle();
      expect(find.text('Précisez votre activité'), findsOneWidget);
    });

    testWidgets('SUBSCRIPTION_REQUIRED en Structure : renvoi aux Détails de l\'établissement',
        (tester) async {
      final server = MockBusinessServer();
      server.script = (event, req) => event == 'post'
          ? MockBusinessServer.reply(400, {'code': 'SUBSCRIPTION_REQUIRED', 'message': 'x'})
          : null;
      await openRecap(tester, await completeDraft(BusinessAccountType.structure),
          overrides: server.overrides());
      await tester.tap(_submit);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('recap-fix')));
      await tester.pumpAndSettle();
      expect(find.text('Étape 3 sur 4'), findsOneWidget);
      expect(find.text("Détails de l'établissement"), findsOneWidget);
    });

    testWidgets('429 : « Trop de demandes, réessayez plus tard. », on peut réessayer', (tester) async {
      final server = MockBusinessServer();
      var once = true;
      server.script = (event, req) {
        if (event == 'sign:photo' && once) {
          once = false;
          return MockBusinessServer.reply(429, {'code': 'throttled', 'message': 'MESSAGE-BRUT'});
        }
        return null;
      };
      await openRecap(tester, await completeDraft(BusinessAccountType.boutique),
          overrides: server.overrides());
      await tester.tap(_submit);
      await tester.pumpAndSettle();
      expect(find.text('Trop de demandes, réessayez plus tard.'), findsOneWidget);
      expect(find.textContaining('MESSAGE-BRUT'), findsNothing);
      await tester.tap(_retry);
      await tester.pumpAndSettle();
      expect(find.text('Demande envoyée'), findsOneWidget);
    });

    testWidgets('401 après renouvellement refusé : message de session, brouillon conservé',
        (tester) async {
      final server = MockBusinessServer();
      server.script = (event, req) => event == 'post'
          ? MockBusinessServer.reply(401, {'code': 'token_not_valid', 'message': 'MESSAGE-BRUT'})
          : null;
      final container = await openRecap(tester, await completeDraft(BusinessAccountType.boutique),
          overrides: server.overrides());
      await tester.tap(_submit);
      await tester.pumpAndSettle();

      expect(find.text('Votre session a expiré. Reconnectez-vous : votre demande n\'a pas été envoyée.'),
          findsOneWidget);
      expect(find.textContaining('MESSAGE-BRUT'), findsNothing);
      expect(container.read(businessDraftProvider).name, 'Boutique Mama Aïcha');
      expect(server.refreshCalls, 1);
    });

    testWidgets('409 business_exists : succès après relecture de l\'état', (tester) async {
      final server = MockBusinessServer()..businessExists = true;
      await openRecap(tester, await completeDraft(BusinessAccountType.boutique),
          overrides: server.overrides());
      await tester.tap(_submit);
      await tester.pumpAndSettle();
      expect(server.events.takeLast(2), ['post', 'get-me']);
      expect(find.text('Demande envoyée'), findsOneWidget);
    });

    testWidgets('photo refusée : message, « Corriger » ouvre l\'écran de la photo', (tester) async {
      final server = MockBusinessServer();
      server.script = (event, req) => event == 'put:cni_photo'
          ? MockBusinessServer.reply(400, {'code': 'invalid_content', 'message': 'x'})
          : null;
      await openRecap(tester, await completeDraft(BusinessAccountType.prestataireService),
          overrides: server.overrides());
      await tester.tap(_submit);
      await tester.pumpAndSettle();
      expect(find.text('Une photo n\'a pas pu être envoyée (format ou taille). Choisissez-en une autre.'),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('recap-fix')));
      await tester.pumpAndSettle();
      expect(find.text('Quel type de service proposez-vous ?'), findsOneWidget);
    });

    testWidgets('photo du commerce absente : rien n\'est envoyé, « Corriger » mène aux Informations',
        (tester) async {
      final server = MockBusinessServer();
      final base = await completeDraft(BusinessAccountType.boutique);
      await openRecap(tester, base.copyWith(photoPath: null), overrides: server.overrides());
      await tester.tap(_submit);
      await tester.pumpAndSettle();
      expect(
          find.text('Ajoutez la photo de votre activité (obligatoire) pour envoyer votre demande.'),
          findsOneWidget);
      expect(server.events, isEmpty);
      await tester.tap(find.byKey(const ValueKey('recap-fix')));
      await tester.pumpAndSettle();
      expect(find.text('Informations de base'), findsOneWidget);
    });

    testWidgets('compte bloqué et erreur serveur : messages courts, jamais le texte brut',
        (tester) async {
      final server = MockBusinessServer();
      server.script = (event, req) => event == 'post'
          ? MockBusinessServer.reply(500, {'code': 'error', 'message': 'TRACE-INTERNE'})
          : null;
      await openRecap(tester, await completeDraft(BusinessAccountType.boutique),
          overrides: server.overrides());
      await tester.tap(_submit);
      await tester.pumpAndSettle();
      expect(find.text('Une erreur est survenue. Réessayez.'), findsOneWidget);
      expect(find.textContaining('TRACE'), findsNothing);
      expect(_retry, findsOneWidget);
    });

    testWidgets('messages d\'erreur et écrans : aucun chemin, clé, jeton ni numéro, journaux compris',
        (tester) async {
      final logs = <String>[];
      final old = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
      try {
        await runZoned(() async {
          final server = MockBusinessServer();
          var cut = true;
          server.script = (event, req) {
            if (event == 'post' && cut) {
              cut = false;
              throw server.cut(req);
            }
            return null;
          };
          await openRecap(tester, await completeDraft(BusinessAccountType.prestataireService),
              overrides: server.overrides());
          await tester.tap(_submit);
          await tester.pumpAndSettle();
          // Tout le texte affiché pendant l'échec.
          final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '');
          final shown = texts.join('\n');
          for (final secret in ['/fictif', 'u1/', 'cni-secrete', 'tok', '10.0.2.2', 'acc-test']) {
            expect(shown, isNot(contains(secret)), reason: secret);
          }
          await tester.tap(_retry);
          await tester.pumpAndSettle();
        },
            zoneSpecification:
                ZoneSpecification(print: (self, parent, zone, line) => logs.add(line)));
      } finally {
        debugPrint = old;
      }
      final joined = logs.join('\n');
      for (final secret in ['/fictif', 'u1/', 'cni-secrete', 'tok', '10.0.2.2', 'acc-test', '6••']) {
        expect(joined, isNot(contains(secret)), reason: secret);
      }
    });

    for (final scale in [1.0, 1.3]) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('erreur et progression à 360 px, police ${(scale * 100).round()} %, $mode',
            (tester) async {
          final server = MockBusinessServer();
          server.script = (event, req) => event == 'post'
              ? MockBusinessServer.reply(400, {'code': 'SUBSCRIPTION_REQUIRED', 'message': 'x'})
              : null;
          await openRecap(tester, await completeDraft(BusinessAccountType.boutique),
              overrides: server.overrides(), textScale: scale, mode: mode);
          await tester.tap(_submit);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          final error = tester.getRect(_error);
          expect(error.left, greaterThanOrEqualTo(0));
          expect(error.right, lessThanOrEqualTo(360));
          final fix = tester.getSize(find.byKey(const ValueKey('recap-fix')));
          expect(fix.height, greaterThanOrEqualTo(48));
          // Le bouton d'envoi reste visible (la barre du bas ne sort pas de l'écran).
          expect(tester.getRect(find.ancestor(of: _submit, matching: find.byType(FilledButton)).first)
                  .bottom,
              lessThanOrEqualTo(780));
        });
      }
    }
  });

  group('mode factice, de bout en bout', () {
    testWidgets('Informations -> Secteur -> Détails -> Récapitulatif -> Demande envoyée -> Profil',
        (tester) async {
      final accountFake = AccountRepositoryFake();
      final photos = FakePhotoPicker();
      await pumpBusinessApp(
        tester,
        photos: photos,
        account: accountFake,
        overrides: [
          businessRepositoryProvider
              .overrideWithValue(BusinessRepositoryFake(onCreated: accountFake.markHasBusiness)),
          photoBytesReaderProvider.overrideWithValue((path) async => fakeJpeg(64)),
        ],
      );
      Future<void> tapVisible(Finder f) async {
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      await tester.enterText(find.byKey(const ValueKey('business-name')), 'Chez Aïcha');
      await tester.enterText(find.byKey(const ValueKey('business-owner')), 'Aïcha B.');
      photos.result = '/fictif/commerce.jpg';
      await tapVisible(find.byKey(const ValueKey('business-photo')));
      await tester.tap(find.byKey(const ValueKey('photo-camera')));
      await tester.pumpAndSettle();
      photos.result = '/fictif/personne.jpg';
      await tapVisible(find.byKey(const ValueKey('business-owner-photo')));
      await tester.tap(find.byKey(const ValueKey('photo-camera')));
      await tester.pumpAndSettle();
      await tapVisible(continueButton);

      await tapVisible(find.byKey(const ValueKey('business-sector-alimentation')));
      await tapVisible(continueButton);
      await tapVisible(find.byKey(const ValueKey('business-sub-1')));
      await tapVisible(find.byKey(const ValueKey('business-sub-2')));
      await tapVisible(continueButton);

      // Récapitulatif : dernière étape du parcours.
      expect(find.text('Étape 4 sur 4'), findsOneWidget);
      expect(find.text('Chez Aïcha'), findsOneWidget);
      expect(find.text('Maroua'), findsOneWidget);
      expect(find.text('+237 6•• •• •• 12 ✓'), findsOneWidget);
      await tapVisible(_submit);

      expect(find.text('Demande envoyée'), findsOneWidget);
      await tester.tap(find.text('Voir mon profil'));
      await tester.pumpAndSettle();
      expect(find.text('En attente de validation'), findsOneWidget);
      expect(find.text('Activer mon compte Business'), findsNothing);
      expect(_container(tester).read(businessDraftProvider).name, '');
    });

    test('les fournisseurs en mode factice sont reliés entre eux (USE_FAKE_API=true)', () async {
      final container = ProviderContainer(overrides: [
        photoBytesReaderProvider.overrideWithValue((path) async => fakeJpeg(64)),
      ]);
      addTearDown(container.dispose);
      final business = container.read(businessRepositoryProvider);
      final account = container.read(accountRepositoryProvider);
      // Le test ne peut pas changer la compilation : sans le réglage, rien à vérifier ici.
      if (business is! BusinessRepositoryFake) {
        expect(const bool.fromEnvironment('USE_FAKE_API'), isFalse);
        return;
      }
      expect(account, isA<AccountRepositoryFake>());
      expect((await account.getMe()).hasBusiness, isFalse);
      await business.create({'name': 'X'});
      expect((await account.getMe()).hasBusiness, isTrue);
      expect((await business.getMine()).status, BusinessStatus.pending);
    });
  });

  group('Profil : carte d\'état du compte business', () {
    testWidgets('sans compte business : l\'invitation reste, pas de carte, aucune lecture',
        (tester) async {
      final business = ScriptedBusinessRepository([const MyBusiness(status: BusinessStatus.active)]);
      await _openProfile(tester,
          account: ScriptedAccountRepository(me: meWith(name: 'Jeff N.')), business: business);
      expect(find.text('Activer mon compte Business'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-business-status')), findsNothing);
      expect(business.getCalls, 0);
    });

    testWidgets('en attente de validation', (tester) async {
      await _openProfile(tester,
          account: ScriptedAccountRepository(me: _meWithBusiness()),
          business: ScriptedBusinessRepository([
            const MyBusiness(status: BusinessStatus.pending, name: 'Boutique Mama Aïcha')
          ]));
      expect(find.text('COMPTE BUSINESS'), findsOneWidget);
      expect(find.text('Boutique Mama Aïcha'), findsOneWidget);
      expect(find.text('En attente de validation'), findsOneWidget);
      expect(find.text('Votre demande est examinée par l\'équipe NetBuis, généralement sous 24 heures.'),
          findsOneWidget);
      expect(find.text('Activer mon compte Business'), findsNothing);
      expect(find.text('Vous vendez un produit ou un service ?'), findsNothing);
    });

    testWidgets('actif', (tester) async {
      await _openProfile(tester,
          account: ScriptedAccountRepository(me: _meWithBusiness()),
          business: ScriptedBusinessRepository([const MyBusiness(status: BusinessStatus.active)]));
      expect(find.text('Actif'), findsOneWidget);
      expect(find.text('Votre compte business est publié.'), findsOneWidget);
      expect(find.text('En attente de validation'), findsNothing);
      expect(find.text('Activer mon compte Business'), findsNothing);
    });

    testWidgets('rejeté : le motif et une indication de correction', (tester) async {
      await _openProfile(tester,
          account: ScriptedAccountRepository(me: _meWithBusiness()),
          business: ScriptedBusinessRepository([
            const MyBusiness(status: BusinessStatus.rejected, motifRejet: 'Photo de la CNI floue')
          ]));
      expect(find.text('Rejeté'), findsOneWidget);
      expect(find.text('Motif : Photo de la CNI floue'), findsOneWidget);
      expect(find.text('Votre demande peut être corrigée puis renvoyée (bientôt disponible).'),
          findsOneWidget);
      expect(find.text('Activer mon compte Business'), findsNothing);
    });

    testWidgets('erreur de lecture : carte discrète avec « Réessayer », le reste du Profil marche',
        (tester) async {
      final business = ScriptedBusinessRepository([
        const ApiException(ApiErrorCode.network),
        const MyBusiness(status: BusinessStatus.pending),
      ]);
      await _openProfile(tester,
          account: ScriptedAccountRepository(me: _meWithBusiness()), business: business);

      expect(find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-business-status-retry')), findsOneWidget);
      // Le reste du Profil n'est pas bloqué.
      expect(find.text('Jeff N.'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-city')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('profile-logout')));
      expect(find.text('Se déconnecter'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('profile-business-status-retry')));
      await tester.pumpAndSettle();
      expect(business.getCalls, 2);
      expect(find.text('En attente de validation'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-business-status-retry')), findsNothing);
    });

    testWidgets('autre erreur (réponse illisible) : texte simple, jamais le texte du serveur',
        (tester) async {
      await _openProfile(tester,
          account: ScriptedAccountRepository(me: _meWithBusiness()),
          business: ScriptedBusinessRepository(
              [const ApiException(ApiErrorCode.unknown, message: 'TRACE-INTERNE')]));
      expect(find.text('Impossible de lire l\'état de votre compte business.'), findsOneWidget);
      expect(find.textContaining('TRACE'), findsNothing);
    });

    for (final scale in [1.0, 1.3]) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('rejeté à 360 px, police ${(scale * 100).round()} %, $mode : « Se déconnecter » reste accessible',
            (tester) async {
          await _openProfile(tester,
              account: ScriptedAccountRepository(me: _meWithBusiness()),
              business: ScriptedBusinessRepository([
                const MyBusiness(
                    status: BusinessStatus.rejected,
                    name: 'Boutique Mama Aïcha',
                    motifRejet: 'La photo du représentant est floue, merci de la reprendre'),
              ]),
              textScale: scale,
              mode: mode);

          expect(tester.takeException(), isNull);
          final card = tester.getRect(find.byKey(const ValueKey('profile-business-status')));
          expect(card.left, greaterThanOrEqualTo(0));
          expect(card.right, lessThanOrEqualTo(360));
          final logout = find.byKey(const ValueKey('profile-logout'));
          await tester.ensureVisible(logout);
          await tester.pumpAndSettle();
          expect(tester.getSize(logout).height, greaterThanOrEqualTo(48));
          expect(find.text('Se déconnecter'), findsOneWidget);
          expect(
              find.byType(Scrollable).evaluate().where((e) =>
                  (e.widget as Scrollable).axis == Axis.horizontal),
              isEmpty);
        });
      }
    }
  });
}

extension on List<String> {
  List<String> takeLast(int n) => sublist(length - n);
}
