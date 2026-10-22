import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/account/data/models/me.dart';
import 'package:netbuis/features/auth/presentation/screens/login_screen.dart';
import 'package:netbuis/features/business/application/business_controller.dart';
import 'package:netbuis/features/business/data/models/business.dart';
import 'package:netbuis/features/settings/application/help_providers.dart';

import '../auth/auth_test_helpers.dart';
import '../auth/login_test_helpers.dart' show expectNoHorizontalScroll;
import 'account_test_helpers.dart';

Finder _k(String key) => find.byKey(ValueKey(key));

Me _me({bool business = false, int? free, int? credits}) => Me(
      id: 1,
      name: 'Jeff N.',
      phoneMasked: '+237 6•• •• •• 12',
      hasBusiness: business,
      freeCallAvailable: free,
      creditsBalance: credits,
    );

Future<void> _pump(
  WidgetTester tester, {
  Me? me,
  ScriptedAccountRepository? repo,
  MemoryTokenStorage? tokens,
  bool credits = false,
  MyBusiness? status,
}) =>
    pumpAccountApp(
      tester,
      account: repo ?? ScriptedAccountRepository(me: me ?? _me()),
      tokens: tokens,
      overrides: [
        if (credits) creditsEnabledProvider.overrideWithValue(true),
        if (status != null) myBusinessProvider.overrideWith((ref) async => status),
      ],
    );

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_k(key));
  await tester.pumpAndSettle();
  await tester.tap(_k(key));
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first));

