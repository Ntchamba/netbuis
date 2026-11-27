import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/data/referentials/referential_repository_fake.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/network/interceptors/refresh_interceptor.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/business/application/business_draft_controller.dart';
import 'package:netbuis/features/business/application/business_request.dart';
import 'package:netbuis/features/business/application/business_submit_controller.dart';
import 'package:netbuis/features/business/data/models/business_draft.dart';

import '../account/account_test_helpers.dart';
import 'business_submit_helpers.dart';

/// Contrôleur d'envoi contre un faux serveur, SANS réseau réel et sans écran.
Future<(ProviderContainer, MockBusinessServer)> _setup(
  BusinessAccountType type, {
  MockBusinessServer? server,
  Map<String, Uint8List>? files,
  RefreshOutcome refresh = RefreshOutcome.rejected,
  BusinessDraft? draft,
  ScriptedAccountRepository? account,
}) async {
  final mock = server ?? MockBusinessServer();
  final container = ProviderContainer(overrides: [
    ...mock.overrides(files: files, refresh: refresh),
    accountRepositoryProvider
        .overrideWithValue(account ?? ScriptedAccountRepository(me: meWith(name: 'Jeff N.'))),
  ]);
  addTearDown(container.dispose);
  // Garde en vie les fournisseurs « autoDispose » le temps du test.
  container.listen(businessDraftProvider, (_, __) {});
  container.listen(businessSubmitProvider, (_, __) {});
  final d = draft ?? await completeDraft(type);
  container.read(businessDraftProvider.notifier).update((_) => d);
  return (container, mock);
}

SubmitState _state(ProviderContainer c) => c.read(businessSubmitProvider);
BusinessDraft _draft(ProviderContainer c) => c.read(businessDraftProvider);

Future<void> _submit(ProviderContainer c) => c.read(businessSubmitProvider.notifier).submit();

