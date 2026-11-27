import 'zone.dart';

/// Accès aux zones (public, sans connexion). Partagé par l'accueil, la recherche
/// et la création de commerce.
abstract class ZoneRepository {
  /// Zones actives d'un niveau et/ou d'un parent, triées par ordre puis nom.
  /// Suit toutes les pages du serveur.
  Future<List<Zone>> listZones({ZoneLevel? level, int? parent});

  /// Une zone avec son chemin. Erreur 404 si elle est inconnue ou désactivée.
  Future<ZoneDetail> getZone(int id);
}
