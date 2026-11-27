// T123 : parcours de bout en bout par domaine (accès, création de commerce, recherche, carte,
// forum, compte). Chaque scénario monte l'application COMPLÈTE (routeur réel, onglets) avec des
// faux dépôts (équivalents de USE_FAKE_API) : aucun réseau, aucun téléphone, aucun fichier.
// Ils sont partagés par :
//  - test/integration/domain_flow_test.dart   (lancé par `flutter test`) ;
//  - integration_test/domain_flow_test.dart   (lancé sur appareil / émulateur).
// Les parcours d'appel (Jitsi) et de recherche suivie d'un appel sont dans flow_scenarios.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:netbuis/app.dart';
import 'package:netbuis/core/data/referentials/referential_repository_fake.dart';
import 'package:netbuis/core/data/zones/zone_repository_fake.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/account/data/models/me.dart';
import 'package:netbuis/features/account/data/repositories/account_repository.dart';
import 'package:netbuis/features/account/data/repositories/account_repository_fake.dart';
import 'package:netbuis/features/auth/data/repositories/auth_repository_fake.dart';
import 'package:netbuis/features/auth/presentation/screens/login_screen.dart';
import 'package:netbuis/features/auth/presentation/screens/otp_screen.dart';
import 'package:netbuis/features/business/application/business_draft_controller.dart';
import 'package:netbuis/features/business/application/business_services.dart';
import 'package:netbuis/features/business/data/models/business.dart';
import 'package:netbuis/features/business/data/models/business_draft.dart';
import 'package:netbuis/features/business/data/repositories/business_repository_fake.dart';
import 'package:netbuis/features/business/presentation/screens/business_detail_screen.dart';
import 'package:netbuis/features/business/data/models/public_business.dart';
import 'package:netbuis/features/business/data/repositories/public_business_repository.dart';
import 'package:netbuis/features/forum/application/forum_services.dart';
import 'package:netbuis/features/forum/data/forum_feed_cache.dart';
import 'package:netbuis/features/forum/data/models/report.dart';
import 'package:netbuis/features/maps/application/map_controller.dart';
import 'package:netbuis/features/maps/data/map_repository_fake.dart';
import 'package:netbuis/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:netbuis/features/account/presentation/screens/edit_profile_screen.dart';
import 'package:netbuis/features/auth/application/auth_controller.dart';
import 'package:netbuis/features/auth/presentation/widgets/otp_input.dart';
import 'package:netbuis/features/merchant/application/offers_controller.dart';
import 'package:netbuis/features/search/application/search_controller.dart';
import 'package:netbuis/features/search/data/models/search_query.dart';
import 'package:netbuis/features/search/data/search_cache.dart';
import 'package:netbuis/features/trends/application/trends_controller.dart';

import '../features/account/account_test_helpers.dart';
import '../features/auth/auth_test_helpers.dart';
import '../features/auth/login_test_helpers.dart';
import '../features/business/business_submit_helpers.dart';
import '../features/business/business_test_helpers.dart';
import '../features/call/call_test_helpers.dart';
import '../features/forum/forum_test_helpers.dart';
import '../features/forum/post_test_helpers.dart';
import '../features/home/no_trends.dart';
import '../features/merchant/offers_test_helpers.dart';
import 'flow_scenarios.dart';

Finder _k(String key) => find.byKey(ValueKey(key));

Future<void> _showAndTap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

/// Vrai quand l'écran de connexion (numéro) est affiché.
bool _onLogin() => find.byType(LoginScreen).evaluate().isNotEmpty;

// ============================================================================= ACCÈS

