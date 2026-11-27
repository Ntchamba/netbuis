// Nettoyage des données de la personne qui se déconnecte (ou dont le compte est supprimé).
// Centralisé ici : il ne dépend pas de l'ouverture préalable des écrans Forum ou Recherche.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../forum/application/forum_services.dart';
import '../../search/application/search_controller.dart';

/// Lance l'effacement explicite des mémoires disque (fil du forum, dernière recherche), même si
/// leurs contrôleurs n'existent pas. La mémoire vive (fil, signalements, recherche) est
/// réinitialisée par ces contrôleurs eux-mêmes quand ils existent : ils écoutent la déconnexion
/// (un fournisseur ne peut pas en invalider un autre qui l'écoute).
/// N'attend pas le disque et ne lève jamais d'erreur : la déconnexion doit toujours aboutir.
void clearSessionData(Ref ref) {
  _safely(() => ref.read(forumFeedCacheProvider).clear());
  _safely(() => ref.read(searchCacheProvider).clear());
}

void _safely(Future<void> Function() action) {
  try {
    unawaited(action().catchError((Object _) {}));
  } on Object {
    // La mémoire du téléphone ne doit pas empêcher la déconnexion.
  }
}
