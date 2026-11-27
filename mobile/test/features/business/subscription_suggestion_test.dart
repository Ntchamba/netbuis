// T111 : encart « Vous recevez beaucoup d'appels » (Profil) et écran « Bientôt disponible ».
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/router/guards.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/account/data/models/me.dart';
import 'package:netbuis/features/auth/application/auth_state.dart';
import 'package:netbuis/features/auth/presentation/screens/login_screen.dart';
import 'package:netbuis/features/business/data/models/business.dart';
import 'package:netbuis/features/business/data/repositories/business_repository_fake.dart';
import 'package:netbuis/features/business/presentation/screens/subscription_soon_screen.dart';
import 'package:netbuis/features/call/data/call_channel.dart';
import 'package:netbuis/features/settings/application/help_providers.dart';

import '../account/account_test_helpers.dart';
import '../call/call_test_helpers.dart';
import 'business_test_helpers.dart';

// Valeurs d'essai : ce ne sont pas de vrais contacts.
const _fakeSupport = SupportContact(whatsapp: '+237 0000 0000');

Finder get _card => find.byKey(const ValueKey('profile-subscription-card'));
Finder get _subscribe =>
    find.byKey(const ValueKey('profile-subscription-button'));
Finder get _whatsapp => find.byKey(const ValueKey('subscription-whatsapp'));

Me _me({bool hasBusiness = true}) => Me(
      id: 1,
      name: 'Jeff N.',
      phoneMasked: '+237 6•• •• •• 12',
      hasBusiness: hasBusiness,
    );

MyBusiness _mine(BusinessStatus status, {bool suggest = true}) => MyBusiness(
    status: status, name: 'Chez Aïcha', suggestSubscription: suggest);

Future<void> _pumpProfile(
  WidgetTester tester, {
  MyBusiness? mine,
  bool hasBusiness = true,
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.dark,
  FakeCallChannel? channel,
  SupportContact contact = _fakeSupport,
}) =>
    pumpBusinessApp(
      tester,
      initialLocation: Routes.profile,
      account: ScriptedAccountRepository(me: _me(hasBusiness: hasBusiness)),
      textScale: textScale,
      mode: mode,
      overrides: [
        businessRepositoryProvider
            .overrideWithValue(BusinessRepositoryFake(initial: mine)),
        callChannelProvider.overrideWithValue(channel ?? FakeCallChannel()),
        supportContactProvider.overrideWithValue(contact),
      ],
    );

Future<void> _pumpSoon(
  WidgetTester tester, {
  FakeCallChannel? channel,
  SupportContact contact = _fakeSupport,
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.dark,
  bool signedIn = true,
}) =>
    pumpBusinessApp(
      tester,
      initialLocation: Routes.subscriptionSoon,
      signedIn: signedIn,
      textScale: textScale,
      mode: mode,
      overrides: [
        callChannelProvider.overrideWithValue(channel ?? FakeCallChannel()),
        supportContactProvider.overrideWithValue(contact),
      ],
    );

