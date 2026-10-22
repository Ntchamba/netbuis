import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/features/forum/data/forum_feed_cache.dart';
import 'package:netbuis/features/forum/data/models/report.dart';

import 'package:netbuis/features/forum/presentation/widgets/report_menu_button.dart';

import 'forum_test_helpers.dart';
import 'post_test_helpers.dart';

const _thanks = 'Merci, votre signalement a été envoyé.';

MemoryForumFeedCache _cache() => MemoryForumFeedCache();

ForumHarness _harness({MemoryForumFeedCache? cache, bool mineFirst = false}) =>
    ForumHarness(
      cache: cache,
      posts: [
        feedPost(1, 'Nouveau lot de riz', comments: 2, mine: mineFirst),
        feedPost(2, 'Modèles de boubous', name: 'Couturier Ibrahim'),
      ],
      comments: [
        comment(10, 'Le riz est disponible ?'),
        comment(11, 'Merci pour la réponse', mine: true),
      ],
    );

Finder get _sheet => key('report-sheet');

Future<void> _openPostPage(WidgetTester tester, ForumHarness h) async {
  await h.pump(tester);
  await tapKey(tester, 'feed-comments-1');
}

List<int> _cachedIds(MemoryForumFeedCache cache) => [
      for (final p in (jsonDecode(cache.raw!) as Map)['results'] as List)
        (p as Map)['id'] as int
    ];

