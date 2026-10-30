// T123 : mêmes parcours par domaine que test/integration/domain_flow_test.dart, lancés sur
// appareil ou émulateur (`flutter test integration_test/domain_flow_test.dart -d <appareil>`).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/integration/domain_scenarios.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('accès : première ouverture → code SMS → Accueil', scenarioAccessFirstOpen);
  testWidgets('accès : session restaurée', scenarioAccessRestoredSession);
  testWidgets('accès : déconnexion', scenarioAccessLogout);
  testWidgets('création de commerce : assistant complet → en attente de validation',
      scenarioBusinessCreation);
  testWidgets('recherche par nom du commerce', scenarioSearchByName);
  testWidgets('recherche vocale', scenarioVoiceSearchResults);
  testWidgets('carte : villes → quartiers → commerces → fiche', scenarioMapToBusiness);
  testWidgets('forum : lire, commenter, signaler, publier', scenarioForumReadCommentReportPublish);
  testWidgets('compte : modifier ma boutique', scenarioAccountEditBusiness);
  testWidgets('compte : suppression', scenarioAccountDeletion);
}
