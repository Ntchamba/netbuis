// T121 : jetons et mémoires du compte effacés quand la session est fermée, quelle qu'en soit la
// raison (jeton refusé, compte bloqué ou supprimé), à la déconnexion et à la suppression du compte.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/network/interceptors/refresh_interceptor.dart';
import 'package:netbuis/features/account/data/models/me.dart';
import 'package:netbuis/features/auth/application/auth_controller.dart';
import 'package:netbuis/features/auth/application/auth_state.dart';
import 'package:netbuis/features/auth/data/models/auth_tokens.dart';
import 'package:netbuis/features/forum/application/forum_services.dart';
import 'package:netbuis/features/forum/data/forum_feed_cache.dart';
import 'package:netbuis/features/search/application/search_controller.dart';
import 'package:netbuis/features/search/data/models/search_query.dart';
import 'package:netbuis/features/search/data/search_cache.dart';

import '../account/account_test_helpers.dart';
import '../forum/forum_test_helpers.dart';
import 'auth_test_helpers.dart';
import 'login_test_helpers.dart';

class _RefusingRepository extends FlowRepository {
  _RefusingRepository(this.error);
  final ApiException error;
  int refreshCalls = 0;

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    refreshCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    throw error;
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  for (final code in [
    ApiErrorCode.tokenInvalid,
    ApiErrorCode.accountBlocked,
    ApiErrorCode.accountDeleted,
  ]) {
    test('renouvellement refusé (${code.value}) : jetons ET mémoires disque effacés', () async {
      final tokens = MemoryTokenStorage(access: 'acc-1', refresh: 'ref-1');
      final forum = MemoryForumFeedCache();
      final search = MemorySearchCache();
      await forum.write(CachedFeed(zone: 16, items: [feedPost(1, 'Riz de A')], count: 1));
      await search.write(const CachedSearch(query: SearchQuery(zone: 16), items: [], count: 0));
      final repo = _RefusingRepository(ApiException(code, statusCode: 401));
      final c = ProviderContainer(overrides: [
        tokenStorageProvider.overrideWithValue(tokens),
        authRepositoryProvider.overrideWithValue(repo),
        forumFeedCacheProvider.overrideWithValue(forum),
        searchCacheProvider.overrideWithValue(search),
      ]);
      addTearDown(c.dispose);
      c.listen(authControllerProvider, (_, __) {});
      await _settle();
      expect(c.read(authControllerProvider), isA<AuthAuthenticated>());
      expect(forum.raw, isNotNull);

      final outcome = await c.read(sessionRefresherProvider).refresh();
      await _settle();

      expect(outcome, RefreshOutcome.rejected);
      final stored = await tokens.read();
      expect((stored.access, stored.refresh), (null, null));
      expect(forum.raw, isNull, reason: 'fil du forum du compte précédent');
      expect(search.raw, isNull, reason: 'dernière recherche du compte précédent');
      expect(c.read(authControllerProvider), isNot(isA<AuthAuthenticated>()));
    });
  }

  test('un seul renouvellement pour plusieurs appelants simultanés', () async {
    final tokens = MemoryTokenStorage(access: 'acc-1', refresh: 'ref-1');
    final repo = _RefusingRepository(const ApiException(ApiErrorCode.tokenInvalid));
    final c = ProviderContainer(overrides: [
      tokenStorageProvider.overrideWithValue(tokens),
      authRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(c.dispose);
    final refresher = c.read(sessionRefresherProvider);
    final results = await Future.wait([refresher.refresh(), refresher.refresh(), refresher.refresh()]);
    expect(results, everyElement(RefreshOutcome.rejected));
    expect(repo.refreshCalls, 1);
  });

  testWidgets('suppression du compte : jetons effacés et retour à la connexion', (tester) async {
    final tokens = MemoryTokenStorage(access: 'acc-1', refresh: 'ref-1');
    final repo = ScriptedAccountRepository(
        me: const Me(id: 1, name: 'A', phoneMasked: '+237 6•• •• •• 12'));
    await pumpAccountApp(tester, account: repo, tokens: tokens);
    expect((await tokens.read()).hasRefresh, isTrue);

    final profileDelete = find.byKey(const ValueKey('profile-delete'));
    await tester.ensureVisible(profileDelete);
    await tester.pumpAndSettle();
    await tester.tap(profileDelete);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-delete-first-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-delete-second-confirm')));
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, 1);
    final stored = await tokens.read();
    expect((stored.access, stored.refresh), (null, null));
  });

  testWidgets('suppression refusée par le serveur : les jetons restent (rien n\'est effacé à tort)',
      (tester) async {
    final tokens = MemoryTokenStorage(access: 'acc-1', refresh: 'ref-1');
    final repo = ScriptedAccountRepository(
        me: const Me(id: 1, name: 'A', phoneMasked: '+237 6•• •• •• 12'))
      ..deleteError = const ApiException(ApiErrorCode.network);
    await pumpAccountApp(tester, account: repo, tokens: tokens);
    final profileDelete = find.byKey(const ValueKey('profile-delete'));
    await tester.ensureVisible(profileDelete);
    await tester.pumpAndSettle();
    await tester.tap(profileDelete);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-delete-first-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-delete-second-confirm')));
    await tester.pumpAndSettle();
    expect((await tokens.read()).hasRefresh, isTrue);
  });
}