void main() {
  group('feuille de motifs', () {
    testWidgets(
        '4 gros boutons icône + mot, Annuler ferme sans rien envoyer, aucune saisie libre',
        (tester) async {
      final h = _harness();
      await h.pump(tester);
      await tapKey(tester, 'feed-report-1');
      expect(_sheet, findsOneWidget);
      expect(find.text('Signaler cette publication'), findsWidgets);
      for (final label in ['Spam', 'Arnaque', 'Contenu inapproprié', 'Autre']) {
        expect(find.text(label), findsOneWidget);
      }
      for (final r in ReportReason.values) {
        final button = key('report-reason-${r.value}');
        expect(button, findsOneWidget);
        expect(find.descendant(of: button, matching: find.byIcon(r.icon)),
            findsOneWidget);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(64));
      }
      expect(find.byType(TextField), findsNothing);

      await tapKey(tester, 'report-cancel');
      expect(_sheet, findsNothing);
      expect(h.reports.calls, isEmpty);
      expect(find.text('Nouveau lot de riz'), findsOneWidget);
    });

    testWidgets('chaque motif envoie la bonne valeur en un seul toucher',
        (tester) async {
      for (final r in ReportReason.values) {
        final h = _harness();
        await h.pump(tester);
        await tapKey(tester, 'feed-report-1');
        await tapKey(tester, 'report-reason-${r.value}');
        expect(h.reports.calls.single,
            (target: ReportTarget.post, id: 1, reason: r));
        expect(_sheet, findsNothing);
      }
      // Les valeurs sont celles de l'API.
      expect([for (final r in ReportReason.values) r.value],
          ['spam', 'arnaque', 'contenu_inapproprie', 'autre']);
    });
  });

  group('publication', () {
    testWidgets(
        'fil : merci, la publication disparaît du fil et de la mémoire hors connexion',
        (tester) async {
      final cache = _cache();
      final h = _harness(cache: cache);
      await h.pump(tester);
      expect(_cachedIds(cache), [1, 2]);

      await tapKey(tester, 'feed-report-1');
      await tapKey(tester, 'report-reason-spam');

      expect(find.text(_thanks), findsOneWidget);
      expect(find.text('Nouveau lot de riz'), findsNothing);
      expect(find.text('Modèles de boubous'), findsOneWidget);
      expect(_cachedIds(cache), [2]);
    });

    testWidgets('la dernière publication signalée : le fil devient vide',
        (tester) async {
      final cache = _cache();
      final h = ForumHarness(cache: cache, posts: [feedPost(1, 'Seule')]);
      await h.pump(tester);
      await tapKey(tester, 'feed-report-1');
      await tapKey(tester, 'report-reason-autre');
      expect(key('forum-empty'), findsOneWidget);
      expect(cache.raw, isNull);
    });

    testWidgets(
        'rechargement : un contenu signalé par moi ne revient pas, même si la réponse le contient',
        (tester) async {
      final h = _harness();
      await h.pump(tester);
      await tapKey(tester, 'feed-report-1');
      await tapKey(tester, 'report-reason-arnaque');
      // Le dépôt scénarisé renvoie encore la publication : l'application ne la montre plus.
      await tester.fling(
          find.byType(ListView).first, const Offset(0, 400), 800);
      await tester.pumpAndSettle();
      expect(h.repo.feedCalls.length, greaterThan(1));
      expect(find.text('Nouveau lot de riz'), findsNothing);
      expect(find.text('Modèles de boubous'), findsOneWidget);
    });

    testWidgets('page de la publication : signaler la ramène au fil, sans elle',
        (tester) async {
      final h = _harness();
      await _openPostPage(tester, h);
      expect(key('post-caption'), findsOneWidget);
      await tapKey(tester, 'post-report');
      expect(find.text('Signaler cette publication'), findsWidgets);
      await tapKey(tester, 'report-reason-contenu_inapproprie');

      expect(h.reports.calls.single,
          (target: ReportTarget.post, id: 1, reason: ReportReason.inapproprie));
      expect(find.text(_thanks), findsOneWidget);
      expect(key('post-caption'), findsNothing);
      expect(find.text('Nouveau lot de riz'), findsNothing);
      expect(find.text('Modèles de boubous'), findsOneWidget);
    });

    testWidgets('pas de bouton Signaler sur mes propres publications',
        (tester) async {
      final h = _harness(mineFirst: true);
      await h.pump(tester);
      expect(key('feed-report-1'), findsNothing);
      expect(key('feed-report-2'), findsOneWidget);
      await tapKey(tester, 'feed-comments-1');
      expect(key('post-caption'), findsOneWidget);
      expect(key('post-report'), findsNothing);
    });
  });

  group('commentaire', () {
    testWidgets(
        'signaler un commentaire : merci, il disparaît de la page, les autres restent',
        (tester) async {
      final h = _harness();
      await _openPostPage(tester, h);
      expect(find.text('Le riz est disponible ?'), findsOneWidget);
      await tapKey(tester, 'comment-report-10');
      expect(find.text('Signaler ce commentaire'), findsWidgets);
      await tapKey(tester, 'report-reason-arnaque');

      expect(h.reports.calls.single,
          (target: ReportTarget.comment, id: 10, reason: ReportReason.arnaque));
      expect(find.text(_thanks), findsOneWidget);
      expect(find.text('Le riz est disponible ?'), findsNothing);
      expect(find.text('Merci pour la réponse'), findsOneWidget);
      // La publication reste affichée.
      expect(key('post-caption'), findsOneWidget);
    });

    testWidgets('pas de bouton Signaler sur mes propres commentaires',
        (tester) async {
      final h = _harness();
      await _openPostPage(tester, h);
      expect(key('comment-report-10'), findsOneWidget);
      expect(key('comment-report-11'), findsNothing);
    });

    testWidgets(
        'un commentaire signalé ne revient pas quand la page est rechargée',
        (tester) async {
      final h = _harness();
      await _openPostPage(tester, h);
      await tapKey(tester, 'comment-report-10');
      await tapKey(tester, 'report-reason-spam');
      // On revient au fil puis on rouvre la page : le dépôt renvoie encore le commentaire.
      await tapKey(tester, 'post-back');
      await tapKey(tester, 'feed-comments-1');
      expect(find.text('Merci pour la réponse'), findsOneWidget);
      expect(find.text('Le riz est disponible ?'), findsNothing);
    });
  });

  group('erreurs', () {
    testWidgets(
        '409 déjà signalé : pas d\'erreur, message « déjà signalé », contenu retiré',
        (tester) async {
      final h = _harness();
      h.reports.error = kAlreadyReported;
      await h.pump(tester);
      await tapKey(tester, 'feed-report-1');
      await tapKey(tester, 'report-reason-spam');
      expect(find.text('Vous avez déjà signalé ce contenu.'), findsOneWidget);
      expect(_sheet, findsNothing);
      expect(find.text('Nouveau lot de riz'), findsNothing);
    });

    testWidgets(
        '400 own_content : message clair dans la feuille, le contenu reste',
        (tester) async {
      final h = _harness();
      h.reports.error = kOwnContent;
      await _openPostPage(tester, h);
      await tapKey(tester, 'comment-report-10');
      await tapKey(tester, 'report-reason-spam');
      expect(_sheet, findsOneWidget);
      expect(find.text('Vous ne pouvez pas signaler votre propre contenu.'),
          findsOneWidget);
      expect(find.byKey(const Key('report-reason-spam')), findsNothing);
      await tapKey(tester, 'report-close');
      expect(_sheet, findsNothing);
      expect(find.text('Le riz est disponible ?'), findsOneWidget);
    });

    testWidgets('404 : le contenu a disparu, il est retiré avec un message',
        (tester) async {
      final h = _harness();
      h.reports.error = kGone;
      await h.pump(tester);
      await tapKey(tester, 'feed-report-2');
      await tapKey(tester, 'report-reason-autre');
      expect(find.text('Ce contenu n\'est plus disponible.'), findsOneWidget);
      expect(find.text('Modèles de boubous'), findsNothing);
      expect(find.text('Nouveau lot de riz'), findsOneWidget);
    });

    testWidgets(
        'réseau : message et Réessayer dans la feuille, le contenu reste ; Réessayer renvoie le même motif',
        (tester) async {
      final h = _harness();
      h.reports.error = kNetworkError;
      await h.pump(tester);
      await tapKey(tester, 'feed-report-1');
      await tapKey(tester, 'report-reason-arnaque');
      expect(_sheet, findsOneWidget);
      expect(
          find.text('Pas de connexion. Votre signalement n\'a pas été envoyé.'),
          findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Nouveau lot de riz'), findsOneWidget);

      h.reports.error = null;
      await tapKey(tester, 'report-retry');
      expect(h.reports.calls.length, 2);
      expect(h.reports.calls.last.reason, ReportReason.arnaque);
      expect(_sheet, findsNothing);
      expect(find.text(_thanks), findsOneWidget);
      expect(find.text('Nouveau lot de riz'), findsNothing);
    });

    testWidgets('autre erreur : message, on peut réessayer', (tester) async {
      final h = _harness();
      h.reports.error =
          const ApiException(ApiErrorCode.unknown, statusCode: 500);
      await h.pump(tester);
      await tapKey(tester, 'feed-report-1');
      await tapKey(tester, 'report-reason-spam');
      expect(find.text('Le signalement n\'a pas pu être envoyé. Réessayez.'),
          findsOneWidget);
      expect(key('report-retry'), findsOneWidget);
      expect(find.text('Nouveau lot de riz'), findsOneWidget);
    });

    testWidgets('double envoi impossible : un seul appel pendant l\'attente',
        (tester) async {
      final h = _harness();
      h.reports.gate = Completer<void>();
      await h.pump(tester);
      await tapKey(tester, 'feed-report-1');
      await tester.tap(key('report-reason-spam'));
      await tester.pump();
      // Pendant l'envoi : les autres motifs et Annuler sont désactivés.
      await tester.tap(key('report-reason-spam'), warnIfMissed: false);
      await tester.tap(key('report-reason-arnaque'), warnIfMissed: false);
      await tester.tap(key('report-cancel'), warnIfMissed: false);
      await tester.pump();
      expect(h.reports.calls.length, 1);
      expect(_sheet, findsOneWidget);
      h.reports.gate!.complete();
      await tester.pumpAndSettle();
      expect(h.reports.calls.length, 1);
      expect(_sheet, findsNothing);
      expect(find.text(_thanks), findsOneWidget);
    });
  });

  group('hors connexion', () {
    testWidgets('boutons ⋯ désactivés, rien n\'est envoyé', (tester) async {
      final h = _harness();
      await _openPostPage(tester, h);
      setOffline(tester, true);
      await tester.pumpAndSettle();
      for (final k in ['post-report', 'comment-report-10']) {
        expect(tester.widget<ReportMenuButton>(key(k)).onPressed, isNull,
            reason: k);
      }
      expect(find.byTooltip('Signaler cette publication, hors connexion'),
          findsOneWidget);
      expect(find.byTooltip('Signaler ce commentaire, hors connexion'),
          findsOneWidget);
      await tester.tap(key('post-report'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(h.reports.calls, isEmpty);
    });

    testWidgets('fil : bouton ⋯ désactivé hors connexion', (tester) async {
      final h = _harness();
      await h.pump(tester);
      setOffline(tester, true);
      await tester.pumpAndSettle();
      expect(tester.widget<ReportMenuButton>(key('feed-report-1')).onPressed,
          isNull);
    });
  });
}