/// Application complète, non connectée ou connectée, tous les dépôts factices.
Future<MemoryTokenStorage> _pumpSession(
  WidgetTester tester, {
  bool signedIn = false,
  bool onboardingSeen = true,
  String initialLocation = Routes.splash,
  FakeSmsSource? sms,
  AccountRepository? account,
  List<Override> extra = const [],
}) async {
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final tokens = MemoryTokenStorage(refresh: signedIn ? 'ref-1' : null);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appPrefsProvider.overrideWithValue(MemoryPrefs(seen: onboardingSeen)),
      tokenStorageProvider.overrideWithValue(tokens),
      authRepositoryProvider.overrideWithValue(AuthRepositoryFake()),
      accountRepositoryProvider.overrideWithValue(account ?? AccountRepositoryFake()),
      referentialRepositoryProvider.overrideWithValue(const ReferentialRepositoryFake()),
      zoneRepositoryProvider.overrideWithValue(ZoneRepositoryFake()),
      trendsRepositoryProvider.overrideWithValue(const NoTrendsRepository()),
      smsCodeSourceProvider.overrideWithValue(sms ?? FakeSmsSource()),
      authClockProvider.overrideWith((ref) => () => tester.binding.clock.now()),
      ...extra,
    ],
    child: NetBuisApp(themeMode: ThemeMode.light, initialLocation: initialLocation),
  ));
  await tester.pumpAndSettle();
  return tokens;
}

/// Première ouverture : Lancement → Découverte → numéro → code faux (refusé) → code reçu par SMS →
/// saisie du nom (passée) → Accueil. Les jetons sont gardés.
Future<void> scenarioAccessFirstOpen(WidgetTester tester) async {
  final sms = FakeSmsSource();
  final tokens = await _pumpSession(tester, onboardingSeen: false, sms: sms);

  await tester.tap(find.text('Commencer'));
  await tester.pumpAndSettle();
  expect(find.byType(OnboardingScreen), findsOneWidget);
  await tester.tap(find.text('Passer'));
  await tester.pumpAndSettle();
  expect(find.byType(LoginScreen), findsOneWidget);

  await submitPhone(tester, '612345678');
  expect(find.byType(OtpScreen), findsOneWidget);
  expect(sms.started, isTrue, reason: 'la lecture du SMS est démarrée');

  // Un mauvais code est refusé et on reste sur l'écran du code, sans jeton.
  await tester.enterText(otpField, '000000');
  await tester.pumpAndSettle();
  expect(find.text('Code incorrect'), findsOneWidget);
  expect(find.byType(OtpScreen), findsOneWidget);
  expect((await tokens.read()).refresh, isNull);

  // Le bon code arrive par SMS et est envoyé tout seul.
  sms.receive('<#> ${AuthRepositoryFake.acceptedCode} est votre code NetBuis');
  await tester.pumpAndSettle();
  expect(find.byType(EditProfileScreen), findsOneWidget, reason: 'première connexion : le nom');
  await tester.tap(find.text('Passer'));
  await tester.pumpAndSettle();

  expect(onHomeTabs(), isTrue);
  expect(find.byKey(const Key('home-search')), findsOneWidget);
  expect((await tokens.read()).refresh, isNotNull, reason: 'session gardée sur l\'appareil');
}

/// Session restaurée : jeton présent → « Commencer » mène directement à l'Accueil (pas de numéro) ;
/// un écran protégé s'ouvre sans repasser par la connexion.
Future<void> scenarioAccessRestoredSession(WidgetTester tester) async {
  await _pumpSession(tester, signedIn: true);
  await tester.tap(find.text('Commencer'));
  await tester.pumpAndSettle();
  expect(onHomeTabs(), isTrue);
  expect(_onLogin(), isFalse);

  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(Routes.settings);
  await tester.pumpAndSettle();
  expect(_onLogin(), isFalse, reason: 'écran protégé accessible quand la session existe');
  expect(find.text('Langue'), findsWidgets);
}

/// Déconnexion : Profil → Se déconnecter → écran du numéro, jetons effacés, l'Accueil n'est plus
/// accessible (la garde renvoie à la connexion), et un nouveau code redonne accès.
Future<void> scenarioAccessLogout(WidgetTester tester) async {
  final tokens = await _pumpSession(tester, signedIn: true, initialLocation: Routes.home);
  expect(onHomeTabs(), isTrue);
  await openTab(tester, 3);
  await _showAndTap(tester, _k('profile-logout'));

  expect(_onLogin(), isTrue);
  final stored = await tokens.read();
  expect((stored.access, stored.refresh), (null, null));
  expect(onHomeTabs(), isFalse);

  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(Routes.home);
  await tester.pumpAndSettle();
  expect(_onLogin(), isTrue, reason: 'non connecté : l\'Accueil est protégé');

  await submitPhone(tester, '612345678');
  await tester.enterText(otpField, AuthRepositoryFake.acceptedCode);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Passer'));
  await tester.pumpAndSettle();
  expect(onHomeTabs(), isTrue, reason: 'une nouvelle connexion redonne accès');
}

