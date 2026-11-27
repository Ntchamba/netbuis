import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:netbuis/core/data/referentials/referential_repository_fake.dart';
import 'package:netbuis/core/data/zones/zone.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/network/dio_client.dart';
import 'package:netbuis/core/network/interceptors/refresh_interceptor.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/business/application/business_draft_controller.dart';
import 'package:netbuis/features/business/application/business_services.dart';
import 'package:netbuis/features/business/data/models/business_draft.dart';
import 'package:netbuis/features/business/data/repositories/business_repository_api.dart';

import '../account/account_test_helpers.dart';
import '../auth/auth_test_helpers.dart';
import 'business_test_helpers.dart';

const String kApiUrl = 'http://10.0.2.2:8000/api';
const String kOrigin = 'http://10.0.2.2:8000';

/// Faux fichiers : seuls les premiers octets comptent (le type vient d'eux, jamais du nom).
Uint8List fakeJpeg(int length) =>
    Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(length - 4, 7)]);
Uint8List fakePng(int length) => Uint8List.fromList(
    [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, ...List.filled(length - 8, 7)]);
Uint8List fakeWebp(int length) => Uint8List.fromList([
      0x52, 0x49, 0x46, 0x46, 1, 2, 3, 4, 0x57, 0x45, 0x42, 0x50, //
      ...List.filled(length - 12, 7)
    ]);
Uint8List fakeGif(int length) =>
    Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, ...List.filled(length - 6, 7)]);

/// Chemin fictif -> contenu. Les chemins ont une extension TROMPEUSE exprès : le type doit
/// être reconnu d'après les octets.
final Map<String, Uint8List> kFakeFiles = {
  '/fictif/commerce.png': fakeJpeg(1200), // « .png » mais JPEG
  '/fictif/personne.jpg': fakePng(900), // « .jpg » mais PNG
  '/fictif/cni-secrete.jpg': fakeWebp(700),
  '/fictif/diplome.jpeg': fakeJpeg(500),
};

Zone get kCity => const Zone(id: 16, name: 'Maroua', level: ZoneLevel.villeVillage);
Zone get kDistrict => const Zone(id: 21, name: 'Hardé', level: ZoneLevel.quartier, parent: 16);

/// Brouillon complet d'un type de compte (valeurs fictives).
Future<BusinessDraft> completeDraft(BusinessAccountType type, {bool withDistrict = true}) async {
  const referentials = ReferentialRepositoryFake();
  var d = const BusinessDraft().withType(type).copyWith(
        name: 'Boutique Mama Aïcha',
        representantNom: 'Aïcha Oumarou',
        repere: 'Près du grand manguier',
        photoPath: '/fictif/commerce.png',
        representantPhotoPath: '/fictif/personne.jpg',
      );
  d = d.withCity(kCity);
  if (withDistrict) d = d.withQuartier(kDistrict);
  switch (type) {
    case BusinessAccountType.boutique:
    case BusinessAccountType.particulierVendeur:
    case BusinessAccountType.entreprise:
      final sector = (await referentials.getSectors()).first;
      d = d.withSector(sector).copyWith(
            sousCategorieIds: [1, 2],
            descriptionActivite: 'Vente de fruits et légumes frais',
          );
      if (type == BusinessAccountType.entreprise) {
        d = d.copyWith(formeJuridique: LegalForm.sarl, rccm: 'RC/MRA/2023/B/0456');
      }
    case BusinessAccountType.prestataireService:
      final category = (await referentials.getServiceCategories())[1];
      d = d.withServiceCategory(category).copyWith(
            cniPhotoPath: '/fictif/cni-secrete.jpg',
            diplomePhotoPath: '/fictif/diplome.jpeg',
          );
    case BusinessAccountType.structure:
      final restaurant = (await referentials.getStructureTypes())[1];
      d = d.withStructureType(restaurant).copyWith(
            cuisine: 'camerounaise',
            livraison: true,
            horaires: 'Tous les jours, 11h–22h',
            description: 'Cadre climatisé',
          );
  }
  return d;
}

/// Faux serveur du compte business : applique les règles du contrat (signature, PUT, création)
/// et note l'ordre des appels dans [events] (`sign:photo`, `put:photo`, `post`, `get-me`).
class MockBusinessServer {
  MockBusinessServer() {
    mainAdapter = FakeAdapter(_main);
    uploadAdapter = FakeAdapter(_upload);
  }

