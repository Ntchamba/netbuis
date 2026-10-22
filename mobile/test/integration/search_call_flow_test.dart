// T056 / T123 : parcours bout en bout exécutés par `flutter test` (mêmes scénarios que sur appareil).
// L'appel est un appel Jitsi vers l'équipe NetBuis (D-25) simulé par FakeJitsiService.
import 'package:flutter_test/flutter_test.dart';

import 'flow_scenarios.dart';

void main() {
  testWidgets('écrit : Accueil → recherche → fiche → appel Jitsi (appelant → « Appel en cours » → réponse équipe → fin) → historique',
      scenarioWrittenSearchCall);
  testWidgets('vocal : Accueil → micro → résultat → appel Jitsi → réponse équipe → fin → historique',
      scenarioVoiceSearchCall);
  testWidgets('WhatsApp : fiche → lien au canal natif, jamais affiché → historique',
      scenarioWhatsappFlow);
  testWidgets('WhatsApp absent : bouton grisé, rien ne part', scenarioWhatsappAbsent);
  testWidgets('hors connexion : bandeau, boutons désactivés, puis retour du réseau',
      scenarioOffline);
  testWidgets('échec : session impossible (réseau), aucune salle Jitsi, aucune question de suivi',
      scenarioCallRefused);
  testWidgets('équipe indisponible : message exact, aucune salle Jitsi rejointe',
      scenarioTeamUnavailable);
  testWidgets('équipe sans réponse : « Personne n\'a répondu », salle quittée', scenarioTeamMissed);
  testWidgets('annulation : l\'appelant raccroche pendant la sonnerie (cancel, pas end)',
      scenarioCallCancelled);
}