// ============================================================================= CRÉATION DE COMMERCE

/// Assistant « Commerce » complet par les écrans : Profil → Activer mon compte Business →
/// Informations (refus si vide, puis remplies) → Secteur → Détails → Récapitulatif → envoi des photos
/// et de la demande → « Demande envoyée » → Profil « En attente de validation ».
Future<void> scenarioBusinessCreation(WidgetTester tester) async {
  final server = MockBusinessServer();
  final account = ScriptedAccountRepository(me: meWith(name: 'Jeff N.'));
  server.script = (event, req) {
    if (event == 'post') {
      account.me = const Me(
          id: 1, name: 'Jeff N.', phoneMasked: '+237 6•• •• •• 12', hasBusiness: true);
    }
    return null;
  };
  await pumpBusinessApp(
    tester,
    initialLocation: Routes.profile,
    account: account,
    overrides: [
      ...server.overrides(files: {'/fictif/photo.jpg': fakeJpeg(900)}),
      referentialRepositoryProvider.overrideWithValue(const ReferentialRepositoryFake()),
      zoneRepositoryProvider.overrideWithValue(ZoneRepositoryFake()),
    ],
  );
  expect(find.byKey(const ValueKey('profile-business-status')), findsNothing);
  await _showAndTap(tester, _k('profile-create-business-button'));

  // Étape 1 : Informations. Vide -> refus, on reste.
  expect(find.text('Étape 1 sur 4'), findsOneWidget);
  await tester.ensureVisible(continueButton);
  await tester.tap(continueButton);
  await tester.pumpAndSettle();
  expect(find.text('Étape 1 sur 4'), findsOneWidget, reason: 'champs vides : pas de passage');
  expect(server.events, isEmpty);

  await tester.enterText(_k('business-name'), 'Boutique Mama Aïcha');
  await tester.enterText(_k('business-owner'), 'Aïcha Oumarou');
  await _showAndTap(tester, _k('business-owner-photo'));
  await tester.tap(_k('photo-camera'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(continueButton);
  await tester.tap(continueButton);
  await tester.pumpAndSettle();

  // Étape 2 : Secteur (sans choix : refus).
  expect(find.text('Étape 2 sur 4'), findsOneWidget);
  await tester.tap(continueButton);
  await tester.pumpAndSettle();
  expect(find.text('Choisissez un secteur.'), findsOneWidget);
  await _showAndTap(tester, _k('business-sector-alimentation'));
  await tester.tap(continueButton);
  await tester.pumpAndSettle();

  // Étape 3 : Détails.
  expect(find.text('Étape 3 sur 4'), findsOneWidget);
  expect(find.text('Précisez votre activité'), findsOneWidget);
  await _showAndTap(tester, _k('business-sub-1'));
  await _showAndTap(tester, _k('business-sub-2'));
  await tester.ensureVisible(continueButton);
  await tester.tap(continueButton);
  await tester.pumpAndSettle();

  // Étape 4 : Récapitulatif, puis envoi.
  expectRecapShown();
  expect(find.text('Boutique Mama Aïcha'), findsWidgets);
  final draft = _container(tester).read(businessDraftProvider);
  expect(draft.typeCompte, BusinessAccountType.boutique);
  expect(draft.sousCategorieIds, [1, 2]);
  expect(server.events, isEmpty, reason: 'rien n\'est envoyé avant « Publier ma demande »');

  await tester.tap(find.text('Publier ma demande'));
  await tester.pumpAndSettle();
  expect(server.events.last, 'post');
  expect(server.events.where((e) => e.startsWith('sign:')), isNotEmpty);
  expect(find.text('Demande envoyée'), findsOneWidget);
  expect(find.textContaining('24 heures'), findsOneWidget);
  expect(_container(tester).read(businessDraftProvider).name, '', reason: 'brouillon vidé');

  await tester.tap(find.text('Voir mon profil'));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('profile-business-status')), findsOneWidget);
  expect(find.text('En attente de validation'), findsOneWidget);
  expect(find.byKey(const ValueKey('profile-create-business')), findsNothing);
}

