// Règle du lieu d'un compte business et recherche par nom
import '../../../core/data/zones/zone.dart';

/// Vrai si une zone de ce niveau peut être le lieu d'un compte business : seulement
/// `ville_village` ou `quartier` (le serveur refuse les autres niveaux avec une erreur
/// sur le champ `zone`). Fonction pure : c'est la **seule** règle de niveau de
/// l'application, utilisée par le brouillon et par les écrans.
bool isBusinessZoneLevel(ZoneLevel level) =>
    level == ZoneLevel.villeVillage || level == ZoneLevel.quartier;

/// Zone refusée comme lieu du commerce parce que son niveau ne convient pas
/// (pays, région, département, arrondissement, repère), ou n'est pas celui attendu.
class InvalidBusinessZoneException implements Exception {
  const InvalidBusinessZoneException(this.level);

  /// Niveau de la zone refusée.
  final ZoneLevel level;

  @override
  String toString() => 'InvalidBusinessZoneException(${level.value})';
}

/// Lève [InvalidBusinessZoneException] si [zone] n'est pas d'un niveau `expected` accepté.
void ensureBusinessZone(Zone zone, {required ZoneLevel expected}) {
  if (!isBusinessZoneLevel(zone.level) || zone.level != expected) {
    throw InvalidBusinessZoneException(zone.level);
  }
}

const String _accented = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿœæ';
const String _plain = 'aaaaaaceeeeiiiinooooouuuuyyoa';

/// Texte pour comparer des noms : minuscules, sans accents, espaces des bouts retirés.
String normalizeForSearch(String text) {
  final lower = text.trim().toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    final i = _accented.indexOf(ch);
    if (i < 0) {
      out.write(ch);
    } else if (ch == 'œ') {
      out.write('oe');
    } else if (ch == 'æ') {
      out.write('ae');
    } else {
      out.write(_plain[i]);
    }
  }
  return out.toString();
}

/// Zones dont le nom contient [query] (insensible à la casse et aux accents).
/// Une recherche vide renvoie tout, dans l'ordre reçu.
List<Zone> filterZonesByName(List<Zone> zones, String query) {
  final q = normalizeForSearch(query);
  if (q.isEmpty) return zones;
  return [for (final z in zones) if (normalizeForSearch(z.name).contains(q)) z];
}