  late final FakeAdapter mainAdapter;
  late final FakeAdapter uploadAdapter;
  final List<String> events = [];
  final Map<String, ({String kind, String contentType, int size, String key})> _tickets = {};
  final Set<String> _used = {};
  final Set<String> _storedKeys = {};
  int _n = 0;
  Map<String, dynamic>? lastBody;
  bool businessExists = false;

  /// Vrai : se comporte comme le serveur ACTUEL, qui exige `phone_anchor` (backend
  /// `BusinessProfile.clean`) alors que le mobile ne connaît jamais le numéro entier.
  bool requirePhoneAnchor = false;
  int refreshCalls = 0;

  /// Le test peut imposer une réponse (ou lever une DioException) pour un événement.
  FakeAdapterReply? Function(String event, SeenRequest request)? script;

  /// Si défini, tout PUT attend ce signal avant de partir (pour observer la progression).
  Completer<void>? putGate;

  /// Chaque fichier envoyé : `kind` -> nombre de PUT acceptés.
  final Map<String, int> accepted = {};

  static FakeAdapterReply reply(int status, Object? body, {Map<String, String> headers = const {}}) =>
      FakeAdapter.reply(status, body, headers: headers);

  DioException cut(SeenRequest r) => DioException(
        requestOptions: RequestOptions(path: r.path),
        type: DioExceptionType.connectionError,
      );

  FakeAdapterReply _main(SeenRequest r) {
    final String event;
    if (r.path == '/uploads/sign/') {
      event = 'sign:${(r.body as Map)['kind']}';
    } else if (r.path == '/business/' && r.method == 'POST') {
      event = 'post';
    } else if (r.path == '/business/me/') {
      event = 'get-me';
    } else {
      return reply(404, {'code': 'not_found', 'message': 'x'});
    }
    events.add(event);
    final forced = script?.call(event, r);
    if (forced != null) return forced;
    if (event.startsWith('sign:')) return _sign(r.body as Map);
    if (event == 'post') return _post(r.body as Map);
    return businessExists
        ? reply(200, _profile())
        : reply(404, {'code': 'no_business', 'message': 'x'});
  }

  Map<String, Object?> _profile() => {
        'id': 1,
        'name': 'Boutique Mama Aïcha',
        'status': 'en_attente_validation',
        'motif_rejet': '',
        'phone_masked': '+237 6•• •• •• 12',
      };

  FakeAdapterReply _sign(Map body) {
    const kinds = {'photo', 'representant_photo', 'cni_photo', 'diplome_photo'};
    const types = {'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp'};
    final kind = body['kind'];
    final ct = body['content_type'];
    final size = body['size'];
    if (!kinds.contains(kind)) return reply(400, {'code': 'invalid_kind', 'message': 'x'});
    if (!types.containsKey(ct)) return reply(400, {'code': 'invalid_type', 'message': 'x'});
    if (size is! int || size < 1) return reply(400, {'code': 'invalid', 'message': 'x'});
    if (size > 5242880) return reply(400, {'code': 'too_large', 'message': 'x'});
    _n++;
    final token = 'tok$_n';
    final key = 'u1/$kind/${_n.toString().padLeft(32, '0')}.${types[ct]}';
    _tickets[token] = (kind: kind as String, contentType: ct as String, size: size, key: key);
    return reply(200, {
      'key': key,
      'upload_url': '/api/uploads/local/$token/',
      'method': 'PUT',
      'headers': {'Content-Type': ct},
      'expires_in': 900,
    });
  }

  FakeAdapterReply _post(Map body) {
    lastBody = Map<String, dynamic>.from(body);
    if (businessExists) return reply(409, {'code': 'business_exists', 'message': 'x'});
    if (requirePhoneAnchor && body['phone_anchor'] == null) {
      return reply(400, {
        'code': 'invalid',
        'message': 'x',
        'fields': {'phone_anchor': ['Le numéro est obligatoire.']},
      });
    }
    // Les clés doivent exister (envoyées) : sinon 400 par champ, comme le serveur.
    final fields = <String, Object?>{};
    for (final f in const ['photo', 'representant_photo', 'cni_photo', 'diplome_photo']) {
      final v = body[f];
      if (v != null && !_storedKeys.contains(v)) {
        fields[f] = ['Fichier inconnu : envoyez-le d\'abord.'];
      }
    }
    // `photo` (commerce) est facultative côté serveur (T026c) ; seule celle du représentant
    // est obligatoire.
    if (body['representant_photo'] == null) fields['representant_photo'] = ['obligatoire'];
    if (fields.isNotEmpty) {
      return reply(400, {'code': 'invalid', 'message': 'x', 'fields': fields});
    }
    businessExists = true;
    return reply(201, _profile());
  }