// ============================================================================= RECHERCHE

/// Par nom du commerce (casse et accents ignorés) : « aminatou » ne trouve que cette boutique,
/// « MAMA » seulement Chez Mama Riz, un nom inconnu donne « Aucun résultat » ; la fiche s'ouvre.
Future<void> scenarioSearchByName(WidgetTester tester) async {
  final env = FlowEnv();
  await pumpFlowApp(tester, env);
  await tester.tap(find.byKey(const Key('home-search')));
  await settleAll(tester);

  Future<void> searchFor(String text) async {
    await tester.enterText(find.byKey(const Key('search-field')), text);
    await tester.pump(const Duration(milliseconds: 450));
    await settleAll(tester);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settleAll(tester);
  }

  await searchFor('aminatou');
  expect(find.text('Boutique Aminatou'), findsWidgets);
  expect(find.text('Chez Mama Riz'), findsNothing);
  expectNoPhoneOnScreen(tester);

  await searchFor('MAMA');
  expect(find.text('Chez Mama Riz'), findsWidgets);
  expect(find.text('Boutique Aminatou'), findsNothing);

  await searchFor('zzzz');
  expect(find.textContaining('Aucun résultat'), findsWidgets);
  expect(find.text('Chez Mama Riz'), findsNothing);

  await searchFor('Mama');
  await openDetailFromCard(tester, 'Chez Mama Riz');
  expect(find.text('Chez Mama Riz'), findsWidgets);
  expect(env.calls.requests, isEmpty, reason: 'chercher n\'appelle personne');
}

/// Vocal : « je cherche un plombier » (aucun résultat dans les données) puis « du riz » (résultat) ;
/// la reconnaissance est écoutée, le texte envoyé tel quel au serveur, aucun numéro affiché.
Future<void> scenarioVoiceSearchResults(WidgetTester tester) async {
  final env = FlowEnv();
  await pumpFlowApp(tester, env);
  await tester.tap(find.byKey(const Key('home-voice')));
  await settleAll(tester);
  await tester.tap(find.byKey(const Key('voice-rationale-ok')));
  await settleAll(tester);
  expect(env.speech.listening, isTrue);
  env.speech.say('je cherche un plombier');
  await settleAll(tester);
  expect(env.search.voiceCalls, ['je cherche un plombier']);
  // L'Accueil affiche lui-même les résultats vocaux : sa phrase pour « rien trouvé ».
  expect(find.text('Aucun commerce pour le moment.'), findsOneWidget);
  expect(find.text('Boutique Aminatou'), findsNothing);
  expectNoPhoneOnScreen(tester);

  // Nouvelle recherche vocale depuis l'Accueil (qui affiche les résultats).
  await tester.tap(find.byKey(const Key('home-voice')));
  await settleAll(tester);
  env.speech.say('du riz');
  await settleAll(tester);
  expect(env.search.voiceCalls, ['je cherche un plombier', 'du riz']);
  expect(find.text('Boutique Aminatou'), findsWidgets);
  await openDetailFromCard(tester, 'Boutique Aminatou');
}

// ============================================================================= CARTE

/// Fiches de n'importe quel commerce de la carte : le faux dépôt de fiches ne connaît que deux
/// commerces, la carte en propose d'autres (Commerce n de Quartier).
class _AnyBusinessRepository implements PublicBusinessRepository {
  @override
  Future<PublicBusiness> get(int id) async => PublicBusiness(
        id: id,
        name: 'Commerce 1 de Hardé',
        typeCompte: 'boutique',
        secteur: 'Alimentation',
        zone: const PublicZone(id: 301, name: 'Hardé'),
        descriptionActivite: 'Riz, huile, condiments',
      );
}

