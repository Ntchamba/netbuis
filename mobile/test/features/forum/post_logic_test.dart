import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/features/business/application/business_services.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/features/forum/application/forum_services.dart';
import 'package:netbuis/core/l10n/l10n.dart';
import 'package:netbuis/features/forum/application/post_publisher.dart';
import 'package:netbuis/features/forum/application/post_time.dart';
import 'package:netbuis/features/forum/data/models/post.dart';
import 'package:netbuis/features/forum/data/post_media.dart';
import 'package:netbuis/features/forum/data/repositories/forum_repository.dart';

import '../business/business_submit_helpers.dart';
import 'post_test_helpers.dart';

ProviderContainer _container(PostsHarness h, Map<String, Uint8List> files) =>
    ProviderContainer(overrides: [
      forumRepositoryProvider.overrideWithValue(h.forum),
      businessRepositoryProvider.overrideWithValue(h.business),
      photoBytesReaderProvider.overrideWithValue((path) async => files[path]!),
    ]);

void main() {
  group('detectPostMedia / checkPostMedia (d\'après les octets)', () {
    test('JPEG, PNG, WebP -> post_image', () {
      for (final bytes in [fakeJpeg(40), fakePng(40), fakeWebp(40)]) {
        final info = detectPostMedia(bytes)!;
        expect(info.type, PostMediaType.image);
        expect(info.signKind, 'post_image');
      }
    });

    test('MP4 -> post_video / video/mp4', () {
      final info = detectPostMedia(fakeMp4(64))!;
      expect(info.type, PostMediaType.video);
      expect(info.signKind, 'post_video');
      expect(info.contentType, 'video/mp4');
    });

    test('GIF, texte, fichier vide : refusés', () {
      expect(detectPostMedia(fakeGif(40)), isNull);
      expect(detectPostMedia(Uint8List.fromList('<html>'.codeUnits)), isNull);
      expect(() => checkPostMedia(Uint8List(0)), throwsA(isA<PostMediaException>()));
    });

    test('tailles : 5 Mo image, 30 Mo vidéo', () {
      expect(checkPostMedia(fakeJpeg(5 * 1024 * 1024)).type, PostMediaType.image);
      expect(
          () => checkPostMedia(fakeJpeg(5 * 1024 * 1024 + 1)),
          throwsA(isA<PostMediaException>().having((e) => e.tooLarge, 'tooLarge', isTrue)));
      expect(checkPostMedia(fakeMp4(30 * 1024 * 1024)).type, PostMediaType.video);
      expect(() => checkPostMedia(fakeMp4(30 * 1024 * 1024 + 1)),
          throwsA(isA<PostMediaException>()));
    });
  });

  group('MyPost.fromJson', () {
    test('réponse du contrat', () {
      final p = MyPost.fromJson({
        'id': 4,
        'media_type': 'video',
        'media_url': '/media/x.mp4',
        'caption': 'Salut',
        'offer': {'id': 9, 'name': 'Riz'},
        'created_at': '2026-03-04T10:00:00Z',
        'comments_count': 3,
        'status': 'masque',
      });
      expect(p.id, 4);
      expect(p.mediaType, PostMediaType.video);
      expect(p.offerId, 9);
      expect(p.offerName, 'Riz');
      expect(p.commentsCount, 3);
      expect(p.isHidden, isTrue);
    });

    test('réponse sans statut = active ; réponse incomplète refusée', () {
      final p = MyPost.fromJson(
          {'id': 1, 'caption': '', 'created_at': '2026-03-04T10:00:00Z', 'media_type': 'image'});
      expect(p.status, PostStatus.active);
      expect(() => MyPost.fromJson({'id': 1}), throwsFormatException);
      expect(() => MyPost.fromJson('x'), throwsFormatException);
    });
  });

  group('PostPublisher', () {
    test('un fichier GIF est refusé sans rien envoyer', () async {
      final h = PostsHarness();
      final container = _container(h, {'/g.jpg': fakeGif(100)});
      addTearDown(container.dispose);
      await expectLater(
          container.read(postPublisherProvider).publish(path: '/g.jpg', caption: 'x'),
          throwsA(isA<PostMediaException>()));
      expect(h.business.signedKinds, isEmpty);
      expect(h.forum.created, isEmpty);
    });

    test('une légende de 501 caractères est refusée sans rien envoyer', () async {
      final h = PostsHarness();
      final container = _container(h, {'/p.jpg': fakeJpeg(100)});
      addTearDown(container.dispose);
      await expectLater(
          container
              .read(postPublisherProvider)
              .publish(path: '/p.jpg', caption: 'a' * (kMaxCaptionLength + 1)),
          throwsA(isA<CaptionTooLongException>()));
      expect(h.business.signedKinds, isEmpty);
    });

    test('postErrorKey : un code du serveur inconnu donne le message générique', () {
      expect(postErrorKey(kCapError), 'posts.error.cap');
      expect(postErrorKey(kDailyError), 'posts.error.daily');
      expect(postErrorKey(kNetworkError), 'posts.error.network');
      expect(postErrorKey(StateError('x')), 'posts.error.unknown');
    });
  });

  group('postAgo', () {
    final l10n = L10n(const Locale('fr'), {
      'posts.ago.now': 'À l\'instant',
      'posts.ago.minutes': 'Il y a {n} min',
      'posts.ago.hours': 'Il y a {n}h',
      'posts.ago.day.one': 'Il y a {n} jour',
      'posts.ago.day.other': 'Il y a {n} jours',
      'posts.ago.week.one': 'Il y a {n} semaine',
      'posts.ago.week.other': 'Il y a {n} semaines',
    });
    final now = DateTime(2026, 5, 20, 12);
    String ago(Duration d) => postAgo(l10n, now.subtract(d), now);

    test('minutes, heures, jours, semaines, date', () {
      expect(ago(const Duration(seconds: 20)), 'À l\'instant');
      expect(ago(const Duration(minutes: 7)), 'Il y a 7 min');
      expect(ago(const Duration(hours: 2)), 'Il y a 2h');
      expect(ago(const Duration(days: 1)), 'Il y a 1 jour');
      expect(ago(const Duration(days: 3)), 'Il y a 3 jours');
      expect(ago(const Duration(days: 7)), 'Il y a 1 semaine');
      expect(ago(const Duration(days: 15)), 'Il y a 2 semaines');
      expect(ago(const Duration(days: 40)), '10/04/2026');
    });
  });
}
