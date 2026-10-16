import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/l10n/l10n.dart';

void main() {
  Map<String, dynamic> read(String lang) =>
      json.decode(File('assets/l10n/$lang.json').readAsStringSync()) as Map<String, dynamic>;

  test('fr.json et en.json ont exactement les mêmes clés', () {
    expect(read('en').keys.toSet(), read('fr').keys.toSet());
  });

  test('une clé absente lève une erreur', () {
    final l10n = L10n(const Locale('fr'), {'nav.home': 'Accueil'});
    expect(l10n.t('nav.home'), 'Accueil');
    expect(() => l10n.t('nav.trends'), throwsA(isA<FlutterError>()));
  });
}