/// Carte : onglet Carte → ville (Maroua) → quartier (Hardé) → liste des commerces → fiche ; retour
/// jusqu'à la carte ; puis une ville sans quartier ; hors connexion le bandeau apparaît.
Future<void> scenarioMapToBusiness(WidgetTester tester) async {
  final env = FlowEnv();
  await pumpFlowApp(tester, env,
      extra: [mapRepositoryProvider.overrideWithValue(MapRepositoryFake())],
      publicBusiness: _AnyBusinessRepository());
  await openTab(tester, 1);
  expect(find.text('Explorer'), findsOneWidget);
  expect(find.text('Maroua · 91'), findsOneWidget);

  await tester.tap(find.byKey(const Key('map-pin-city-16')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('map-pin-area-301')), findsOneWidget);
  await tester.tap(find.byKey(const Key('map-pin-area-301')));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('area-title')), findsOneWidget);
  expect(find.text('Cameroun'), findsOneWidget);
  expect(find.text('Commerce 1 de Hardé'), findsOneWidget);
  expectNoPhoneOnScreen(tester);

  await tester.tap(find.text('Commerce 1 de Hardé'));
  await tester.pumpAndSettle();
  expect(find.byType(BusinessDetailScreen), findsOneWidget);
  expect(find.text('Commerce 1 de Hardé'), findsWidgets);
  expectNoPhoneOnScreen(tester);

  await backFrom(tester, find.byType(BusinessDetailScreen));
  expect(find.byKey(const Key('area-title')), findsOneWidget, reason: 'retour au quartier');
  await tester.tap(find.byKey(const Key('area-back')));
  await tester.pumpAndSettle();
  expect(find.text('Explorer'), findsOneWidget, reason: 'retour à la carte');
}

// ============================================================================= FORUM