void main() {
  group('envoi nominal', () {
    for (final type in BusinessAccountType.values) {
      test('${type.value} : sign -> PUT pour chaque photo, puis POST ; tout est accepté', () async {
        final (c, server) = await _setup(type);
        await _submit(c);

        expect(_state(c).phase, SubmitPhase.sent, reason: 'état final');
        final isProvider = type == BusinessAccountType.prestataireService;
        final kinds = [
          'photo',
          'representant_photo',
          if (isProvider) ...['cni_photo', 'diplome_photo'],
        ];
        // Ordre exact : pour chaque fichier, sign puis PUT ; le profil en dernier.
        expect(server.events, [
          for (final k in kinds) ...['sign:$k', 'put:$k'],
          'post',
        ]);
        expect(server.accepted.keys.toSet(), kinds.toSet());
        expect(server.businessExists, isTrue);
      });
    }

    test('le PUT part avec les en-têtes du serveur, SANS Authorization, vers l\'origine de l\'API',
        () async {
      final (c, server) = await _setup(BusinessAccountType.boutique);
      await _submit(c);

      expect(server.uploadRequests, hasLength(2));
      for (final put in server.uploadRequests) {
        expect(put.method, 'PUT');
        // Chemin serveur absolu résolu contre l'ORIGINE (pas « …/api » + « /api/… »).
        expect(put.path, startsWith('$kOrigin/api/uploads/local/tok'));
        expect(put.path, isNot(contains('/api/api/')));
        expect(put.headers.keys.map((k) => k.toLowerCase()), isNot(contains('authorization')));
        final ct = put.headers['content-type'] ?? put.headers['Content-Type'];
        expect(ct.toString().split(';').first, anyOf('image/jpeg', 'image/png'));
      }
      // Le client principal, lui, envoie le jeton d'accès.
      final signs = server.mainRequests.where((r) => r.path == '/uploads/sign/');
      expect(signs, isNotEmpty);
      for (final r in server.mainRequests) {
        expect(r.headers['Authorization'], 'Bearer acc-test', reason: r.path);
      }
    });

    test('type détecté d\'après les octets (jamais l\'extension) et taille exacte', () async {
      final (c, server) = await _setup(BusinessAccountType.prestataireService);
      await _submit(c);

      Map signFor(String kind) => server.mainRequests
          .firstWhere((r) => r.path == '/uploads/sign/' && (r.body as Map)['kind'] == kind)
          .body as Map;
      // « commerce.png » est en réalité un JPEG, « personne.jpg » un PNG, la CNI un WebP.
      expect(signFor('photo'), {'kind': 'photo', 'content_type': 'image/jpeg', 'size': 1200});
      expect(signFor('representant_photo'),
          {'kind': 'representant_photo', 'content_type': 'image/png', 'size': 900});
      expect(signFor('cni_photo'),
          {'kind': 'cni_photo', 'content_type': 'image/webp', 'size': 700});
      expect(signFor('diplome_photo'),
          {'kind': 'diplome_photo', 'content_type': 'image/jpeg', 'size': 500});
      // Les PUT portent exactement ces octets (le faux serveur compare type, taille, octets).
      expect(server.accepted.values.every((n) => n == 1), isTrue);
    });

    test('corps du POST : seulement les champs du type, avec les clés obtenues', () async {
      final expectations = <BusinessAccountType, Set<String>>{
        BusinessAccountType.boutique: {
          'type_compte', 'name', 'zone', 'repere', 'representant_nom', 'photo',
          'representant_photo', 'secteur', 'sous_categories', 'description_activite', //
        },
        BusinessAccountType.particulierVendeur: {
          'type_compte', 'name', 'zone', 'repere', 'representant_nom', 'photo',
          'representant_photo', 'secteur', 'sous_categories', 'description_activite', //
        },
        BusinessAccountType.entreprise: {
          'type_compte', 'name', 'zone', 'repere', 'representant_nom', 'photo',
          'representant_photo', 'secteur', 'sous_categories', 'description_activite',
          'forme_juridique', 'rccm', //
        },
        BusinessAccountType.prestataireService: {
          'type_compte', 'name', 'zone', 'repere', 'representant_nom', 'photo',
          'representant_photo', 'categorie_service', 'cni_photo', 'diplome_photo', //
        },
        BusinessAccountType.structure: {
          'type_compte', 'name', 'zone', 'repere', 'representant_nom', 'photo',
          'representant_photo', 'structure_type', 'cuisine', 'livraison', 'horaires',
          'description', //
        },
      };
      for (final entry in expectations.entries) {
        final (c, server) = await _setup(entry.key);
        await _submit(c);
        final body = server.lastBody!;
        expect(body.keys.toSet(), entry.value, reason: entry.key.value);
        expect(body['type_compte'], entry.key.value);
        expect(body['zone'], 21, reason: 'le quartier choisi');
        expect(body['name'], 'Boutique Mama Aïcha');
        // Les clés viennent du serveur (u1/<kind>/…), pas des chemins locaux.
        expect(body['photo'], matches(r'^u1/photo/0+\d+\.jpg$'));
        expect(body['representant_photo'], matches(r'^u1/representant_photo/0+\d+\.png$'));
        expect(body.toString(), isNot(contains('/fictif/')));
        // Jamais le numéro, ni le statut, ni un champ d'un autre type.
        expect(body.containsKey('phone_anchor'), isFalse);
        expect(body.containsKey('status'), isFalse);
        if (entry.key == BusinessAccountType.prestataireService) {
          expect(body['cni_photo'], matches(r'^u1/cni_photo/'));
          expect(body['diplome_photo'], matches(r'^u1/diplome_photo/'));
        }
      }
    });

    test('corps Structure : restaurant ; supermarché, hôtel, centre de santé ; « Autre »', () async {
      const referentials = ReferentialRepositoryFake();
      Future<Map<String, dynamic>> bodyFor(String code, BusinessDraft Function(BusinessDraft) fill) async {
        final base = await completeDraft(BusinessAccountType.structure);
        final type = (await referentials.getStructureTypes()).firstWhere((t) => t.code == code);
        final (c, server) =
            await _setup(BusinessAccountType.structure, draft: fill(base.withStructureType(type)));
        await _submit(c);
        return server.lastBody!;
      }

      final hotel = await bodyFor('hotel',
          (d) => d.copyWith(standing: 'confort', nombreChambres: 18, equipements: ['wifi']));
      expect(hotel['standing'], 'confort');
      expect(hotel['nombre_chambres'], 18);
      expect(hotel['equipements'], ['wifi']);
      expect(hotel.containsKey('cuisine'), isFalse);
      expect(hotel.containsKey('rayons'), isFalse);

      final market = await bodyFor('supermarche', (d) => d.copyWith(rayons: ['boissons']));
      expect(market['rayons'], ['boissons']);
      expect(market.containsKey('standing'), isFalse);

      final health = await bodyFor('sante',
          (d) => d.copyWith(specialites: ['pediatrie'], numeroAgrement: 'MINSANTE/2024/0456'));
      expect(health['specialites'], ['pediatrie']);
      expect(health['numero_agrement'], 'MINSANTE/2024/0456');

      final other = await bodyFor('autre', (d) => d.copyWith(structureTypeLibre: 'Pressing'));
      expect(other['structure_type_libre'], 'Pressing');
      for (final f in ['rayons', 'cuisine', 'standing', 'specialites', 'equipements']) {
        expect(other.containsKey(f), isFalse, reason: f);
      }
    });

    test('Prestataire sans diplôme : pas de diplome_photo, 3 envois', () async {
      final base = await completeDraft(BusinessAccountType.prestataireService);
      final (c, server) = await _setup(BusinessAccountType.prestataireService,
          draft: base.copyWith(diplomePhotoPath: null));
      await _submit(c);
      expect(server.events, [
        'sign:photo', 'put:photo', 'sign:representant_photo', 'put:representant_photo',
        'sign:cni_photo', 'put:cni_photo', 'post', //
      ]);
      expect(server.lastBody!.containsKey('diplome_photo'), isFalse);
    });

    test('progression : un pas par fichier, puis la demande', () async {
      final (c, _) = await _setup(BusinessAccountType.prestataireService);
      final seen = <(int, int)>[];
      c.listen(businessSubmitProvider, (_, next) {
        if (next.sending) seen.add((next.done, next.total));
      });
      await _submit(c);
      expect(seen, [(0, 5), (1, 5), (2, 5), (3, 5), (4, 5)]);
      expect(_state(c).phase, SubmitPhase.sent);
    });
  });

  group('rien n\'est perdu', () {
    test('coupure réseau au milieu : le brouillon reste, « Réessayer » ne renvoie pas les fichiers déjà partis',
        () async {
      final (c, server) = await _setup(BusinessAccountType.prestataireService);
      var cutOnce = true;
      server.script = (event, req) {
        if (event == 'put:cni_photo' && cutOnce) {
          cutOnce = false;
          throw server.cut(req);
        }
        return null;
      };
      final before = _draft(c);
      await _submit(c);

      expect(_state(c).phase, SubmitPhase.failed);
      expect(_state(c).problem, SubmitProblem.network);
      expect(_state(c).done, 2, reason: 'photo et représentant sont partis');
      // Le brouillon (nom, photos locales) est intact ; seules les clés se sont ajoutées.
      expect(_draft(c).name, before.name);
      expect(_draft(c).cniPhotoPath, before.cniPhotoPath);
      expect(_draft(c).uploaded.keys.toSet(), {'photo', 'representant_photo'});
      expect(server.businessExists, isFalse);

      server.events.clear();
      await _submit(c);

      expect(_state(c).phase, SubmitPhase.sent);
      // La reprise recommence à la CNI : photo et représentant ne sont PAS renvoyés.
      expect(server.events, [
        'sign:cni_photo', 'put:cni_photo', 'sign:diplome_photo', 'put:diplome_photo', 'post', //
      ]);
      expect(server.accepted, {
        'photo': 1, 'representant_photo': 1, 'cni_photo': 1, 'diplome_photo': 1, //
      });
      // Le POST reprend les clés d'avant la coupure.
      expect(server.lastBody!['photo'], matches(r'^u1/photo/'));
    });

    test('coupure pendant le POST : les clés sont réutilisées, aucun fichier renvoyé', () async {
      final (c, server) = await _setup(BusinessAccountType.boutique);
      var cutOnce = true;
      server.script = (event, req) {
        if (event == 'post' && cutOnce) {
          cutOnce = false;
          throw server.cut(req);
        }
        return null;
      };
      await _submit(c);
      expect(_state(c).problem, SubmitProblem.network);
      expect(_draft(c).uploaded.keys.toSet(), {'photo', 'representant_photo'});

      server.events.clear();
      await _submit(c);
      expect(_state(c).phase, SubmitPhase.sent);
      expect(server.events, ['post']);
      expect(server.accepted, {'photo': 1, 'representant_photo': 1});
    });

    test('photo changée entre deux essais : la clé de l\'ancienne n\'est pas reprise', () async {
      final (c, server) = await _setup(BusinessAccountType.boutique);
      var cutOnce = true;
      server.script = (event, req) {
        if (event == 'post' && cutOnce) {
          cutOnce = false;
          throw server.cut(req);
        }
        return null;
      };
      await _submit(c);
      c.read(businessDraftProvider.notifier).setPhotoPath('/fictif/diplome.jpeg');

      server.events.clear();
      await _submit(c);
      expect(_state(c).phase, SubmitPhase.sent);
      expect(server.events, ['sign:photo', 'put:photo', 'post'],
          reason: 'seule la photo changée repart');
    });

    test('lien d\'envoi expiré ou refusé (403) : nouveau lien pour CE fichier seulement', () async {
      final (c, server) = await _setup(BusinessAccountType.boutique);
      var refuse = true;
      server.script = (event, req) {
        if (event == 'put:representant_photo' && refuse) {
          refuse = false;
          return MockBusinessServer.reply(403, {'code': 'invalid_token', 'message': 'brut'});
        }
        return null;
      };
      await _submit(c);

      expect(_state(c).phase, SubmitPhase.sent);
      expect(server.events, [
        'sign:photo', 'put:photo',
        'sign:representant_photo', 'put:representant_photo', // refusé
        'sign:representant_photo', 'put:representant_photo', // nouveau lien, même fichier
        'post', //
      ]);
      expect(server.accepted['photo'], 1, reason: 'la première photo n\'est pas renvoyée');
    });

    test('lien refusé deux fois : arrêt propre, « Réessayer » redemande un lien', () async {
      final (c, server) = await _setup(BusinessAccountType.boutique);
      var refusals = 2;
      server.script = (event, req) {
        if (event == 'put:photo' && refusals > 0) {
          refusals--;
          return MockBusinessServer.reply(403, {'code': 'already_used', 'message': 'x'});
        }
        return null;
      };
      await _submit(c);
      expect(_state(c).phase, SubmitPhase.failed);
      expect(_state(c).problem, SubmitProblem.server);
      expect(_draft(c).uploaded, isEmpty);

      await _submit(c);
      expect(_state(c).phase, SubmitPhase.sent);
    });

    test('409 business_exists (réponse perdue) : succès après relecture de GET /business/me/',
        () async {
      final (c, server) = await _setup(BusinessAccountType.boutique);
      // La création a réussi côté serveur, mais la réponse s'est perdue.
      server.script = (event, req) {
        if (event == 'post' && !server.businessExists) {
          server.businessExists = true;
          throw server.cut(req);
        }
        return null;
      };
      await _submit(c);
      expect(_state(c).problem, SubmitProblem.network);

      server.events.clear();
      await _submit(c);
      expect(_state(c).phase, SubmitPhase.sent);
      expect(server.events, ['post', 'get-me']);
    });

    test('409 puis la relecture échoue : pas de faux succès', () async {
      final (c, server) = await _setup(BusinessAccountType.boutique);
      server.businessExists = true;
      server.script = (event, req) =>
          event == 'get-me' ? MockBusinessServer.reply(500, {'code': 'error', 'message': 'x'}) : null;
      await _submit(c);
      expect(_state(c).phase, SubmitPhase.failed);
      expect(_state(c).problem, SubmitProblem.server);
    });
  });

  group('échecs du serveur', () {
    test('400 par champ : message général et renvoi à l\'écran concerné (zone -> lieu, name -> Informations)',
        () async {
      final cases = {
        'zone': Routes.createBusinessLocation,
        'name': Routes.createBusiness,
        'representant_nom': Routes.createBusiness,
        'forme_juridique': Routes.createBusinessLegalForm,
        'secteur': Routes.createBusinessSector,
        'sous_categories': Routes.createBusinessDetails,
        'categorie_service': Routes.createBusinessServiceCategory,
        'cni_photo': Routes.createBusinessServiceCategory,
        'structure_type': Routes.createBusinessStructureType,
        'rayons': Routes.createBusinessStructureDetails,
      };
      for (final entry in cases.entries) {
        final (c, server) = await _setup(BusinessAccountType.boutique);
        server.script = (event, req) => event == 'post'
            ? MockBusinessServer.reply(400, {
                'code': 'invalid',
                'message': 'Le lieu doit être une ville',
                'fields': {entry.key: ['Texte du serveur à ne jamais afficher']},
              })
            : null;
        await _submit(c);
        expect(_state(c).phase, SubmitPhase.failed, reason: entry.key);
        expect(_state(c).problem, SubmitProblem.fields, reason: entry.key);
        expect(_state(c).fixRoute, entry.value, reason: entry.key);
      }
    });

    test('champ sans écran de correction (phone_anchor) : erreur générique, rien n\'est perdu',
        () async {
      // Le serveur actuel exige `phone_anchor`, que le mobile ne connaît jamais en entier
      // (voir logs/T035-blocage.md) : l'application ne l'invente pas et ne bloque pas.
      final (c, server) = await _setup(BusinessAccountType.boutique);
      server.requirePhoneAnchor = true;
      await _submit(c);
      expect(_state(c).phase, SubmitPhase.failed);
      expect(_state(c).problem, SubmitProblem.server);
      expect(_state(c).fixRoute, isNull);
      expect(server.lastBody!.containsKey('phone_anchor'), isFalse);
      expect(_draft(c).uploaded.keys.toSet(), {'photo', 'representant_photo'});
      expect(_draft(c).name, 'Boutique Mama Aïcha');
    });

    test('400 par champ sur un fichier inconnu : sa clé est oubliée, il repart à l\'essai suivant',
        () async {
      final (c, server) = await _setup(BusinessAccountType.boutique);
      var once = true;
      server.script = (event, req) {
        if (event == 'post' && once) {
          once = false;
          return MockBusinessServer.reply(400, {
            'code': 'invalid',
            'message': 'x',
            'fields': {'photo': ['Fichier inconnu : envoyez-le d\'abord.']},
          });
        }
        return null;
      };
      await _submit(c);
      expect(_state(c).problem, SubmitProblem.fields);
      expect(_draft(c).uploaded.keys, ['representant_photo']);

      server.events.clear();
      await _submit(c);
      expect(_state(c).phase, SubmitPhase.sent);
      expect(server.events, ['sign:photo', 'put:photo', 'post']);
    });

    test('SUBSCRIPTION_REQUIRED : renvoi à Détails (Structure : Détails de l\'établissement)',
        () async {
      for (final (type, route) in [
        (BusinessAccountType.boutique, Routes.createBusinessDetails),
        (BusinessAccountType.entreprise, Routes.createBusinessDetails),
        (BusinessAccountType.structure, Routes.createBusinessStructureDetails),
      ]) {
        final (c, server) = await _setup(type);
        server.script = (event, req) => event == 'post'
            ? MockBusinessServer.reply(400,
                {'code': 'SUBSCRIPTION_REQUIRED', 'message': 'Abonnez-vous pour dépasser'})
            : null;
        await _submit(c);
        expect(_state(c).problem, SubmitProblem.subscription, reason: type.value);
        expect(_state(c).fixRoute, route, reason: type.value);
        expect(_draft(c).sousCategorieIds, isNotNull);
      }
    });

    test('429 throttled (au sign comme au POST) : message « Trop de demandes »', () async {
      final (c, server) = await _setup(BusinessAccountType.boutique);
      server.script = (event, req) => event == 'sign:photo'
          ? MockBusinessServer.reply(429, {'code': 'throttled', 'message': 'brut'})
          : null;
      await _submit(c);
      expect(_state(c).problem, SubmitProblem.throttled);

      final (c2, server2) = await _setup(BusinessAccountType.boutique);
      server2.script = (event, req) => event == 'post'
          ? MockBusinessServer.reply(429, {'code': 'throttled', 'message': 'brut'})
          : null;
      await _submit(c2);
      expect(_state(c2).problem, SubmitProblem.throttled);
      expect(_draft(c2).uploaded.keys.toSet(), {'photo', 'representant_photo'});
    });

    test('401 après renouvellement refusé : problème « session », brouillon gardé', () async {
      final (c, server) = await _setup(BusinessAccountType.boutique);
      server.script = (event, req) => event == 'post'
          ? MockBusinessServer.reply(401, {'code': 'token_not_valid', 'message': 'brut'})
          : null;
      await _submit(c);
      expect(_state(c).problem, SubmitProblem.session);
      expect(server.refreshCalls, 1, reason: 'le renouvellement automatique a été tenté');
      expect(_draft(c).name, 'Boutique Mama Aïcha');
    });

    test('401 puis renouvellement réussi : la requête est rejouée et aboutit', () async {
      final mock = MockBusinessServer();
      var first = true;
      mock.script = (event, req) {
        if (event == 'post' && first) {
          first = false;
          return MockBusinessServer.reply(401, {'code': 'token_not_valid', 'message': 'x'});
        }
        return null;
      };
      final (c, server) = await _setup(BusinessAccountType.boutique,
          server: mock, refresh: RefreshOutcome.renewed);
      await _submit(c);
      expect(_state(c).phase, SubmitPhase.sent);
      expect(server.refreshCalls, 1);
    });

    test('compte bloqué, erreur serveur : messages simples', () async {
      final (c, server) = await _setup(BusinessAccountType.boutique);
      server.script = (event, req) => event == 'sign:photo'
          ? MockBusinessServer.reply(403, {'code': 'account_blocked', 'message': 'brut'})
          : null;
      await _submit(c);
      expect(_state(c).problem, SubmitProblem.support);

      final (c2, server2) = await _setup(BusinessAccountType.boutique);
      server2.script = (event, req) =>
          event == 'post' ? MockBusinessServer.reply(500, {'code': 'error', 'message': 'x'}) : null;
      await _submit(c2);
      expect(_state(c2).problem, SubmitProblem.server);
    });

    test('PUT refusé (contenu invalide, trop gros) : photo à changer, renvoi à l\'écran de la photo',
        () async {
      final (c, server) = await _setup(BusinessAccountType.prestataireService);
      server.script = (event, req) => event == 'put:cni_photo'
          ? MockBusinessServer.reply(400, {'code': 'invalid_content', 'message': 'x'})
          : null;
      await _submit(c);
      expect(_state(c).problem, SubmitProblem.photo);
      expect(_state(c).fixRoute, Routes.createBusinessServiceCategory);

      final (c2, server2) = await _setup(BusinessAccountType.boutique);
      server2.script = (event, req) => event == 'put:photo'
          ? MockBusinessServer.reply(413, {'code': 'too_large', 'message': 'x'})
          : null;
      await _submit(c2);
      expect(_state(c2).problem, SubmitProblem.photo);
      expect(_state(c2).fixRoute, Routes.createBusiness);
    });
  });

  group('photos locales', () {
    test('format non accepté (GIF), fichier illisible ou trop gros : rien n\'est envoyé', () async {
      final cases = <String, Map<String, Uint8List>>{
        'gif': {...kFakeFiles, '/fictif/commerce.png': fakeGif(300)},
        'absent': {
          for (final e in kFakeFiles.entries)
            if (e.key != '/fictif/commerce.png') e.key: e.value
        },
        'trop gros': {...kFakeFiles, '/fictif/commerce.png': fakeJpeg(5242881)},
        'vide': {...kFakeFiles, '/fictif/commerce.png': Uint8List(0)},
      };
      for (final entry in cases.entries) {
        final (c, server) = await _setup(BusinessAccountType.boutique, files: entry.value);
        await _submit(c);
        expect(_state(c).problem, SubmitProblem.photo, reason: entry.key);
        expect(_state(c).fixRoute, Routes.createBusiness, reason: entry.key);
        expect(server.events, isEmpty, reason: '${entry.key} : aucun appel réseau');
      }
    });

    test('photo du représentant absente : rien n\'est envoyé, renvoi aux Informations', () async {
      for (final type in BusinessAccountType.values) {
        final base = await completeDraft(type);
        final (c, server) = await _setup(type, draft: base.copyWith(representantPhotoPath: null));
        await _submit(c);
        expect(_state(c).problem, SubmitProblem.photoMissing, reason: type.value);
        expect(_state(c).fixRoute, Routes.createBusiness, reason: type.value);
        expect(server.events, isEmpty, reason: type.value);
      }
    });

    test('envoi sans photo du commerce : OK (sign -> PUT -> POST avec une photo de moins)', () async {
      for (final type in [BusinessAccountType.boutique, BusinessAccountType.prestataireService]) {
        final base = await completeDraft(type);
        final (c, server) = await _setup(type, draft: base.copyWith(photoPath: null));
        await _submit(c);
        expect(_state(c).phase, SubmitPhase.sent, reason: type.value);
        final isProvider = type == BusinessAccountType.prestataireService;
        final kinds = [
          'representant_photo',
          if (isProvider) ...['cni_photo', 'diplome_photo'],
        ];
        expect(server.events, [
          for (final k in kinds) ...['sign:$k', 'put:$k'],
          'post',
        ], reason: type.value);
        expect(server.lastBody!.containsKey('photo'), isFalse, reason: type.value);
        expect(server.lastBody!.containsKey('phone_anchor'), isFalse, reason: type.value);
        expect(server.lastBody!['representant_photo'], isNotNull, reason: type.value);
      }
    });

    test('progression sans photo du commerce : le total suit le nombre réel de fichiers', () async {
      final base = await completeDraft(BusinessAccountType.boutique);
      final (c, _) =
          await _setup(BusinessAccountType.boutique, draft: base.copyWith(photoPath: null));
      final seen = <(int, int)>[];
      c.listen(businessSubmitProvider, (_, next) {
        if (next.sending) seen.add((next.done, next.total));
      });
      await _submit(c);
      expect(seen, [(0, 2), (1, 2)]);
      expect(_state(c).phase, SubmitPhase.sent);
    });

    test('JPEG, PNG, WebP reconnus ; une taille de 5 242 880 octets passe', () async {
      final files = {...kFakeFiles, '/fictif/commerce.png': fakeJpeg(5242880)};
      final (c, server) = await _setup(BusinessAccountType.boutique, files: files);
      await _submit(c);
      expect(_state(c).phase, SubmitPhase.sent);
      expect((server.mainRequests.first.body as Map)['size'], 5242880);
    });
  });

  group('vie privée', () {
    test('aucun journal (print / debugPrint) ne contient chemin, clé, jeton ni numéro', () async {
      final logs = <String>[];
      final old = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
      try {
        await runZoned(() async {
          // Un parcours avec échecs (coupure, refus de lien) puis succès.
          final (c, server) = await _setup(BusinessAccountType.prestataireService);
          var n = 0;
          server.script = (event, req) {
            if (event == 'put:cni_photo' && n++ == 0) {
              return MockBusinessServer.reply(403, {'code': 'invalid_token', 'message': 'x'});
            }
            if (event == 'post' && n++ == 1) throw server.cut(req);
            return null;
          };
          await _submit(c);
          await _submit(c);
          expect(_state(c).phase, SubmitPhase.sent);
        },
            zoneSpecification:
                ZoneSpecification(print: (self, parent, zone, line) => logs.add(line)));
      } finally {
        debugPrint = old;
      }
      final joined = logs.join('\n');
      for (final secret in ['/fictif', 'u1/', 'tok', 'cni-secrete', '10.0.2.2', '6••', 'acc-test']) {
        expect(joined, isNot(contains(secret)), reason: secret);
      }
    });

    test('ApiException ne garde ni la valeur d\'un champ ni un jeton : seulement les noms', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/business/'),
        response: Response(
          requestOptions: RequestOptions(path: '/business/'),
          statusCode: 400,
          data: {
            'code': 'invalid',
            'message': 'm',
            'fields': {'zone': ['secret-valeur'], 'photo': ['autre-secret']},
          },
        ),
      );
      final api = ApiException.fromDio(e);
      expect(api.fieldNames, ['zone', 'photo']);
      expect(api.toString(), isNot(contains('secret')));
    });

    test('le numéro du compte n\'est jamais dans le corps envoyé', () async {
      final (c, server) = await _setup(BusinessAccountType.boutique);
      await _submit(c);
      final text = server.mainRequests.map((r) => '${r.body}').join();
      expect(text, isNot(contains('phone')));
      expect(text, isNot(contains('+237')));
    });
  });

  group('fonctions pures', () {
    test('photosToSend : CNI et diplôme seulement pour le prestataire', () async {
      final provider = await completeDraft(BusinessAccountType.prestataireService);
      expect(photosToSend(provider).map((p) => p.kind),
          ['photo', 'representant_photo', 'cni_photo', 'diplome_photo']);
      final shop = (await completeDraft(BusinessAccountType.boutique))
          .copyWith(cniPhotoPath: '/fictif/cni-secrete.jpg', diplomePhotoPath: '/fictif/diplome.jpeg');
      expect(photosToSend(shop).map((p) => p.kind), ['photo', 'representant_photo']);
    });

    test('firstIncompleteStep : brouillon vide -> Informations ; complet -> null', () async {
      expect(firstIncompleteStep(const BusinessDraft()), isNotNull);
      for (final type in BusinessAccountType.values) {
        expect(firstIncompleteStep(await completeDraft(type)), isNull, reason: type.value);
      }
      final noSector = (await completeDraft(BusinessAccountType.boutique))
          .copyWith(secteurId: null, secteur: null);
      expect(firstIncompleteStep(noSector)?.path, Routes.createBusinessSector);
    });

    test('routeForFields : premier champ connu, sinon null', () {
      expect(routeForFields(['inconnu', 'zone'], BusinessAccountType.boutique),
          Routes.createBusinessLocation);
      expect(routeForFields(['phone_anchor'], BusinessAccountType.boutique), isNull);
      expect(routeForFields(['non_field_errors'], BusinessAccountType.boutique), isNull);
    });
  });
}
