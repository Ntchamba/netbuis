// T140 : version web (PWA). Aucune fonction native ne doit planter dans le navigateur :
// chaque point d'appel natif a une garde (message clair ou repli silencieux).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/config/env.dart';
import 'package:netbuis/core/utils/local_image.dart';
import 'package:netbuis/features/auth/presentation/widgets/otp_input.dart';
import 'package:netbuis/features/call/application/call_controller.dart';
import 'package:netbuis/features/call/data/call_channel.dart';
import 'package:netbuis/features/call/presentation/widgets/call_button.dart';
import 'package:netbuis/features/call/presentation/widgets/whatsapp_button.dart';
import 'package:netbuis/features/home/data/share_service.dart';

import '../features/call/call_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('canal natif (appel, WhatsApp, composeur, micro)', () {
    test('dans le navigateur : chaque méthode échoue proprement, sans appeler le natif', () async {
      var nativeCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PlatformCallChannel.channel, (call) async {
        nativeCalls++;
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PlatformCallChannel.channel, null));
      const web = PlatformCallChannel(isWeb: true);
      await expectLater(web.microphone(), throwsA(isA<CallChannelException>()));
      await expectLater(web.requestMicrophone(), throwsA(isA<CallChannelException>()));
      await expectLater(web.openWhatsapp(kFakeWaUrl), throwsA(isA<CallChannelException>()));
      await expectLater(web.dial('+237000'), throwsA(isA<CallChannelException>()));
      expect(nativeCalls, 0);
    });

    test('contre-épreuve : hors navigateur, le canal natif est bien appelé', () async {
      var nativeCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PlatformCallChannel.channel, (call) async {
        nativeCalls++;
        return true;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PlatformCallChannel.channel, null));
      expect(await const PlatformCallChannel(isWeb: false).requestMicrophone(), isTrue);
      expect(nativeCalls, 1);
    });
  });

  group('partage', () {
    test('dans le navigateur : exception (l\'écran affiche son message d\'erreur)', () async {
      await expectLater(const PlatformShareService(isWeb: true).shareText('x'),
          throwsA(isA<PlatformException>()));
    });

    test('hors navigateur : la feuille de partage native est appelée', () async {
      String? shared;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PlatformShareService.channel, (call) async {
        shared = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PlatformShareService.channel, null));
      await const PlatformShareService(isWeb: false).shareText('bonjour');
      expect(shared, 'bonjour');
    });
  });

  group('lecture automatique des SMS', () {
    test('dans le navigateur : aucun code, démarrage et arrêt sans erreur', () async {
      final source = SmsAutofillCodeSource(isWeb: true);
      expect(await source.codes.isEmpty, isTrue);
      await source.start();
      await source.stop();
    });
  });

  group('photos choisies', () {
    testWidgets('navigateur : adresse blob lue par le réseau ; téléphone : fichier', (tester) async {
      final web = localImage('blob:http://x/abc', isWeb: true) as Image;
      expect(web.image, isA<NetworkImage>());
      final phone = localImage('/tmp/x.jpg', isWeb: false) as Image;
      expect(phone.image, isA<FileImage>());
    });

    test('lecture des octets d\'un fichier du téléphone ; fichier absent = erreur', () async {
      final dir = await Directory.systemTemp.createTemp('netbuis_img');
      addTearDown(() => dir.delete(recursive: true));
      final f = File('${dir.path}/p.jpg')..writeAsBytesSync([1, 2, 3]);
      expect(await readLocalFileBytes(f.path, isWeb: false), [1, 2, 3]);
      await expectLater(readLocalFileBytes('${dir.path}/absent.jpg', isWeb: false),
          throwsA(isA<FileSystemException>()));
    });
  });

  group('appel et WhatsApp dans la version web', () {
    final channel = FakeCallChannel();
    final repo = FakeCallRepository();

    Future<void> pumpHost(WidgetTester tester, {required bool web, required bool whatsapp}) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [...callOverrides(channel, repo), callIsWebProvider.overrideWithValue(web)],
        child: testApp(Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                key: kOpenCall,
                onPressed: () => whatsapp
                    ? startWhatsapp(context, businessId: 5, businessName: 'Chez Aminatou')
                    : startCall(context, businessId: 5, businessName: 'Chez Aminatou'),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        )),
      ));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.byKey(kOpenCall));
    }

    testWidgets('appel : message clair, ni micro ni session ni salle', (tester) async {
      await pumpHost(tester, web: true, whatsapp: false);
      expect(find.byKey(const Key('call-web-unavailable')), findsOneWidget);
      expect(
          find.text(
              'L\'appel n\'est pas disponible dans la version web, utilisez l\'application Android.'),
          findsOneWidget);
      expect(repo.requests, isEmpty);
      expect(channel.requestCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('appel : contre-épreuve, hors web le message n\'apparaît pas', (tester) async {
      await pumpHost(tester, web: false, whatsapp: false);
      expect(find.byKey(const Key('call-web-unavailable')), findsNothing);
      expect(repo.requests, isNotEmpty);
    });

    testWidgets('WhatsApp : message clair, aucun appel au serveur ni au natif', (tester) async {
      await pumpHost(tester, web: true, whatsapp: true);
      expect(find.byKey(const Key('whatsapp-web-unavailable')), findsOneWidget);
      expect(
          find.text(
              'WhatsApp depuis NetBuis n\'est pas disponible dans la version web, utilisez l\'application Android.'),
          findsOneWidget);
      expect(repo.whatsappRequests, isEmpty);
      expect(channel.whatsappOpened, isEmpty);
      await tapAndSettle(tester, find.byKey(const Key('whatsapp-close')));
      expect(find.byKey(const Key('whatsapp-web-unavailable')), findsNothing);
    });
  });

  group('adresse de l\'API en version web', () {
    test('une version web de production (kReleaseMode) refuse http', () {
      expect(() => ensureSecureApiUrl('http://serveur.example/api', release: true),
          throwsA(isA<StateError>()));
      expect(ensureSecureApiUrl('https://serveur.example/api', release: true),
          'https://serveur.example/api');
    });
  });
}