/// Forum complet avec un compte business actif : lire le fil → ouvrir une publication et la
/// commenter → signaler une autre publication (elle disparaît) → Profil → Mes publications →
/// Publier (refus du serveur d'abord, puis succès).
Future<void> scenarioForumReadCommentReportPublish(WidgetTester tester) async {
  final fh = ForumHarness(
    posts: [
      feedPost(1, 'Nouveau lot de riz parfumé disponible', comments: 2, offer: 'Riz 25kg'),
      feedPost(2, 'Modèles de boubous', name: 'Couturier Ibrahim', initials: 'CI', zone: 'Domayo'),
    ],
    comments: [
      comment(10, 'Le riz 25kg est encore disponible ?', name: 'Jeff N.', initials: 'JN'),
      comment(11, 'Vous livrez vers Djarengol ?'),
    ],
  );
  final ph = PostsHarness(offers: [kOfferA]);
  ph.picker.result = '/fictif/riz.jpg';
  ph.files['/fictif/riz.jpg'] = fakeJpeg(900);
  await pumpBusinessApp(
    tester,
    initialLocation: Routes.forum,
    account: ScriptedAccountRepository(me: activeMe),
    overrides: [
      forumFeedRepositoryProvider.overrideWithValue(fh.repo),
      forumFeedCacheProvider.overrideWithValue(fh.cache),
      reportRepositoryProvider.overrideWithValue(fh.reports),
      forumRepositoryProvider.overrideWithValue(ph.forum),
      merchantRepositoryProvider.overrideWithValue(ph.merchant),
      businessRepositoryProvider.overrideWithValue(ph.business),
      postMediaPickerProvider.overrideWithValue(ph.picker),
      photoBytesReaderProvider.overrideWithValue((path) async => ph.files[path] ?? fakeJpeg(64)),
    ],
  );

  // Lire.
  expect(find.text('Publications des commerçants'), findsOneWidget);
  expect(find.text('Nouveau lot de riz parfumé disponible'), findsOneWidget);
  expect(find.text('Modèles de boubous'), findsOneWidget);

  // Commenter.
  await tapKey(tester, 'feed-comments-1');
  expect(find.text('Commentaires · 2'), findsOneWidget);
  expect(find.text('Vous livrez vers Djarengol ?'), findsOneWidget);
  await tester.enterText(key('comment-field'), '   ');
  await tester.pump();
  expect(tester.widget<IconButton>(key('comment-send')).onPressed, isNull,
      reason: 'un commentaire vide ne part pas');
  await tester.enterText(key('comment-field'), 'Merci, je passe demain');
  await tester.pump();
  await tester.tap(key('comment-send'));
  await tester.pumpAndSettle();
  expect(fh.repo.added, ['Merci, je passe demain']);
  expect(find.text('Merci, je passe demain'), findsOneWidget);
  expect(find.text('Commentaires · 3'), findsOneWidget);
  await tapKey(tester, 'post-back');
  expect(find.text('3 commentaires · écrire un commentaire'), findsOneWidget);

  // Signaler.
  await tapKey(tester, 'feed-report-2');
  expect(key('report-sheet'), findsOneWidget);
  await tapKey(tester, 'report-reason-arnaque');
  expect(fh.reports.calls.single, (target: ReportTarget.post, id: 2, reason: ReportReason.arnaque));
  expect(find.text('Merci, votre signalement a été envoyé.'), findsOneWidget);
  expect(find.text('Modèles de boubous'), findsNothing);
  expect(find.text('Nouveau lot de riz parfumé disponible'), findsOneWidget);

  // Publier : le serveur refuse d'abord (plafond du jour), puis accepte.
  await openTab(tester, 3);
  await tapKey(tester, 'profile-my-posts');
  await tapKey(tester, 'posts-publish');
  await tapKey(tester, 'post-media');
  await tester.tap(key('post-media-gallery'));
  await tester.pumpAndSettle();
  await tester.enterText(key('post-caption'), 'Riz parfumé en promotion');
  await tester.pump();
  ph.forum.createError = kDailyError;
  await tapKey(tester, 'post-publish');
  expect(ph.forum.created, isEmpty);
  expect(find.text('Vous avez atteint la limite de 5 publications par jour. Réessayez demain.'),
      findsOneWidget);

  ph.forum.createError = null;
  await tapKey(tester, 'post-publish');
  expect(ph.forum.created.single.caption, 'Riz parfumé en promotion');
  expect(ph.business.signedKinds, isNotEmpty);
  expect(ph.business.signedKinds.toSet(), {'post_image'}, reason: 'la photo est signée puis envoyée');
  expect(find.text('Publication envoyée.'), findsOneWidget);
  expect(find.text('Riz parfumé en promotion'), findsOneWidget);
}

// ============================================================================= COMPTE

/// Modifier ma boutique : Profil (actif) → Modifier ma boutique → repère et description sans
/// nouvelle validation → de nouveau, changer le NOM prévient (annuler ne change rien) puis remet
/// le compte « en attente de validation ».
Future<void> scenarioAccountEditBusiness(WidgetTester tester) async {
  final repo = BusinessRepositoryFake(
    initial: const MyBusiness(
      status: BusinessStatus.active,
      name: 'Boutique Mama Aïcha',
      typeCompte: BusinessAccountType.boutique,
      zoneId: 16,
      repere: 'Près du manguier',
      descriptionActivite: 'Fruits et légumes',
      representantNom: 'Aïcha Oumarou',
      hasPhoto: true,
      hasRepresentantPhoto: true,
    ),
  );
  await pumpBusinessApp(
    tester,
    initialLocation: Routes.profile,
    account: ScriptedAccountRepository(me: activeMe),
    overrides: [
      businessRepositoryProvider.overrideWithValue(repo),
      zoneRepositoryProvider.overrideWithValue(ZoneRepositoryFake()),
    ],
  );
  expect(find.text('Actif'), findsOneWidget);

  Future<void> enter(String key, String text) async {
    await tester.ensureVisible(_k(key));
    await tester.enterText(_k(key), text);
    await tester.pump();
  }

  await _showAndTap(tester, _k('profile-edit-business'));
  expect(tester.widget<TextField>(_k('business-edit-name')).controller!.text,
      'Boutique Mama Aïcha');
  expect(find.text('Aucune modification pour l\'instant.'), findsOneWidget);

  // Champs non sensibles : enregistrés, le compte reste actif.
  await enter('business-edit-repere', 'Face au marché');
  await tester.tap(_k('business-edit-save'));
  await tester.pumpAndSettle();
  expect(find.text('Modifications enregistrées.'), findsOneWidget);
  expect((await repo.getMine()).repere, 'Face au marché');
  expect((await repo.getMine()).status, BusinessStatus.active);
  expect(find.text('Actif'), findsOneWidget);

  // Le nom : avertissement ; refuser ne change rien ; confirmer remet en attente.
  await _showAndTap(tester, _k('profile-edit-business'));
  await enter('business-edit-name', 'Chez Aïcha');
  await tester.tap(_k('business-edit-save'));
  await tester.pumpAndSettle();
  expect(_k('business-edit-warning'), findsOneWidget);
  await tester.tap(_k('business-edit-warning-cancel'));
  await tester.pumpAndSettle();
  expect((await repo.getMine()).name, 'Boutique Mama Aïcha', reason: 'rien n\'est parti');

  await tester.tap(_k('business-edit-save'));
  await tester.pumpAndSettle();
  await tester.tap(_k('business-edit-warning-confirm'));
  await tester.pumpAndSettle();
  final saved = await repo.getMine();
  expect(saved.name, 'Chez Aïcha');
  expect(saved.status, BusinessStatus.pending);
  expect(find.text('En attente de validation'), findsOneWidget);
}

