// Signalement (T093) : ce qu'on signale et pourquoi. Listes fermées, comme le serveur.
import 'package:flutter/material.dart';

/// Ce qu'on signale (champ `target_type` de POST /api/reports/).
enum ReportTarget {
  post('post'),
  comment('comment'),
  business('business');

  const ReportTarget(this.value);
  final String value;
}

/// Les 4 motifs (champ `reason`), dans l'ordre d'affichage. Aucune saisie libre.
enum ReportReason {
  spam('spam', Icons.mark_email_unread_outlined),
  arnaque('arnaque', Icons.gpp_maybe_outlined),
  inapproprie('contenu_inapproprie', Icons.report_gmailerrorred_outlined),
  autre('autre', Icons.more_horiz);

  const ReportReason(this.value, this.icon);
  final String value;
  final IconData icon;
}

/// Résultat d'un envoi, pour l'écran.
enum ReportOutcome {
  /// Signalement enregistré.
  done,

  /// 409 `already_reported` : déjà signalé, ce n'est pas une erreur.
  already,

  /// 400 `own_content` : on ne signale pas son propre contenu.
  own,

  /// 404 : le contenu a disparu.
  gone,

  /// Pas de réseau : on peut réessayer.
  network,

  /// Toute autre erreur.
  failed,
}
