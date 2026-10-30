// T123 : parcours de bout en bout par domaine, exécutés par `flutter test`
// (mêmes scénarios que sur appareil : integration_test/domain_flow_test.dart).
import 'package:flutter_test/flutter_test.dart';

import 'domain_scenarios.dart';

void main() {
  group('accès', () {
    testWidgets('première ouverture : Découverte → numéro → mauvais code → code SMS → Accueil',
        scenarioAccessFirstOpen);
    testWidgets('session restaurée : Accueil sans repasser par le numéro',
        scenarioAccessRestoredSession);
    testWidgets('déconnexion : jetons effacés, Accueil protégé, reconnexion possible',
        scenarioAccessLogout);
  });
  group('création de commerce', () {
    testWidgets('assistant Commerce complet → récapitulatif → envoyé → en attente de validation',
        scenarioBusinessCreation);
  });
  group('recherche', () {
    testWidgets('par nom du commerce : casse, accents, aucun résultat, fiche',
        scenarioSearchByName);
    testWidgets('vocale : aucun résultat puis résultat', scenarioVoiceSearchResults);
  });
  group('carte', () {
    testWidgets('villes → quartiers → commerces → fiche, puis retour', scenarioMapToBusiness);
  });
  group('forum', () {
    testWidgets('lire, commenter, signaler, publier (refus puis succès)',
        scenarioForumReadCommentReportPublish);
  });
  group('compte', () {
    testWidgets('modifier ma boutique : sans puis avec nouvelle validation',
        scenarioAccountEditBusiness);
    testWidgets('suppression : annuler, réseau coupé, puis stockage vidé et retour à l\'entrée',
        scenarioAccountDeletion);
  });
}