  FakeAdapterReply _upload(SeenRequest r) {
    final token = Uri.parse(r.path).pathSegments.reversed.skip(1).first;
    final ticket = _tickets[token];
    final kind = ticket?.kind ?? '?';
    final event = 'put:$kind';
    events.add(event);
    final forced = script?.call(event, r);
    if (forced != null) return forced;
    if (ticket == null) return reply(403, {'code': 'invalid_token', 'message': 'x'});
    if (_used.contains(token)) return reply(403, {'code': 'already_used', 'message': 'x'});
    final contentType = (r.headers['content-type'] ?? r.headers['Content-Type'])?.toString();
    final data = r.body;
    if (contentType?.split(';').first != ticket.contentType) {
      return reply(400, {'code': 'invalid_type', 'message': 'x'});
    }
    if (data is! Uint8List || data.length != ticket.size) {
      return reply(400, {'code': 'invalid_content', 'message': 'x'});
    }
    _used.add(token);
    _storedKeys.add(ticket.key);
    accepted[ticket.kind] = (accepted[ticket.kind] ?? 0) + 1;
    return reply(204, null);
  }

  /// Dépôt « API » branché sur ce faux serveur, avec les vrais clients Dio de l'application :
  /// le client principal AVEC jeton et renouvellement, le client d'envoi SANS intercepteur.
  List<Override> overrides({
    Map<String, Uint8List>? files,
    RefreshOutcome refresh = RefreshOutcome.rejected,
  }) {
    final dio = buildDio(
      baseUrl: kApiUrl,
      readAccessToken: () async => 'acc-test',
      refreshSession: () async {
        refreshCalls++;
        return refresh;
      },
    )..httpClientAdapter = mainAdapter;
    final upload = buildUploadDio()..httpClientAdapter = _GatedAdapter(uploadAdapter, this);
    final content = files ?? kFakeFiles;
    return [
      businessRepositoryProvider.overrideWithValue(BusinessRepositoryApi(dio, upload, kApiUrl)),
      photoBytesReaderProvider.overrideWithValue((path) async {
        final bytes = content[path];
        if (bytes == null) throw StateError('fichier absent');
        return bytes;
      }),
    ];
  }

  /// Corps JSON reçu par un événement du client principal.
  List<SeenRequest> get mainRequests => mainAdapter.seen;
  List<SeenRequest> get uploadRequests => uploadAdapter.seen;
}

typedef FakeAdapterReply = ({int status, Object? body, Map<String, String> headers});

/// Ouvre le récapitulatif avec le brouillon [draft] déjà rempli (la pile contient les
/// Informations dessous, comme dans le vrai parcours).
Future<ProviderContainer> openRecap(
  WidgetTester tester,
  BusinessDraft draft, {
  List<Override> overrides = const [],
  ScriptedAccountRepository? account,
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.dark,
  bool settle = true,
}) async {
  await pumpBusinessApp(
    tester,
    overrides: overrides,
    account: account,
    textScale: textScale,
    mode: mode,
  );
  final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
  container.read(businessDraftProvider.notifier).update((_) => draft);
  await tester.pump();
  GoRouter.of(tester.element(find.byType(Scaffold).first)).push(Routes.createBusinessRecap);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return container;
}

/// Adaptateur qui retient les envois tant que [MockBusinessServer.putGate] n'est pas libéré.
class _GatedAdapter implements HttpClientAdapter {
  _GatedAdapter(this._inner, this._server);

  final HttpClientAdapter _inner;
  final MockBusinessServer _server;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream,
      Future<void>? cancelFuture) async {
    final gate = _server.putGate;
    if (gate != null) await gate.future;
    return _inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);
}
