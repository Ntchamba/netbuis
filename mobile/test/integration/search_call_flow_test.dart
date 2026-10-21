// T056 : parcours bout en bout exécutés par `flutter test` (mêmes scénarios que sur appareil).
import 'package:flutter_test/flutter_test.dart';

import 'flow_scenarios.dart';

void main() {
  testWidgets('écrit : Accueil → recherche → fiche → appel Orange → « abouti » → historique',
      scenarioWrittenSearchCall);
  testWidgets('vocal : Accueil → micro → résultat → appel MTN → « pas de réponse » → historique',
      scenarioVoiceSearchCall);
  testWidgets('WhatsApp : fiche → lien au canal natif, jamais affiché → historique',
      scenarioWhatsappFlow);
  testWidgets('WhatsApp absent : bouton grisé, rien ne part', scenarioWhatsappAbsent);
  testWidgets('hors connexion : bandeau, boutons désactivés, puis retour du réseau',
      scenarioOffline);
  testWidgets('échec : appel refusé, aucun appel natif, aucune question « ça a abouti ? »',
      scenarioCallRefused);
}
