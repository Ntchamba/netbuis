// T121 (revue de sécurité, partie mobile) : contrôles exécutables, pas des déclarations.
// Chaque garde est accompagnée d'une contre-épreuve (le détecteur trouve bien ce qu'il doit trouver).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/config/env.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/network/dio_client.dart';
import 'package:netbuis/core/network/upload_url.dart';
import 'package:netbuis/features/auth/data/models/auth_tokens.dart';
import 'package:netbuis/features/call/data/models/call_session.dart';

/// Texte d'un fichier source sans les commentaires `//` (et `///`).
String _code(File f) => f
    .readAsLinesSync()
    .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
    .join('\n');

List<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

String _rel(File f) => f.path.replaceAll('\\', '/');

/// Fichiers de `lib/` dont le code (hors commentaires) contient [pattern].
List<String> _libMatches(RegExp pattern) => [
      for (final f in _dartFiles('lib'))
        if (pattern.hasMatch(_code(f))) _rel(f),
    ]..sort();

String _manifest(String path) => File(path).readAsStringSync();

Set<String> _permissions(String xml, {required bool removed}) => {
      for (final m in RegExp(r'<uses-permission\s+([^>]*?)/?>').allMatches(xml))
        if (m.group(1)!.contains('tools:node="remove"') == removed)
          RegExp(r'android:name="([^"]+)"').firstMatch(m.group(1)!)!.group(1)!,
    };