/// Suppression du compte : double confirmation ; annuler ne supprime rien ; une coupure réseau
/// garde le compte et affiche un message ; puis la suppression efface jetons, mémoire de la
/// recherche et du fil, et ramène à l'écran d'entrée (numéro). L'Accueil n'est plus accessible.
Future<void> scenarioAccountDeletion(WidgetTester tester) async {
  final forumCache = MemoryForumFeedCache();
  final searchCache = MemorySearchCache();
  await forumCache.write(CachedFeed(zone: 16, items: [feedPost(1, 'Riz de A')], count: 1));
  await searchCache.write(const CachedSearch(query: SearchQuery(zone: 16), items: [], count: 0));
  final account = ScriptedAccountRepository(
      me: const Me(id: 1, name: 'Jeff N.', phoneMasked: '+237 6•• •• •• 12'));
  final tokens = await _pumpSession(tester, signedIn: true, initialLocation: Routes.home, account: account, extra: [
    forumFeedCacheProvider.overrideWithValue(forumCache),
    searchCacheProvider.overrideWithValue(searchCache),
  ]);
  await openTab(tester, 3);

  // Annuler à la première fenêtre : rien ne bouge.
  await _showAndTap(tester, _k('profile-delete'));
  expect(_k('profile-delete-first'), findsOneWidget);
  await tester.tap(_k('profile-delete-first-cancel'));
  await tester.pumpAndSettle();
  expect(account.deleteCalls, 0);

  // Réseau coupé à la confirmation : message, compte et jetons gardés.
  account.deleteError = const ApiException(ApiErrorCode.network);
  await _showAndTap(tester, _k('profile-delete'));
  await tester.tap(_k('profile-delete-first-continue'));
  await tester.pumpAndSettle();
  await tester.tap(_k('profile-delete-second-confirm'));
  await tester.pumpAndSettle();
  expect(account.deleteCalls, 1);
  expect(_k('profile-delete-error'), findsOneWidget);
  expect((await tokens.read()).refresh, isNotNull);
  expect(forumCache.raw, isNotNull);
  expect(_onLogin(), isFalse);

  // Nouvel essai : supprimé.
  account.deleteError = null;
  await tester.tap(_k('profile-delete-second-confirm'));
  await tester.pumpAndSettle();
  expect(account.deleteCalls, 2);
  expect(_onLogin(), isTrue, reason: 'retour à l\'écran d\'entrée');
  final stored = await tokens.read();
  expect((stored.access, stored.refresh), (null, null));
  expect(forumCache.raw, isNull);
  expect(searchCache.raw, isNull);

  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(Routes.home);
  await tester.pumpAndSettle();
  expect(onHomeTabs(), isFalse, reason: 'plus de session : l\'Accueil est protégé');
}
