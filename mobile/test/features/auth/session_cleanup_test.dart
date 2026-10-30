// T103b : à la déconnexion et à la suppression du compte, rien du compte précédent ne reste
// (mémoires disque du fil et de la recherche, fil en mémoire, signalements), même si les écrans
// Forum et Recherche n'ont jamais été ouverts.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/storage/prefs.dart';
import 'package:netbuis/features/account/data/models/me.dart';
import 'package:netbuis/features/auth/application/auth_controller.dart';
import 'package:netbuis/features/auth/application/auth_state.dart';
import 'package:netbuis/features/forum/application/forum_feed_controller.dart';
import 'package:netbuis/features/forum/application/forum_services.dart';
import 'package:netbuis/features/forum/application/report_controller.dart';
import 'package:netbuis/features/forum/data/forum_feed_cache.dart';
import 'package:netbuis/features/forum/data/models/report.dart';
import 'package:netbuis/features/search/application/search_controller.dart';
import 'package:netbuis/features/search/data/models/search_query.dart';
import 'package:netbuis/features/search/data/models/search_result.dart';
import 'package:netbuis/features/search/data/search_cache.dart';

import '../account/account_test_helpers.dart';
import '../forum/forum_test_helpers.dart';
import 'auth_test_helpers.dart';
import 'login_test_helpers.dart';

const _found = [
  SearchResult(
      id: 1,
      name: 'Boutique Aminatou',
      kind: 'produit',
      secteur: 'Alimentation',
      zone: ResultZone(id: 16, name: 'Maroua'),
      descriptionActivite: 'Riz et huile'),
];

Future<void> _fillCaches(MemoryForumFeedCache forum, MemorySearchCache search) async {
  await forum.write(CachedFeed(zone: 16, items: [feedPost(1, 'Riz de A')], count: 1));
  await search.write(const CachedSearch(query: SearchQuery(zone: 16), items: _found, count: 1));
}

ProviderContainer _container({
  required MemoryForumFeedCache forum,
  required MemorySearchCache search,
  required ScriptedFeedRepository feed,
}) {
  final c = ProviderContainer(overrides: [
    tokenStorageProvider.overrideWithValue(MemoryTokenStorage(refresh: 'ref-A')),
    authRepositoryProvider.overrideWithValue(FlowRepository()),
    forumFeedCacheProvider.overrideWithValue(forum),
    searchCacheProvider.overrideWithValue(search),
    forumFeedRepositoryProvider.overrideWithValue(feed),
    appPrefsProvider.overrideWithValue(MemoryPrefs(city: const SelectedCity(id: 16, name: 'Maroua'))),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  test('A connecté, onglets jamais ouverts : la déconnexion vide les deux mémoires', () async {
    final forum = MemoryForumFeedCache();
    final search = MemorySearchCache();
    await _fillCaches(forum, search);
    final c = _container(forum: forum, search: search, feed: ScriptedFeedRepository());
    c.listen(authControllerProvider, (_, __) {});
    await _settle();
    expect(c.read(authControllerProvider), isA<AuthAuthenticated>());
    expect(forum.raw, isNotNull);
    expect(search.raw, isNotNull);

    await c.read(authControllerProvider.notifier).logout();

    expect(c.read(authControllerProvider), isA<AuthLoggedOut>());
    expect(forum.raw, isNull);
    expect(search.raw, isNull);
  });

  test('sans effacement, les mémoires restent (le test détecte bien le défaut)', () async {
    final forum = MemoryForumFeedCache();
    final search = MemorySearchCache();
    await _fillCaches(forum, search);
    final c = _container(forum: forum, search: search, feed: ScriptedFeedRepository());
    c.listen(authControllerProvider, (_, __) {});
    await _settle();
    // Aucune déconnexion : rien n'est effacé.
    expect(forum.raw, isNotNull);
    expect(search.raw, isNotNull);
  });

  test('A déconnecté puis B connecté : ni mémoire, ni fil, ni signalements de A', () async {
    final forum = MemoryForumFeedCache();
    final search = MemorySearchCache();
    final feed = ScriptedFeedRepository(posts: [feedPost(1, 'Riz de A'), feedPost(2, 'Huile de A')]);
    final c = _container(forum: forum, search: search, feed: feed);
    c.listen(authControllerProvider, (_, __) {});
    c.listen(forumFeedProvider, (_, __) {});
    c.listen(reportsProvider, (_, __) {});
    await _settle();
    // A a vu le fil, l'a mémorisé et a signalé la publication 2.
    expect(c.read(forumFeedProvider).items, isNotEmpty);
    await c.read(reportsProvider.notifier).submit(ReportTarget.post, 2, ReportReason.inapproprie);
    await _settle();
    expect(c.read(reportsProvider).posts, {2});
    expect(forum.raw, isNotNull);

    await c.read(authControllerProvider.notifier).logout();
    // Avant que le fil de B ne se charge : rien de A.
    expect(forum.raw, isNull);
    expect(search.raw, isNull);
    expect(c.read(reportsProvider).posts, isEmpty);
    expect(c.read(forumFeedProvider).items, isEmpty);
    expect(c.read(searchControllerProvider).items, isEmpty);

    // B se connecte.
    final auth = c.read(authControllerProvider.notifier);
    await auth.requestOtp('612345678');
    await auth.verifyOtp('123456');
    expect(c.read(authControllerProvider), isA<AuthAuthenticated>());
    expect(c.read(reportsProvider).posts, isEmpty);
    expect(c.read(reportsProvider).comments, isEmpty);
    expect(c.read(reportsProvider).businesses, isEmpty);
  });

  testWidgets('suppression du compte : mémoires du fil et de la recherche effacées', (tester) async {
    final forum = MemoryForumFeedCache();
    final search = MemorySearchCache();
    await _fillCaches(forum, search);
    final repo = ScriptedAccountRepository(
        me: const Me(id: 1, name: 'A', phoneMasked: '+237 6•• •• •• 12'));
    await pumpAccountApp(tester, account: repo, overrides: [
      forumFeedCacheProvider.overrideWithValue(forum),
      searchCacheProvider.overrideWithValue(search),
    ]);
    expect(forum.raw, isNotNull);

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
    expect(forum.raw, isNull);
    expect(search.raw, isNull);
  });
}