void main() {
  group('HTTPS obligatoire en release', () {
    test('release : http refusé, https accepté', () {
      expect(() => ensureSecureApiUrl('http://api.exemple.test/api', release: true),
          throwsStateError);
      expect(() => ensureSecureApiUrl('http://10.0.2.2:8000/api', release: true),
          throwsStateError);
      expect(ensureSecureApiUrl('https://api.exemple.test/api', release: true),
          'https://api.exemple.test/api');
    });

    test('débogage : http permis (émulateur)', () {
      expect(ensureSecureApiUrl('http://10.0.2.2:8000/api', release: false),
          'http://10.0.2.2:8000/api');
    });

    test('adresses absurdes ou avec identifiants : refusées dans les deux modes', () {
      for (final bad in [
        '',
        'api.exemple.test/api',
        'ftp://api.exemple.test/api',
        'https:///api',
        'https://utilisateur:motdepasse@api.exemple.test/api',
        'javascript:alert(1)',
      ]) {
        for (final release in [true, false]) {
          expect(() => ensureSecureApiUrl(bad, release: release), throwsStateError,
              reason: '$bad / release=$release');
        }
      }
    });

    test('le message d\'erreur ne cite pas l\'adresse', () {
      try {
        ensureSecureApiUrl('http://secret.exemple.test/api', release: true);
        fail('doit échouer');
      } on StateError catch (e) {
        expect(e.message.contains('secret.exemple'), isFalse);
      }
    });

    test('le client HTTP est construit avec cette vérification', () {
      expect(
          () => buildDio(baseUrl: 'ftp://x.test/api', readAccessToken: () async => null),
          throwsStateError);
      expect(
          buildDio(baseUrl: 'https://x.test/api', readAccessToken: () async => null)
              .options
              .baseUrl,
          'https://x.test/api');
    });

    test('adresses d\'envoi : http refusé en release, permis en débogage', () {
      const api = 'https://api.exemple.test/api';
      expect(() => resolveUploadUrl(api, 'http://cdn.test/f', release: true),
          throwsA(isA<ApiException>()));
      expect(() => resolveUploadUrl(api, 'HTTP://cdn.test/f', release: true),
          throwsA(isA<ApiException>()));
      expect(resolveUploadUrl(api, 'https://cdn.test/f', release: true),
          'https://cdn.test/f');
      expect(resolveUploadUrl(api, '/api/uploads/local/x/', release: true),
          'https://api.exemple.test/api/uploads/local/x/');
      expect(resolveUploadUrl(api, 'http://cdn.test/f', release: false),
          'http://cdn.test/f');
    });

    test('aucune adresse https/http en dur dans lib/ hors liens publics connus', () {
      final allowed = RegExp(r'^(https?://(wa\.me|127\.0\.0\.1|localhost|10\.0\.2\.2|www\.openstreetmap\.org|tile\.openstreetmap\.org))');
      final found = <String>[];
      for (final f in _dartFiles('lib')) {
        for (final m in RegExp('["\'](https?://[^"\'\$ ]+)').allMatches(_code(f))) {
          final url = m.group(1)!;
          if (!allowed.hasMatch(url)) found.add('${_rel(f)}: $url');
        }
      }
      expect(found, isEmpty);
    });
  });

  group('Manifeste Android', () {
    final main = _manifest('android/app/src/main/AndroidManifest.xml');
    final debug = _manifest('android/app/src/debug/AndroidManifest.xml');
    final profile = _manifest('android/app/src/profile/AndroidManifest.xml');
    final release = _manifest('android/app/src/release/AndroidManifest.xml');

    test('aucune sauvegarde automatique des jetons et préférences', () {
      expect(main, contains('android:allowBackup="false"'));
      expect(main, contains('android:fullBackupContent="@xml/backup_rules"'));
      expect(main, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
      for (final f in ['backup_rules', 'data_extraction_rules']) {
        final xml = File('android/app/src/main/res/xml/$f.xml').readAsStringSync();
        expect(xml, contains('domain="sharedpref"'), reason: f);
        expect(xml, contains('domain="file"'), reason: f);
        expect(xml, isNot(contains('<include')), reason: f);
      }
      final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml')
          .readAsStringSync();
      expect(rules, contains('<cloud-backup>'));
      expect(rules, contains('<device-transfer>'));
    });

    test('trafic en clair interdit en release, permis seulement en débogage', () {
      expect(main, contains('android:usesCleartextTraffic="false"'));
      expect(main, contains('android:networkSecurityConfig="@xml/network_security_config"'));
      final release =
          File('android/app/src/main/res/xml/network_security_config.xml').readAsStringSync();
      expect(release, contains('cleartextTrafficPermitted="false"'));
      expect(release, isNot(contains('cleartextTrafficPermitted="true"')));
      expect(release, isNot(contains('<domain')));
      expect(release, isNot(contains('user')), reason: 'pas de certificats utilisateur');
      expect(debug, contains('android:usesCleartextTraffic="true"'));
      expect(
          File('android/app/src/debug/res/xml/network_security_config.xml')
              .readAsStringSync(),
          contains('cleartextTrafficPermitted="true"'));
      // Le profil (mesures) utilise le manifeste principal : pas de clair.
      expect(profile, isNot(contains('usesCleartextTraffic')));
    });

    test('permissions du manifeste principal : micro et internet seulement', () {
      expect(_permissions(main, removed: false),
          {'android.permission.RECORD_AUDIO', 'android.permission.INTERNET'});
    });

    test('permissions injectées par un paquet et inutiles : retirées', () {
      // Dans release, profile et debug (pas dans main : call_data_test y interdit ces noms).
      for (final xml in [release, profile, debug]) {
        expect(_permissions(xml, removed: true), {
          'android.permission.CAMERA',
          'android.permission.READ_PHONE_STATE',
          'android.permission.READ_PHONE_NUMBERS',
          'android.permission.CALL_PHONE',
          'android.permission.ACCESS_FINE_LOCATION',
          'android.permission.ACCESS_COARSE_LOCATION',
        });
        expect(xml, contains('xmlns:tools='));
      }
      expect(_permissions(release, removed: false), isEmpty);
    });

    test('un seul composant exporté : l\'activité de lancement', () {
      final exported = RegExp('android:exported="true"').allMatches(main).length;
      expect(exported, 1);
      expect(main, isNot(contains('<service')));
      expect(main, isNot(contains('<receiver')));
      expect(main, isNot(contains('<provider')));
      // L'activité exportée est bien celle qui porte l'intention de lancement.
      final activity = RegExp(r'<activity.*?</activity>', dotAll: true).firstMatch(main)!.group(0)!;
      expect(activity, contains('android:exported="true"'));
      expect(activity, contains('android.intent.category.LAUNCHER'));
    });

    test('le détecteur de permissions n\'est pas aveugle', () {
      const sample = '<uses-permission android:name="android.permission.CAMERA"/>'
          '<uses-permission android:name="x.Y" tools:node="remove"/>';
      expect(_permissions(sample, removed: false), {'android.permission.CAMERA'});
      expect(_permissions(sample, removed: true), {'x.Y'});
    });

    test('pas de WebView déclarée par l\'application, ni de paquet WebView', () {
      expect(main.toLowerCase(), isNot(contains('webview')));
      final pubspec = File('pubspec.yaml').readAsStringSync().toLowerCase();
      for (final p in ['webview', 'flutter_inappwebview', 'cached_network_image']) {
        expect(pubspec, isNot(contains(p)), reason: p);
      }
      expect(_libMatches(RegExp(r'WebView', caseSensitive: false)), isEmpty);
    });
  });

  group('Secrets et stockage', () {
    test('aucun secret ni clé de service dans mobile/', () {
      final forbidden = RegExp(
          r'BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{12}|(sk|pk|rk)_(live|test)_|AIza[0-9A-Za-z_-]{20}|xox[bp]-|gh[pos]_[A-Za-z0-9]{20}|eyJ[A-Za-z0-9_-]{10,}\.');
      final hits = <String>[];
      for (final root in ['lib', 'android', 'assets', 'integration_test', 'test']) {
        final dir = Directory(root);
        if (!dir.existsSync()) continue;
        for (final f in dir.listSync(recursive: true).whereType<File>()) {
          final p = _rel(f);
          if (p.contains('/build/') || p.contains('/.gradle/') || p.endsWith('.png')) continue;
          if (p == 'test/core/security_test.dart') continue;
          String text;
          try {
            text = f.readAsStringSync();
          } on Object {
            continue; // fichier binaire
          }
          if (forbidden.hasMatch(text)) hits.add(p);
        }
      }
      expect(hits, isEmpty);
    });

    test('pas de fichier de clés ni de configuration de service suivi', () {
      final bad = [
        for (final f in Directory('.').listSync(recursive: true).whereType<File>())
          if (!_rel(f).contains('/build/') &&
              !_rel(f).contains('/.dart_tool/') &&
              !_rel(f).contains('/.gradle/') &&
              RegExp(r'(google-services\.json|GoogleService-Info\.plist|\.jks$|\.keystore$|key\.properties$|\.pem$|\.p12$|/\.env)')
                  .hasMatch(_rel(f)))
            _rel(f),
      ];
      expect(bad, isEmpty);
    });

    test('les jetons ne sont écrits que dans flutter_secure_storage', () {
      // Seul secure_storage.dart connaît les clés des jetons et flutter_secure_storage.
      expect(_libMatches(RegExp(r'flutter_secure_storage')), ['lib/core/storage/secure_storage.dart']);
      expect(_libMatches(RegExp(r'netbuis_(access|refresh)')), ['lib/core/storage/secure_storage.dart']);
      // shared_preferences : seulement ces 4 fichiers, aucune clé sensible.
      expect(_libMatches(RegExp(r'shared_preferences')), [
        'lib/core/storage/prefs.dart',
        'lib/features/forum/data/forum_feed_cache.dart',
        'lib/features/search/data/search_cache.dart',
        'lib/features/settings/data/settings_store.dart',
      ], reason: 'nouveau fichier qui écrit dans les préférences : à relire');
      final keys = <String>[];
      for (final f in [
        'lib/core/storage/prefs.dart',
        'lib/features/forum/data/forum_feed_cache.dart',
        'lib/features/search/data/search_cache.dart',
        'lib/features/settings/data/settings_store.dart',
      ]) {
        keys.addAll(RegExp(r"static const \w*[kK]ey = '([^']+)'")
            .allMatches(_code(File(f)))
            .map((m) => m.group(1)!));
      }
      expect(keys.length, 7);
      for (final k in keys) {
        expect(k, isNot(matches(RegExp(r'token|jwt|room|salle|phone|numero|whatsapp|wa_|password|refresh|access', caseSensitive: false))), reason: k);
      }
    });

    test('aucun fichier écrit sur le disque par l\'application, ni cache d\'images disque', () {
      expect(
          _libMatches(RegExp(
              r'writeAsBytes|writeAsString|openWrite|getTemporaryDirectory|getApplicationDocumentsDirectory|getApplicationSupportDirectory|path_provider|cached_network_image|flutter_cache_manager')),
          isEmpty,
          reason: 'écrire un fichier sur le disque doit être décidé et relu');
      // Les images du réseau passent par Image.network : cache en mémoire seulement.
      expect(File('pubspec.lock').readAsStringSync(), isNot(contains('flutter_cache_manager')));
    });

    test('la salle Jitsi, le jeton Jitsi et le lien WhatsApp ne sont jamais écrits', () {
      // Aucun fichier qui touche aux préférences ne parle de Jitsi, de wa.me ou de la salle.
      for (final f in [
        'lib/core/storage/prefs.dart',
        'lib/core/storage/secure_storage.dart',
        'lib/features/forum/data/forum_feed_cache.dart',
        'lib/features/search/data/search_cache.dart',
        'lib/features/settings/data/settings_store.dart',
      ]) {
        expect(_code(File(f)), isNot(matches(RegExp(r'jitsi|JitsiAccess|WhatsappLink|wa\.me|\.room\b|\.jwt\b', caseSensitive: false))), reason: f);
      }
    });
  });

  group('Numéros et journaux', () {
    test('le numéro d\'un commerçant n\'est lu nulle part dans lib/', () {
      expect(_libMatches(RegExp(r'phone_anchor|phoneAnchor|anchor_phone')), isEmpty);
      // Seules deux lectures de « phone » dans des réponses : le masqué du profil ; le numéro
      // saisi par la personne elle-même part dans le corps de la demande de code.
      final reads = <String>[];
      for (final f in _dartFiles('lib')) {
        if (RegExp(r"json\[\s*'phone'\s*\]|data\[\s*'phone'\s*\]|\['phone'\]").hasMatch(_code(f))) {
          reads.add(_rel(f));
        }
      }
      expect(reads, isEmpty);
    });

    test('le détecteur de lecture du numéro n\'est pas aveugle', () {
      expect(RegExp(r'phone_anchor|phoneAnchor').hasMatch("json['phone_anchor']"), isTrue);
      expect(RegExp(r"json\[\s*'phone'\s*\]").hasMatch("final p = json['phone'];"), isTrue);
    });

    test('aucune journalisation dans lib/ (print, debugPrint, log, stdout, FlutterError)', () {
      final hits = _libMatches(RegExp(
          r'(?<![A-Za-z0-9_.])(print|debugPrint|debugPrintStack|log)\s*\(|developer\.log|\bstdout\b|\bstderr\b|dart:developer|debugPrintSynchronously|LogInterceptor'));
      expect(hits, isEmpty);
    });

    test('le détecteur de journalisation n\'est pas aveugle', () {
      final re = RegExp(
          r'(?<![A-Za-z0-9_.])(print|debugPrint|debugPrintStack|log)\s*\(|developer\.log');
      expect(re.hasMatch("  debugPrint('x');"), isTrue);
      expect(re.hasMatch("print(token);"), isTrue);
      expect(re.hasMatch("showDialog(builder: (c) => AlertDialog(title: x))"), isFalse);
    });

    test('toString des objets sensibles ne montre ni jeton, ni salle, ni lien', () {
      const secret = 'SECRET-A1B2C3';
      final access = JitsiAccess(domain: 'jitsi.exemple.test', room: '$secret-salle', jwt: '$secret-jwt');
      final link = WhatsappLink(callId: 7, url: 'https://wa.me/237600000099?text=$secret');
      final tokens = AuthTokens(access: '$secret-acc', refresh: '$secret-ref', isNew: true);
      for (final o in [access, link, tokens]) {
        expect(o.toString().contains(secret), isFalse, reason: o.runtimeType.toString());
        expect('$o'.contains('237600000099'), isFalse);
      }
      expect(const ApiException(ApiErrorCode.tokenInvalid, message: '').toString(),
          'ApiException(token_invalid, null)');
    });

    test('aucun toString de lib/ n\'interpole un champ sensible', () {
      final hits = <String>[];
      for (final f in _dartFiles('lib')) {
        for (final m in RegExp(r"String toString\(\)\s*(=>|\{)([^;]*);").allMatches(_code(f))) {
          // On regarde seulement ce qui est interpolé ($x ou ${x}), pas le nom de la classe.
          final interpolated = RegExp(r'\$\{?([A-Za-z_][A-Za-z0-9_.]*)')
              .allMatches(m.group(2)!)
              .map((i) => i.group(1)!)
              .join(' ');
          if (RegExp(r'jwt|room|token|access|refresh|url|phone|password', caseSensitive: false)
              .hasMatch(interpolated)) {
            hits.add('${_rel(f)}: ${m.group(0)}');
          }
        }
      }
      expect(hits, isEmpty);
    });
  });

  group('Liens externes et WhatsApp', () {
    test('seul un lien https://wa.me/… est accepté comme lien WhatsApp', () {
      expect(WhatsappLink.isWhatsappUrl('https://wa.me/237600000001?text=Bonjour'), isTrue);
      for (final bad in [
        'http://wa.me/237600000001',
        'https://api.whatsapp.com/send?phone=1',
        'https://evil.test/wa.me/237600000001',
        'https://wa.me.evil.test/237600000001',
        'https://wa.me/',
        'https://wa.me',
        'intent://send#Intent;scheme=whatsapp;end',
        'whatsapp://send?phone=1',
        'tel:+237600000001',
        'javascript:alert(1)',
        'https://utilisateur@evil.test@wa.me/1',
        '',
      ]) {
        expect(WhatsappLink.isWhatsappUrl(bad), isFalse, reason: bad);
      }
    });

    test('une réponse avec un autre lien est refusée sans détail', () {
      expect(() => WhatsappLink.fromJson({'call_id': 1, 'wa_url': 'https://evil.test/x'}),
          throwsA(isA<FormatException>()));
      expect(WhatsappLink.fromJson({'call_id': 1, 'wa_url': 'https://wa.me/237600000001'}).callId, 1);
    });

    test('le code natif refuse tout lien qui n\'est pas https://wa.me et vise le paquet WhatsApp', () {
      final kt = File('android/app/src/main/kotlin/cm/netbuis/netbuis/AppChannel.kt').readAsStringSync();
      expect(kt, contains('uri.scheme != "https" || uri.host != "wa.me"'));
      expect(kt, contains('setPackage(pkg)'));
      expect(kt, contains('"com.whatsapp", "com.whatsapp.w4b"'));
    });

    test('url_launcher : seulement mailto/tel/lien externe de la vidéo, jamais en WebView', () {
      for (final f in _dartFiles('lib')) {
        final code = _code(f);
        expect(code.contains('inAppWebView') || code.contains('InAppWebView'), isFalse, reason: _rel(f));
        for (final m in RegExp(r'LaunchMode\.(\w+)').allMatches(code)) {
          expect(m.group(1), 'externalApplication', reason: _rel(f));
        }
      }
    });
  });
}
