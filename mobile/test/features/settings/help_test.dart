import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/config/feature_flags.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/call/data/call_channel.dart';
import 'package:netbuis/features/settings/application/help_providers.dart';
import 'package:netbuis/features/settings/application/settings_controller.dart';
import 'package:netbuis/features/settings/data/settings_store.dart';
import 'package:netbuis/features/settings/presentation/screens/help_screen.dart';

import '../call/call_test_helpers.dart';
import 'settings_test_helpers.dart';

const _d07 =
    "Dans NetBuis, l'appel se fait dans l'application, avec l'équipe NetBuis. Aucun numéro n'est échangé avec le commerçant. Seul WhatsApp ouvre une conversation avec le numéro du commerce.";

// Valeurs d'essai : ce ne sont pas de vrais contacts.
const _fakeSupport = SupportContact(
  whatsapp: '+237 0000 0000',
  phone: '+23700000001',
  email: 'aide@exemple.invalid',
);

Future<void> _pumpHelp(
  WidgetTester tester, {
  bool credits = false,
  bool team = false,
  SupportContact contact = const SupportContact(),
  FakeCallChannel? channel,
  FakeSpeechOutput? speech,
  MemorySettingsStore? store,
  Future<bool> Function(Uri)? mail,
  bool signedIn = true,
}) =>
    pumpSettingsApp(
      tester,
      store: store ?? MemorySettingsStore(),
      speech: speech,
      initialLocation: Routes.help,
      signedIn: signedIn,
      overrides: [
        creditsEnabledProvider.overrideWithValue(credits),
        teamEnabledProvider.overrideWithValue(team),
        supportContactProvider.overrideWithValue(contact),
        callChannelProvider.overrideWithValue(channel ?? FakeCallChannel()),
        if (mail != null) mailLauncherProvider.overrideWithValue(mail),
      ],
    );

Finder _faq(String id) => find.byKey(ValueKey('faq-$id'));
Finder _answer(String id) => find.byKey(ValueKey('faq-answer-$id'));

Future<void> _open(WidgetTester tester, String id) async {
  await tester.ensureVisible(find.byKey(ValueKey('faq-toggle-$id')));
  await tester.tap(find.byKey(ValueKey('faq-toggle-$id')));
  await tester.pumpAndSettle();
}