void main() {
  group('modèle', () {
    test('suggest_subscription lu ; faux si absent ou non booléen', () {
      MyBusiness parse(Map<String, dynamic> extra) =>
          MyBusiness.fromJson({'status': 'actif', ...extra});
      expect(parse({'suggest_subscription': true}).suggestSubscription, isTrue);
      expect(
          parse({'suggest_subscription': false}).suggestSubscription, isFalse);
      expect(parse({}).suggestSubscription, isFalse);
      expect(
          parse({'suggest_subscription': 'true'}).suggestSubscription, isFalse);
    });
  });

  group('encart du Profil', () {
    testWidgets(
        'actif + suggest : visible, « Souscrire » ouvre « Bientôt disponible »',
        (tester) async {
      await _pumpProfile(tester, mine: _mine(BusinessStatus.active));
      await tester.ensureVisible(_card);
      expect(_card, findsOneWidget);
      expect(find.text("Vous recevez beaucoup d'appels"), findsOneWidget);
      expect(tester.getSize(_subscribe).height, greaterThanOrEqualTo(48));

      await tester.ensureVisible(_subscribe);
      await tester.tap(_subscribe);
      await tester.pumpAndSettle();
      expect(find.byType(SubscriptionSoonScreen), findsOneWidget);
      expect(find.text('Bientôt disponible'), findsOneWidget);
    });

    testWidgets('masqué : suggest faux', (tester) async {
      await _pumpProfile(tester,
          mine: _mine(BusinessStatus.active, suggest: false));
      expect(find.text('Chez Aïcha'), findsWidgets);
      expect(_card, findsNothing);
    });

    testWidgets('masqué : champ absent (anciennes réponses)', (tester) async {
      await _pumpProfile(tester,
          mine: const MyBusiness(status: BusinessStatus.active));
      expect(_card, findsNothing);
    });

    testWidgets('masqué : compte en attente, même si suggest est vrai',
        (tester) async {
      await _pumpProfile(tester, mine: _mine(BusinessStatus.pending));
      expect(_card, findsNothing);
    });

    testWidgets('masqué : compte rejeté, même si suggest est vrai',
        (tester) async {
      await _pumpProfile(tester, mine: _mine(BusinessStatus.rejected));
      expect(_card, findsNothing);
    });

    testWidgets('masqué : compte sans business', (tester) async {
      await _pumpProfile(tester, hasBusiness: false);
      expect(_card, findsNothing);
      expect(find.byKey(const ValueKey('profile-create-business')),
          findsOneWidget);
    });

    testWidgets('360 px, 130 %, clair et sombre : sans débordement',
        (tester) async {
      for (final mode in [ThemeMode.dark, ThemeMode.light]) {
        await _pumpProfile(tester,
            mine: _mine(BusinessStatus.active), textScale: 1.3, mode: mode);
        await tester.ensureVisible(_card);
        expect(_card, findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$mode');
      }
    });
  });

  group('écran « Bientôt disponible »', () {
    testWidgets(
        'numéro du support à remplacer : bouton désactivé et message simple',
        (tester) async {
      await _pumpSoon(tester, contact: const SupportContact());
      expect(find.text('Contactez le support'), findsOneWidget);
      expect(find.byKey(const ValueKey('subscription-contact-soon')),
          findsOneWidget);
      expect(find.text('Coordonnées du support à venir'), findsOneWidget);
      expect(tester.widget<FilledButton>(_whatsapp).onPressed, isNull);
    });

    testWidgets(
        'numéro valide : WhatsApp ouvert avec un lien wa.me et un message',
        (tester) async {
      final channel = FakeCallChannel();
      await _pumpSoon(tester, channel: channel);
      expect(tester.widget<FilledButton>(_whatsapp).onPressed, isNotNull);
      await tester.tap(_whatsapp);
      await tester.pumpAndSettle();
      expect(channel.whatsappOpened, hasLength(1));
      final uri = Uri.parse(channel.whatsappOpened.single);
      expect(uri.host, 'wa.me');
      expect(uri.path, '/23700000000');
      expect(uri.queryParameters['text'],
          "Bonjour NetBuis, je souhaite en savoir plus sur l'abonnement.");
    });

    testWidgets('WhatsApp absent ou échec : message simple', (tester) async {
      final channel = FakeCallChannel()
        ..whatsappResult = WhatsappOpenResult.notInstalled;
      await _pumpSoon(tester, channel: channel);
      await tester.tap(_whatsapp);
      await tester.pumpAndSettle();
      expect(find.text("WhatsApp n'est pas installé sur ce téléphone."),
          findsOneWidget);

      final failing = FakeCallChannel()..throwOnWhatsapp = true;
      await _pumpSoon(tester, channel: failing);
      await tester.tap(_whatsapp);
      await tester.pumpAndSettle();
      expect(find.text("Impossible d'ouvrir WhatsApp pour le moment."),
          findsOneWidget);
    });

    testWidgets('bouton Retour ramène à l\'écran précédent', (tester) async {
      await _pumpProfile(tester, mine: _mine(BusinessStatus.active));
      await tester.ensureVisible(_subscribe);
      await tester.tap(_subscribe);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('subscription-back')));
      await tester.pumpAndSettle();
      expect(find.byType(SubscriptionSoonScreen), findsNothing);
      expect(find.text('Mon profil'), findsOneWidget);
    });

    testWidgets('360 px, 130 %, clair et sombre : sans débordement',
        (tester) async {
      for (final mode in [ThemeMode.dark, ThemeMode.light]) {
        for (final contact in [_fakeSupport, const SupportContact()]) {
          await _pumpSoon(tester, textScale: 1.3, mode: mode, contact: contact);
          expect(tester.takeException(), isNull, reason: '$mode');
          expect(
              find.byKey(const ValueKey('subscription-back')), findsOneWidget);
        }
      }
    });

    testWidgets('route protégée : sans session, la connexion s\'affiche',
        (tester) async {
      await _pumpSoon(tester, signedIn: false);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SubscriptionSoonScreen), findsNothing);
    });

    test('la garde renvoie vers la connexion sans session', () {
      expect(authRedirect(const AuthLoggedOut(), Routes.subscriptionSoon),
          Routes.login);
      expect(authRedirect(const AuthAuthenticated(), Routes.subscriptionSoon),
          isNull);
      expect(Routes.openLegalPaths, isNot(contains(Routes.subscriptionSoon)));
    });
  });

  group('textes', () {
    final forbidden = RegExp(
      r'pay|paie|mobile money|fcfa|xaf|\bprix\b|price|cost|co[uû]t|gratuit|free|urgent|bloqu|block|suspend|expire',
      caseSensitive: false,
    );
    for (final lang in ['fr', 'en']) {
      test('$lang : aucun mot de paiement, de prix ni de menace', () {
        final map =
            jsonDecode(File('assets/l10n/$lang.json').readAsStringSync())
                as Map<String, dynamic>;
        final keys = map.keys.where((k) => k.startsWith('subscription.'));
        expect(keys, isNotEmpty);
        for (final k in keys) {
          expect(forbidden.hasMatch(map[k] as String), isFalse,
              reason: '$lang $k');
          expect(RegExp(r'\d').hasMatch(map[k] as String), isFalse,
              reason: '$lang $k chiffre');
        }
      });
    }

    test('parité fr / en des clés subscription.*', () {
      Set<String> keys(String lang) =>
          (jsonDecode(File('assets/l10n/$lang.json').readAsStringSync())
                  as Map<String, dynamic>)
              .keys
              .where((k) => k.startsWith('subscription.'))
              .toSet();
      expect(keys('fr'), keys('en'));
    });
  });
}
