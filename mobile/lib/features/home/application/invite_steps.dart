// Les feuilles « Inviter » de l'Accueil : lesquelles s'affichent, dans quel ordre

enum InviteStep { sponsor, business, share }

/// Devenir parrain : seulement si l'équipe est active (`TEAM_ENABLED`).
/// Créer mon compte business : pas pour un compte qui en a déjà un.
/// Partager NetBuis : toujours.
List<InviteStep> inviteSteps({required bool teamEnabled, required bool hasBusiness}) => [
      if (teamEnabled) InviteStep.sponsor,
      if (!hasBusiness) InviteStep.business,
      InviteStep.share,
    ];
