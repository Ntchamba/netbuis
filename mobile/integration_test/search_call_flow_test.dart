// T056 : mêmes parcours que test/integration/, lancés sur appareil ou émulateur
// (`flutter test integration_test/search_call_flow_test.dart -d <appareil>`).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/integration/flow_scenarios.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