String _path(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  group('crédits (CREDITS_ENABLED)', () {
    testWidgets('faux : aucun bloc, même si le serveur donnait des valeurs', (tester) async {
      await _pump(tester, me: _me(free: 0, credits: 235));
      expect(_k('profile-credits-card'), findsNothing);
      expect(find.text('Appel gratuit du jour'), findsNothing);
      expect(find.text('Solde de crédits'), findsNothing);
    });

    testWidgets('vrai : appel gratuit et solde (sans bouton d\'achat)', (tester) async {
      await _pump(tester, me: _me(free: 0, credits: 235), credits: true);
      expect(find.text('Appel gratuit du jour'), findsOneWidget);
      expect(find.text('0 / 1 restant'), findsOneWidget);
      expect(find.text('Solde de crédits'), findsOneWidget);
      expect(find.text('235 FCFA'), findsOneWidget);
      expect(find.textContaining('Acheter'), findsNothing);
    });

    testWidgets('vrai mais valeurs null : le bloc reste caché', (tester) async {
      await _pump(tester, me: _me(), credits: true);
      expect(_k('profile-credits-card'), findsNothing);
    });
  });

  group('compte business', () {
    testWidgets('sans compte business : invitation, pas de compteurs', (tester) async {
      await _pump(tester);
      expect(_k('profile-create-business'), findsOneWidget);
      expect(find.text('COMPTE BUSINESS'), findsNothing);
      expect(_k('profile-my-products'), findsNothing);
      expect(_k('profile-my-posts'), findsNothing);
    });

    testWidgets('en attente : état, Mes produits et Mes publications, pas d\'invitation',
        (tester) async {
      await _pump(tester,
          me: _me(business: true),
          status: const MyBusiness(status: BusinessStatus.pending, name: 'Chez Aïcha'));
      expect(find.text('COMPTE BUSINESS'), findsOneWidget);
      expect(find.text('En attente de validation'), findsOneWidget);
      expect(_k('profile-my-products'), findsOneWidget);
      expect(_k('profile-my-posts'), findsOneWidget);
      expect(_k('profile-create-business'), findsNothing);
    });

    testWidgets('rejeté : motif affiché', (tester) async {
      await _pump(tester,
          me: _me(business: true),
          status: const MyBusiness(
              status: BusinessStatus.rejected, name: 'Chez Aïcha', motifRejet: 'Photo illisible'));
      expect(find.text('Rejeté'), findsOneWidget);
      expect(find.text('Motif : Photo illisible'), findsOneWidget);
      expect(_k('profile-create-business'), findsNothing);
    });

    testWidgets('actif : état « Actif » et entrées', (tester) async {
      await _pump(tester,
          me: _me(business: true),
          status: const MyBusiness(status: BusinessStatus.active, name: 'Chez Aïcha'));
      expect(find.text('Actif'), findsOneWidget);
      expect(_k('profile-my-products'), findsOneWidget);
      expect(_k('profile-my-posts'), findsOneWidget);
    });

    for (final status in BusinessStatus.values) {
      testWidgets('$status : « Modifier ma boutique » là ; « Corriger » seulement si rejeté (T102b)',
          (tester) async {
        await _pump(tester,
            me: _me(business: true), status: MyBusiness(status: status, motifRejet: 'x'));
        expect(_k('profile-edit-business'), findsOneWidget);
        expect(find.text('Modifier ma boutique'), findsOneWidget);
        expect(find.text('Corriger'),
            status == BusinessStatus.rejected ? findsOneWidget : findsNothing);
      });
    }
  });

  group('entrées', () {
    testWidgets('chaque entrée visible mène à une route qui existe', (tester) async {
      await _pump(tester);
      final entries = <String, String>{
        'profile-history': Routes.callHistory,
        'profile-create-business-button': Routes.createBusiness,
        'profile-city': Routes.chooseCity,
        'profile-settings': Routes.settings,
        'profile-theme': Routes.settings,
        'profile-help': Routes.help,
      };
      for (final e in entries.entries) {
        await _tap(tester, e.key);
        expect(_path(tester), e.value, reason: e.key);
        expect(find.text('Page Not Found'), findsNothing, reason: e.key);
        expect(find.byKey(const ValueKey('profile-logout')), findsNothing, reason: e.key);
        _router(tester).pop();
        await tester.pumpAndSettle();
        expect(_path(tester), Routes.profile, reason: e.key);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('entrées du compte business : Mes publications mène à sa route; Mes produits s\'ouvre',
        (tester) async {
      await _pump(tester,
          me: _me(business: true),
          status: const MyBusiness(status: BusinessStatus.active, name: 'Chez Aïcha'));
      await _tap(tester, 'profile-my-posts');
      expect(_path(tester), Routes.myPosts);
      _router(tester).pop();
      await tester.pumpAndSettle();

      await _tap(tester, 'profile-my-products');
      expect(find.byKey(const ValueKey('profile-logout')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Langue et Thème montrent le choix en cours', (tester) async {
      await _pump(tester);
      expect(find.text('Langue'), findsOneWidget);
      expect(find.text('Thème'), findsOneWidget);
      expect(find.text('Aide & support'), findsOneWidget);
      expect(find.text('Français'), findsOneWidget);
      expect(find.text('Automatique'), findsOneWidget);
    });
  });

  group('déconnexion', () {
    testWidgets('efface les jetons et revient à la connexion', (tester) async {
      final tokens = MemoryTokenStorage(access: 'acc-1', refresh: 'ref-1');
      await _pump(tester, tokens: tokens);
      await _tap(tester, 'profile-logout');
      expect(find.byType(LoginScreen), findsOneWidget);
      final stored = await tokens.read();
      expect((stored.access, stored.refresh), (null, null));
    });
  });

  group('suppression du compte', () {
    testWidgets('double confirmation : annuler à la 1re ou à la 2e étape ne supprime rien',
        (tester) async {
      final repo = ScriptedAccountRepository(me: _me());
      final tokens = MemoryTokenStorage(access: 'acc-1', refresh: 'ref-1');
      await _pump(tester, repo: repo, tokens: tokens);

      await _tap(tester, 'profile-delete');
      expect(find.text('Supprimer votre compte ?'), findsOneWidget);
      expect(_k('profile-delete-second'), findsNothing);
      await tester.tap(_k('profile-delete-first-cancel'));
      await tester.pumpAndSettle();
      expect(repo.deleteCalls, 0);

      await _tap(tester, 'profile-delete');
      await tester.tap(_k('profile-delete-first-continue'));
      await tester.pumpAndSettle();
      expect(find.text('Dernière confirmation'), findsOneWidget);
      expect(repo.deleteCalls, 0);
      await tester.tap(_k('profile-delete-second-cancel'));
      await tester.pumpAndSettle();
      expect(repo.deleteCalls, 0);
      expect((await tokens.read()).refresh, 'ref-1');
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('succès : DELETE appelé, jetons effacés, retour à la connexion', (tester) async {
      final repo = ScriptedAccountRepository(me: _me());
      final tokens = MemoryTokenStorage(access: 'acc-1', refresh: 'ref-1');
      await _pump(tester, repo: repo, tokens: tokens);

      await _tap(tester, 'profile-delete');
      await tester.tap(_k('profile-delete-first-continue'));
      await tester.pumpAndSettle();
      await tester.tap(_k('profile-delete-second-confirm'));
      await tester.pumpAndSettle();

      expect(repo.deleteCalls, 1);
      expect(find.byType(LoginScreen), findsOneWidget);
      final stored = await tokens.read();
      expect((stored.access, stored.refresh), (null, null));
      expect(tester.takeException(), isNull);
    });

    testWidgets('réseau coupé : message clair, rien n\'est effacé, on peut réessayer',
        (tester) async {
      final repo = ScriptedAccountRepository(me: _me())
        ..deleteError = const ApiException(ApiErrorCode.network);
      final tokens = MemoryTokenStorage(access: 'acc-1', refresh: 'ref-1');
      await _pump(tester, repo: repo, tokens: tokens);

      await _tap(tester, 'profile-delete');
      await tester.tap(_k('profile-delete-first-continue'));
      await tester.pumpAndSettle();
      await tester.tap(_k('profile-delete-second-confirm'));
      await tester.pumpAndSettle();

      expect(repo.deleteCalls, 1);
      expect(find.text('Pas de connexion. Votre compte n\'a pas été supprimé. Réessayez.'),
          findsOneWidget);
      expect((await tokens.read()).refresh, 'ref-1');
      expect(find.byType(LoginScreen), findsNothing);

      repo.deleteError = null;
      await tester.tap(_k('profile-delete-second-confirm'));
      await tester.pumpAndSettle();
      expect(repo.deleteCalls, 2);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('autre erreur : message générique, rien n\'est effacé', (tester) async {
      final repo = ScriptedAccountRepository(me: _me())
        ..deleteError = const ApiException(ApiErrorCode.unknown, statusCode: 500);
      final tokens = MemoryTokenStorage(access: 'acc-1', refresh: 'ref-1');
      await _pump(tester, repo: repo, tokens: tokens);

      await _tap(tester, 'profile-delete');
      await tester.tap(_k('profile-delete-first-continue'));
      await tester.pumpAndSettle();
      await tester.tap(_k('profile-delete-second-confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Votre compte n\'a pas été supprimé. Réessayez.'), findsOneWidget);
      expect((await tokens.read()).refresh, 'ref-1');
    });
  });

  testWidgets('360 px, police 130 %, clair : tout le Profil se construit sans débordement',
      (tester) async {
    await pumpAccountApp(
      tester,
      account: ScriptedAccountRepository(me: _me(business: true, free: 1, credits: 50)),
      textScale: 1.3,
      mode: ThemeMode.light,
      overrides: [
        creditsEnabledProvider.overrideWithValue(true),
        myBusinessProvider.overrideWith((ref) async =>
            const MyBusiness(status: BusinessStatus.rejected, name: 'Chez Aïcha', motifRejet: 'Photo illisible')),
      ],
    );
    expect(tester.takeException(), isNull);
    expectNoHorizontalScroll(tester);
  });
}