void main() {
  group('FAQ', () {
    testWidgets('crédits désactivés : trois thèmes, aucune question de crédits', (tester) async {
      await _pumpHelp(tester);
      expect(find.text('Aide & support'), findsOneWidget);
      expect(find.byKey(const ValueKey('help-theme-calls')), findsOneWidget);
      expect(find.byKey(const ValueKey('help-theme-business')), findsOneWidget);
      expect(find.byKey(const ValueKey('help-theme-security')), findsOneWidget);
      expect(_faq('free_call'), findsNothing);
      expect(_faq('credit_pack'), findsNothing);
      expect(find.textContaining('crédit'), findsNothing);
      expect(find.textContaining('abonnement'), findsNothing);
      expect(_faq('hidden_number'), findsOneWidget);
    });

    testWidgets('crédits activés : les questions de crédits apparaissent', (tester) async {
      await _pumpHelp(tester, credits: true);
      expect(_faq('free_call'), findsOneWidget);
      expect(_faq('credit_pack'), findsOneWidget);
      expect(find.text('📞 APPELS & CRÉDITS'), findsOneWidget);
      // La première question est ouverte au départ (maquette).
      expect(_answer('free_call'), findsOneWidget);
    });

    testWidgets('une seule question ouverte à la fois', (tester) async {
      await _pumpHelp(tester, credits: true);
      expect(_answer('free_call'), findsOneWidget);
      await _open(tester, 'credit_pack');
      expect(_answer('credit_pack'), findsOneWidget);
      expect(_answer('free_call'), findsNothing);
      await _open(tester, 'pending');
      expect(_answer('pending'), findsOneWidget);
      expect(_answer('credit_pack'), findsNothing);
      // Un second appui referme.
      await _open(tester, 'pending');
      expect(_answer('pending'), findsNothing);
    });

    testWidgets('« pourquoi le numéro n\'est pas visible » : texte exact de D-07', (tester) async {
      await _pumpHelp(tester);
      // Sans crédits, c'est la première question : déjà ouverte.
      expect(tester.widget<Text>(_answer('hidden_number')).data, _d07);
    });

    testWidgets('les 5 types de compte business sont cités', (tester) async {
      await _pumpHelp(tester);
      await _open(tester, 'create_business');
      final text = tester.widget<Text>(_answer('create_business')).data!;
      for (final type in ['Commerce', 'Entreprise', 'Structure', 'Particulier vendeur', 'Prestataire de service']) {
        expect(text, contains(type));
      }
    });

    testWidgets('équipe désactivée : seulement la sécurité', (tester) async {
      await _pumpHelp(tester);
      expect(find.text('🛡️ SÉCURITÉ'), findsOneWidget);
      expect(_faq('join_team'), findsNothing);
      expect(_faq('sponsorship'), findsNothing);
      expect(find.textContaining('parrain'), findsNothing);
      expect(_faq('report_suspect'), findsOneWidget);
    });

    testWidgets('équipe activée : parrainage présent', (tester) async {
      await _pumpHelp(tester, team: true);
      expect(find.text('🤝 PARRAINAGE & SÉCURITÉ'), findsOneWidget);
      expect(_faq('join_team'), findsOneWidget);
      expect(_faq('sponsorship'), findsOneWidget);
      expect(_faq('report_suspect'), findsOneWidget);
    });

    testWidgets('la recherche filtre les questions', (tester) async {
      await _pumpHelp(tester);
      await tester.enterText(find.byKey(const ValueKey('help-search')), 'suspect');
      await tester.pumpAndSettle();
      expect(_faq('report_suspect'), findsOneWidget);
      expect(_faq('hidden_number'), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('help-search')), 'zzzzqq');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('help-search-empty')), findsOneWidget);
    });

    testWidgets('liens Conditions et Confidentialité', (tester) async {
      await _pumpHelp(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('legal-link-terms')));
      await tester.tap(find.byKey(const ValueKey('legal-link-terms')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('legal-body')), findsOneWidget);
    });

    testWidgets('en anglais : textes traduits', (tester) async {
      await _pumpHelp(tester, store: MemorySettingsStore(stored: const AppSettings(language: 'en')));
      expect(find.text('Help & support'), findsOneWidget);
      expect(find.text('Why can\'t I see the merchant\'s number?'), findsOneWidget);
    });

    testWidgets('route protégée : sans connexion on n\'arrive pas sur l\'aide', (tester) async {
      await _pumpHelp(tester, signedIn: false);
      expect(find.byKey(const ValueKey('help-search')), findsNothing);
    });
  });

  group('Écouter', () {
    const listen = ValueKey('listen-button');

    testWidgets('lit la réponse affichée, dans la langue de l\'application', (tester) async {
      final speech = FakeSpeechOutput();
      await _pumpHelp(tester, speech: speech);
      expect(find.byKey(listen), findsOneWidget);
      await tester.tap(find.byKey(listen));
      await tester.pumpAndSettle();
      expect(speech.spoken, [_d07]);
      expect(speech.tags, ['fr-FR']);
    });

    testWidgets('chaque réponse ouverte a son bouton ; refermer arrête la lecture', (tester) async {
      final speech = FakeSpeechOutput();
      await _pumpHelp(tester, speech: speech);
      await tester.tap(find.byKey(listen));
      await tester.pumpAndSettle();
      expect(speech.speaking.value, isTrue);
      await _open(tester, 'pending');
      expect(speech.speaking.value, isFalse);
      expect(find.byKey(listen), findsOneWidget);
      await tester.tap(find.byKey(listen));
      await tester.pumpAndSettle();
      expect(speech.spoken.last, tester.widget<Text>(_answer('pending')).data);
    });

    testWidgets('masqué sans aucune voix', (tester) async {
      await _pumpHelp(tester, speech: FakeSpeechOutput(french: false, english: false));
      expect(find.byKey(listen), findsNothing);
    });

    testWidgets('voix française seule : visible en français, masqué en anglais', (tester) async {
      final speech = FakeSpeechOutput(english: false);
      await _pumpHelp(tester, speech: speech);
      expect(find.byKey(listen), findsOneWidget);
      final container = ProviderScope.containerOf(tester.element(find.byType(HelpScreen)));
      container.read(settingsControllerProvider.notifier).setLanguage('en');
      await tester.pumpAndSettle();
      expect(find.text('Help & support'), findsOneWidget);
      expect(find.byKey(listen), findsNothing);
      container.read(settingsControllerProvider.notifier).setLanguage('fr');
      await tester.pumpAndSettle();
      expect(find.byKey(listen), findsOneWidget);
    });

    testWidgets('voix anglaise seule : masqué en français, visible en anglais', (tester) async {
      final speech = FakeSpeechOutput(french: false);
      await _pumpHelp(tester, speech: speech);
      expect(find.byKey(listen), findsNothing);
      final container = ProviderScope.containerOf(tester.element(find.byType(HelpScreen)));
      container.read(settingsControllerProvider.notifier).setLanguage('en');
      await tester.pumpAndSettle();
      expect(find.byKey(listen), findsOneWidget);
      await tester.tap(find.byKey(listen));
      await tester.pumpAndSettle();
      expect(speech.tags, ['en-US']);
    });

    testWidgets('une voix installée pendant l\'usage apparaît à la reprise', (tester) async {
      final speech = FakeSpeechOutput(french: false);
      await _pumpHelp(tester, speech: speech);
      expect(find.byKey(listen), findsNothing);

      speech.french = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byKey(listen), findsOneWidget);
    });

    testWidgets('sans reprise de l\'application, pas de nouvelle détection', (tester) async {
      final speech = FakeSpeechOutput(french: false);
      await _pumpHelp(tester, speech: speech);
      final before = speech.detections;
      speech.french = true;
      await tester.pumpAndSettle();
      expect(speech.detections, before);
      expect(find.byKey(listen), findsNothing);
    });
  });

  group('Contacts du support (D-06)', () {
    Future<void> showContacts(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const ValueKey('contact-email')));
      await tester.pump();
    }

    testWidgets('valeurs À REMPLACER : tout est désactivé, rien ne s\'ouvre', (tester) async {
      final channel = FakeCallChannel();
      var mails = 0;
      await _pumpHelp(tester, channel: channel, mail: (_) async {
        mails++;
        return true;
      });
      await showContacts(tester);
      expect(find.text('Coordonnées du support à venir'), findsWidgets);
      for (final key in ['contact-whatsapp', 'contact-phone', 'contact-email', 'help-report']) {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.tap(find.byKey(ValueKey(key)), warnIfMissed: false);
        await tester.pumpAndSettle();
      }
      expect(channel.whatsappOpened, isEmpty);
      expect(channel.dialed, isEmpty);
      expect(mails, 0);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('help-report'))),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
    });

    testWidgets('valeurs invalides : désactivé aussi', (tester) async {
      final channel = FakeCallChannel();
      await _pumpHelp(
        tester,
        channel: channel,
        contact: const SupportContact(whatsapp: 'abc', phone: '12', email: 'pas-un-email'),
      );
      await showContacts(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('help-report')));
      await tester.tap(find.byKey(const ValueKey('help-report')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(channel.whatsappOpened, isEmpty);
      expect(find.byKey(const ValueKey('help-contact-soon')), findsOneWidget);
    });

    testWidgets('coordonnées valides : WhatsApp, appel et e-mail s\'ouvrent', (tester) async {
      final channel = FakeCallChannel();
      final mails = <Uri>[];
      await _pumpHelp(tester, channel: channel, contact: _fakeSupport, mail: (u) async {
        mails.add(u);
        return true;
      });
      await showContacts(tester);
      expect(find.byKey(const ValueKey('help-contact-soon')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('contact-whatsapp')));
      await tester.pumpAndSettle();
      expect(channel.whatsappOpened, ['https://wa.me/23700000000']);

      await tester.tap(find.byKey(const ValueKey('contact-phone')));
      await tester.pumpAndSettle();
      expect(channel.dialed, ['+23700000001']);

      await tester.tap(find.byKey(const ValueKey('contact-email')));
      await tester.pumpAndSettle();
      expect(mails.single.toString(), 'mailto:aide@exemple.invalid');
    });

    testWidgets('signaler : WhatsApp du support avec message pré-rempli', (tester) async {
      final channel = FakeCallChannel();
      await _pumpHelp(tester, channel: channel, contact: _fakeSupport);
      await tester.ensureVisible(find.byKey(const ValueKey('help-report')));
      await tester.tap(find.byKey(const ValueKey('help-report')));
      await tester.pumpAndSettle();
      final url = Uri.parse(channel.whatsappOpened.single);
      expect(url.scheme, 'https');
      expect(url.host, 'wa.me');
      expect(url.path, '/23700000000');
      expect(url.queryParameters['text'],
          'Bonjour NetBuis, je souhaite signaler un problème ou un compte suspect.');
    });

    testWidgets('WhatsApp absent ou en échec : message simple, pas d\'erreur', (tester) async {
      final channel = FakeCallChannel()..whatsappResult = WhatsappOpenResult.notInstalled;
      await _pumpHelp(tester, channel: channel, contact: _fakeSupport);
      await tester.ensureVisible(find.byKey(const ValueKey('help-report')));
      await tester.tap(find.byKey(const ValueKey('help-report')));
      await tester.pumpAndSettle();
      expect(find.text("WhatsApp n'est pas installé sur ce téléphone."), findsOneWidget);

      channel
        ..whatsappResult = WhatsappOpenResult.opened
        ..throwOnWhatsapp = true;
      await tester.tap(find.byKey(const ValueKey('help-report')));
      await tester.pumpAndSettle();
      expect(find.text('Impossible d\'ouvrir WhatsApp pour le moment.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SupportContact', () {
    test('valeur par défaut : rien de valide', () {
      const c = SupportContact(whatsapp: 'À REMPLACER', phone: 'À REMPLACER', email: 'À REMPLACER');
      expect(c.whatsappDigits, isNull);
      expect(c.phoneNumber, isNull);
      expect(c.emailAddress, isNull);
      expect(c.whatsappLink(), isNull);
      expect(c.anyAvailable, isFalse);
    });

    test('valeurs plausibles acceptées, lien construit', () {
      expect(_fakeSupport.whatsappLink(message: 'a b'), 'https://wa.me/23700000000?text=a%20b');
      expect(_fakeSupport.phoneNumber, '+23700000001');
      expect(_fakeSupport.emailAddress, 'aide@exemple.invalid');
    });

    test('trop court ou trop long refusé', () {
      expect(const SupportContact(whatsapp: '1234567').whatsappDigits, isNull);
      expect(const SupportContact(whatsapp: '1234567890123456').whatsappDigits, isNull);
    });
  });

  test('visibleFaqItems : drapeaux', () {
    final none = visibleFaqItems(credits: false, team: false).map((i) => i.id);
    expect(none, ['hidden_number', 'create_business', 'pending', 'product_limit', 'report_suspect']);
    expect(visibleFaqItems(credits: true, team: true), hasLength(allFaqItems.length));
  });
}
