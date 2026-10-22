import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Clés dont la valeur anglaise peut légitimement être identique à la française
/// (noms propres, sigles, nombres, mots identiques dans les deux langues, icônes).
const Set<String> _sameOnPurpose = {
  'nav.forum', 'forum.title', 'map.pin', 'auth.phone.hint',
  'auth.duration.seconds', 'auth.duration.minutes', 'auth.duration.hours',
  'business.create.noteIcon.boutique', 'business.create.noteIcon.entreprise',
  'business.create.noteIcon.prestataire_service', 'business.create.noteIcon.structure',
  'business.create.noteIcon.particulier_vendeur',
  'business.create.structure.standing.standard', 'business.create.structure.amenity.parking',
  'business.recap.rccm', 'business.recap.photos', 'business.recap.cuisine',
  'business.recap.standing', 'business.detail.cuisine', 'business.detail.standing',
  'business.detail.price', 'business.detail.whatsapp', 'history.badge.whatsapp',
  'home.card.whatsapp', 'call.line.orange', 'call.line.mtn', 'history.entry',
  'offers.form.description', 'search.suggestions.label', 'report.reason.spam',
  'home.card.service', 'about.version', 'home.chip.allIcon', 'home.chip.moreIcon',
  // Noms de langue écrits dans leur propre langue.
  'settings.language.fr', 'settings.language.en',
};

Map<String, String> _read(String lang) =>
    (json.decode(File('assets/l10n/$lang.json').readAsStringSync()) as Map<String, dynamic>)
        .cast<String, String>();

Set<String> _placeholders(String s) =>
    RegExp(r'\{[a-zA-Z]+\}').allMatches(s).map((m) => m.group(0)!).toSet();

void main() {
  final fr = _read('fr');
  final en = _read('en');

  test('mêmes clés dans fr.json et en.json', () {
    expect(en.keys.toSet().difference(fr.keys.toSet()), isEmpty, reason: 'clés seulement en anglais');
    expect(fr.keys.toSet().difference(en.keys.toSet()), isEmpty, reason: 'clés seulement en français');
  });

  test('aucune valeur vide', () {
    expect(fr.entries.where((e) => e.value.trim().isEmpty), isEmpty);
    expect(en.entries.where((e) => e.value.trim().isEmpty), isEmpty);
  });

  test('chaque clé est réellement traduite (pas le français recopié)', () {
    final copied = [
      for (final k in fr.keys)
        if (fr[k] == en[k] && !_sameOnPurpose.contains(k)) k
    ];
    expect(copied, isEmpty, reason: 'valeur anglaise identique à la française : $copied');
  });

  test('l\'exception « identique volontaire » ne cache pas une clé qui a disparu', () {
    expect(_sameOnPurpose.difference(fr.keys.toSet()), isEmpty);
  });

  test('les paramètres {…} sont les mêmes dans les deux langues', () {
    final bad = [
      for (final k in fr.keys)
        if (!_setEquals(_placeholders(fr[k]!), _placeholders(en[k]!))) k
    ];
    expect(bad, isEmpty);
  });

  test('toute clé utilisée dans le code existe (fr et en)', () {
    final used = <String>{};
    final pattern = RegExp(r"""\.t\(\s*['"]([A-Za-z0-9_.]+)['"]\s*\)""");
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      for (final m in pattern.allMatches(f.readAsStringSync())) {
        used.add(m.group(1)!);
      }
    }
    expect(used, isNotEmpty);
    expect(used.difference(fr.keys.toSet()), isEmpty, reason: 'absentes de fr.json');
    expect(used.difference(en.keys.toSet()), isEmpty, reason: 'absentes de en.json');
  });

  test('le test échoue bien sur une clé non traduite (preuve de la règle)', () {
    final fakeFr = {'x.y': 'Bonjour'};
    final fakeEn = {'x.y': 'Bonjour'};
    final copied = [
      for (final k in fakeFr.keys)
        if (fakeFr[k] == fakeEn[k] && !_sameOnPurpose.contains(k)) k
    ];
    expect(copied, ['x.y']);
  });
}

bool _setEquals(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);
