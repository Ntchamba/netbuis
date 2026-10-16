import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Textes de l'interface, lus dans assets/l10n/{fr,en}.json (français par défaut).
class L10n {
  L10n(this.locale, this._strings);

  static const supportedLocales = [Locale('fr'), Locale('en')];
  static const delegate = _L10nDelegate();

  final Locale locale;
  final Map<String, String> _strings;

  static L10n of(BuildContext context) => Localizations.of<L10n>(context, L10n)!;

  /// Renvoie le texte de la clé ; une clé absente lève une erreur (pas de texte silencieusement vide).
  String t(String key) {
    final value = _strings[key];
    if (value == null) throw FlutterError('Clé de traduction absente : $key');
    return value;
  }

  static Future<L10n> load(Locale locale) async {
    final raw = await rootBundle.loadString(
      'assets/l10n/${locale.languageCode}.json',
      cache: false, // chargé une seule fois par langue ; évite un Future partagé entre tests
    );
    final map = (json.decode(raw) as Map<String, dynamic>).cast<String, String>();
    return L10n(locale, map);
  }
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  bool isSupported(Locale locale) =>
      L10n.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<L10n> load(Locale locale) => L10n.load(locale);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}
