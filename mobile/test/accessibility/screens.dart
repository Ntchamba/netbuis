import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/data/referentials/referential_repository_fake.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/account/data/models/me.dart';
import 'package:netbuis/features/account/presentation/screens/account_screen.dart';
import 'package:netbuis/features/account/presentation/screens/edit_profile_screen.dart';
import 'package:netbuis/features/auth/presentation/screens/login_screen.dart';
import 'package:netbuis/features/auth/presentation/screens/otp_screen.dart';
import 'package:netbuis/features/business/data/models/business.dart';
import 'package:netbuis/features/business/data/models/business_draft.dart';
import 'package:netbuis/features/business/data/repositories/business_repository.dart';
import 'package:netbuis/features/business/application/public_business_controller.dart';
import 'package:netbuis/features/business/data/models/public_business.dart';
import 'package:netbuis/features/business/data/repositories/public_business_repository_fake.dart';
import 'package:netbuis/features/business/presentation/screens/business_detail_screen.dart';
import 'package:netbuis/features/business/presentation/screens/business_edit_screen.dart';
import 'package:netbuis/features/business/presentation/screens/business_info_screen.dart';
import 'package:netbuis/features/business/presentation/screens/details_screen.dart';
import 'package:netbuis/features/business/presentation/screens/district_screen.dart';
import 'package:netbuis/features/business/presentation/screens/legal_form_screen.dart';
import 'package:netbuis/features/business/presentation/screens/location_screen.dart';
import 'package:netbuis/features/business/presentation/screens/recap_screen.dart';
import 'package:netbuis/features/business/presentation/screens/sector_screen.dart';
import 'package:netbuis/features/business/presentation/screens/sent_screen.dart';
import 'package:netbuis/features/business/presentation/screens/service_category_screen.dart';
import 'package:netbuis/features/business/presentation/screens/structure_details_screen.dart';
import 'package:netbuis/features/business/presentation/screens/structure_type_screen.dart';
import 'package:netbuis/features/business/presentation/screens/subscription_soon_screen.dart';
import 'package:netbuis/features/call/presentation/screens/call_history_screen.dart';
import 'package:netbuis/features/call/presentation/widgets/call_screen.dart';
import 'package:netbuis/features/forum/presentation/screens/forum_screen.dart';
import 'package:netbuis/features/forum/presentation/screens/my_posts_screen.dart';
import 'package:netbuis/features/forum/presentation/screens/post_screen.dart';
import 'package:netbuis/features/forum/presentation/widgets/report_sheet.dart';
import 'package:netbuis/features/forum/presentation/screens/publish_screen.dart';
import 'package:netbuis/features/home/presentation/screens/home_screen.dart';
import 'package:netbuis/features/maps/presentation/screens/area_screen.dart';
import 'package:netbuis/features/maps/presentation/screens/map_screen.dart';
import 'package:netbuis/features/merchant/data/repositories/merchant_repository.dart';
import 'package:netbuis/features/merchant/application/offers_controller.dart';
import 'package:netbuis/features/merchant/presentation/screens/edit_offer_screen.dart';
import 'package:netbuis/features/merchant/presentation/screens/offers_screen.dart';
import 'package:netbuis/features/onboarding/presentation/screens/choose_city_screen.dart';
import 'package:netbuis/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:netbuis/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/features/search/application/search_controller.dart';
import 'package:netbuis/features/search/data/models/search_query.dart';
import 'package:netbuis/features/search/data/models/search_result.dart';
import 'package:netbuis/features/search/data/repositories/search_repository_fake.dart';
import 'package:netbuis/features/search/presentation/screens/search_screen.dart';
import 'package:netbuis/features/settings/presentation/screens/about_screen.dart';
import 'package:netbuis/features/settings/presentation/screens/help_screen.dart';
import 'package:netbuis/features/settings/presentation/screens/legal_screen.dart';
import 'package:netbuis/features/settings/presentation/screens/settings_screen.dart';

import '../features/account/account_test_helpers.dart';
import '../features/auth/login_test_helpers.dart';
import '../features/business/business_submit_helpers.dart';
import '../features/call/call_test_helpers.dart';
import '../features/merchant/offers_test_helpers.dart';
import 'a11y_harness.dart';

BuildContext _ctx(WidgetTester t) => t.element(find.byType(Scaffold).first);

/// Compte avec un commerce au statut [status], dépôts factices.
List<Override> _withBusiness(BusinessStatus status,
        {bool suggest = false, String motif = ''}) =>
    [
      accountRepositoryProvider.overrideWithValue(ScriptedAccountRepository(
          me: const Me(
              id: 1,
              name: 'Jeff N.',
              phoneMasked: '+237 6•• •• •• 12',
              hasBusiness: true))),
      businessRepositoryProvider.overrideWithValue(_OneBusiness(MyBusiness(
        status: status,
        name: 'Boutique Mama Aïcha',
        motifRejet: motif,
        typeCompte: BusinessAccountType.boutique,
        zoneId: 21,
        repere: 'Près du grand manguier',
        descriptionActivite: 'Vente de fruits et légumes frais',
        representantNom: 'Aïcha Oumarou',
        suggestSubscription: suggest,
      ))),
    ];

/// Recherche dont chaque appel échoue faute de réseau.
class _FailingSearch extends SearchRepositoryFake {
  @override
  Future<SearchPage> search(SearchQuery query, {int page = 1}) =>
      throw const ApiException(ApiErrorCode.network);
}

abstract class _NoBusinessBase implements BusinessRepository {
  @override
  Future<UploadTicket> signUpload(
          {required String kind,
          required String contentType,
          required int size}) =>
      throw StateError('non utilisé par ces tests');
  @override
  Future<void> putFile(UploadTicket ticket, Uint8List bytes) =>
      throw StateError('non utilisé par ces tests');
  @override
  Future<MyBusiness> create(Map<String, Object?> body) =>
      throw StateError('non utilisé par ces tests');
  @override
  Future<MyBusiness> update(Map<String, Object?> body) =>
      throw StateError('non utilisé par ces tests');
}

class _OneBusiness extends _NoBusinessBase {
  _OneBusiness(this.business);
  final MyBusiness business;
  @override
  Future<MyBusiness> getMine() async => business;
}

Future<void> _openOtp(WidgetTester t) async {
  await t.enterText(phoneField, '600000042');
  await t.pump();
  await t.ensureVisible(find.text('Recevoir le code'));
  await t.pump();
  await t.tap(find.text('Recevoir le code'));
  await settle(t);
}

Future<void> _pushWidget(WidgetTester t, Widget screen) async {
  Navigator.of(_ctx(t), rootNavigator: true)
      .push(MaterialPageRoute<void>(builder: (_) => screen));
  await settle(t);
}

Future<void> _openCall(WidgetTester t) async {
  final call = find.byKey(const Key('detail-call'));
  await t.scrollUntilVisible(call, 200,
      scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(call);
  await t.pumpAndSettle();
  await t.tap(call);
  await settle(t);
}

Future<void> _openReport(WidgetTester t) async {
  final report = find.byKey(const Key('detail-report'));
  await t.scrollUntilVisible(report, 200,
      scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(report);
  await t.pumpAndSettle();
  await t.tap(report);
  await settle(t);
}

Future<void> _openFilters(WidgetTester t) async {
  await t.tap(find.byKey(const Key('search-filters')));
  await settle(t);
}

Future<void> _openSectors(WidgetTester t) async {
  await t.tap(find.byKey(const Key('chip-more')));
  await settle(t);
}

/// Brouillon d'un établissement du type [code] (supermarché, restaurant, hôtel, santé, autre).
Future<BusinessDraft> _structure(String code) async {
  final draft = await completeDraft(BusinessAccountType.structure);
  final types = await const ReferentialRepositoryFake().getStructureTypes();
  final typed =
      draft.withStructureType(types.firstWhere((t) => t.code == code));
  // L'hôtel exige un standing pour que le récapitulatif s'ouvre.
  return code == 'hotel'
      ? typed.copyWith(standing: 'standard', nombreChambres: 12)
      : typed;
}

/// Brouillon complet d'un type de compte.
Future<BusinessDraft> _account(BusinessAccountType type) => completeDraft(type);

/// Les écrans audités. `spec` : dans la liste des 16 de docs/spec/ACCESSIBILITE.md.
final List<A11yScreen> a11yScreens = [
  // --- Les 16 écrans de la spec ---
  const A11yScreen('Splash', Routes.splash, SplashScreen,
      signedIn: false, critical: true, spec: true),
  const A11yScreen('Onboarding', Routes.onboarding, OnboardingScreen,
      signedIn: false, spec: true),
  const A11yScreen('Connexion', Routes.login, LoginScreen,
      signedIn: false,
      critical: true,
      spec: true,
      numericKeys: [ValueKey('phone-field')]),
  A11yScreen('Connexion : code SMS', Routes.login, OtpScreen,
      signedIn: false,
      critical: true,
      spec: true,
      prepare: _openOtp,
      numericKeys: const [ValueKey('otp-field')]),
  const A11yScreen('Carte', Routes.map, MapScreen, spec: true),
  A11yScreen('Quartier', Routes.mapAreaPath(301), AreaScreen, spec: true),
  const A11yScreen('Historique', Routes.callHistory, CallHistoryScreen,
      spec: true),
  A11yScreen('MesPublications', Routes.myPosts, MyPostsScreen,
      spec: true, overrides: _withBusiness(BusinessStatus.active)),
  const A11yScreen('Profil', Routes.profile, AccountScreen,
      critical: true, spec: true),
  const A11yScreen('Forum', Routes.forum, ForumScreen, spec: true),
  A11yScreen('Création : Entreprise-Forme', Routes.createBusinessLegalForm,
      LegalFormScreen,
      spec: true, draft: () => completeDraft(BusinessAccountType.entreprise)),
  A11yScreen('Création : Secteur', Routes.createBusinessSector, SectorScreen,
      spec: true, draft: () => completeDraft(BusinessAccountType.boutique)),
  A11yScreen('Création : Prestataire-Catégorie',
      Routes.createBusinessServiceCategory, ServiceCategoryScreen,
      spec: true,
      draft: () => completeDraft(BusinessAccountType.prestataireService)),
  A11yScreen('Création : Structure-Type', Routes.createBusinessStructureType,
      StructureTypeScreen,
      spec: true, draft: () => completeDraft(BusinessAccountType.structure)),
  A11yScreen('Création : Structure-Détails',
      Routes.createBusinessStructureDetails, StructureDetailsScreen,
      spec: true, draft: () => completeDraft(BusinessAccountType.structure)),
  A11yScreen('Création : Détails', Routes.createBusinessDetails, DetailsScreen,
      spec: true, draft: () => completeDraft(BusinessAccountType.boutique)),
  A11yScreen('Création : Récap', Routes.createBusinessRecap, RecapScreen,
      spec: true, draft: () => completeDraft(BusinessAccountType.entreprise)),

  // --- Écrans liés à la création, avec maquette ---
  const A11yScreen(
      'Création : Informations', Routes.createBusiness, BusinessInfoScreen),
  A11yScreen('Création : Envoyé', Routes.createBusinessSent, SentScreen,
      draft: () => completeDraft(BusinessAccountType.boutique)),
  const A11yScreen('Accueil', Routes.home, HomeScreen,
      critical: true, text: 'Très demandé'),
  const A11yScreen('Nom (1re connexion)', Routes.yourName, EditProfileScreen),

  // --- Variantes d'écrans selon le type de compte / d'établissement ---
  A11yScreen('Création : Informations (entreprise)', Routes.createBusiness,
      BusinessInfoScreen,
      draft: () => _account(BusinessAccountType.entreprise)),
  A11yScreen('Création : Informations (prestataire)', Routes.createBusiness,
      BusinessInfoScreen,
      draft: () => _account(BusinessAccountType.prestataireService)),
  A11yScreen('Création : Structure-Détails (supermarché)',
      Routes.createBusinessStructureDetails, StructureDetailsScreen,
      draft: () => _structure('supermarche')),
  A11yScreen('Création : Structure-Détails (hôtel)',
      Routes.createBusinessStructureDetails, StructureDetailsScreen,
      draft: () => _structure('hotel'),
      numericKeys: const [ValueKey('business-structure-chambres')]),
  A11yScreen('Création : Structure-Détails (santé)',
      Routes.createBusinessStructureDetails, StructureDetailsScreen,
      draft: () => _structure('sante')),
  A11yScreen(
      'Création : Récap (commerce)', Routes.createBusinessRecap, RecapScreen,
      draft: () => _account(BusinessAccountType.boutique)),
  A11yScreen(
      'Création : Récap (prestataire)', Routes.createBusinessRecap, RecapScreen,
      draft: () => _account(BusinessAccountType.prestataireService)),
  A11yScreen(
      'Création : Récap (restaurant)', Routes.createBusinessRecap, RecapScreen,
      draft: () => _structure('restaurant')),
  A11yScreen(
      'Création : Récap (hôtel)', Routes.createBusinessRecap, RecapScreen,
      draft: () => _structure('hotel')),

  // --- Écrans sans maquette ---
  const A11yScreen('Choix de ville', Routes.chooseCity, ChooseCityScreen,
      mockup: false, signedIn: false),
  A11yScreen(
      'Choix du lieu : ville', Routes.createBusinessLocation, LocationScreen,
      mockup: false, draft: () => completeDraft(BusinessAccountType.boutique)),
  A11yScreen(
      'Choix du lieu : quartier', Routes.createBusinessDistrict, DistrictScreen,
      mockup: false, draft: () => completeDraft(BusinessAccountType.boutique)),
  const A11yScreen('Recherche', Routes.search, SearchScreen, mockup: false),
  A11yScreen('Recherche : aucun résultat', Routes.search, SearchScreen,
      mockup: false,
      text: 'Aucun résultat',
      overrides: [
        searchRepositoryProvider
            .overrideWithValue(SearchRepositoryFake(data: []))
      ]),
  A11yScreen('Accueil : aucun résultat', Routes.home, HomeScreen,
      mockup: false,
      text: 'Aucun commerce pour le moment',
      overrides: [
        searchRepositoryProvider
            .overrideWithValue(SearchRepositoryFake(data: []))
      ]),
  A11yScreen('Accueil : erreur réseau', Routes.home, HomeScreen,
      mockup: false,
      critical: true,
      text: 'ne se chargent pas',
      overrides: [
        searchRepositoryProvider.overrideWithValue(_FailingSearch())
      ]),
  A11yScreen('Filtres', Routes.search, BottomSheet,
      mockup: false, prepare: _openFilters),
  A11yScreen('Secteurs (Accueil)', Routes.home, BottomSheet,
      mockup: false, prepare: _openSectors),
  A11yScreen(
      'Fiche publique', Routes.businessDetailPath(1), BusinessDetailScreen,
      mockup: false),
  A11yScreen('Fiche publique : 3 photos, nom long',
      Routes.businessDetailPath(3), BusinessDetailScreen,
      mockup: false,
      text: 'Pharmacie',
      overrides: [
        publicBusinessRepositoryProvider
            .overrideWithValue(PublicBusinessRepositoryFake(data: const [
          PublicBusiness(
            id: 3,
            name: 'Pharmacie Générale du Grand Marché de Maroua Centre',
            typeCompte: 'boutique',
            secteur: 'Pharmacie & Santé',
            zone: PublicZone(id: 17, name: 'Hardé'),
            repere: 'En face de la grande mosquée, à côté du marché central',
            description: 'Médicaments, conseils et produits de santé.',
            descriptionActivite: 'Pharmacie et produits de santé',
            photos: ['/media/a.jpg', '/media/b.jpg', '/media/c.jpg'],
            verifie: true,
            offers: [
              PublicOffer(
                  id: 31,
                  name: 'Paracétamol 500 mg, boîte de 16 comprimés',
                  priceFcfa: 1500),
              PublicOffer(id: 32, name: 'Sirop contre la toux'),
            ],
          ),
        ])),
      ]),
  A11yScreen('Fiche publique : restaurant', Routes.businessDetailPath(2),
      BusinessDetailScreen,
      mockup: false, text: 'Chez Mama Riz'),
  A11yScreen('Forum : publication', Routes.forumPostPath(1), PostScreen,
      mockup: false),
  A11yScreen('Forum : publier', Routes.publish, PublishScreen,
      mockup: false, overrides: _withBusiness(BusinessStatus.active)),
  A11yScreen('Modifier ma boutique', Routes.editBusiness, BusinessEditScreen,
      mockup: false, overrides: _withBusiness(BusinessStatus.active)),
  A11yScreen('Profil : boutique active (abonnement proposé)', Routes.profile,
      AccountScreen,
      mockup: false,
      text: 'Souscrire',
      overrides: _withBusiness(BusinessStatus.active, suggest: true)),
  A11yScreen('Profil : boutique refusée', Routes.profile, AccountScreen,
      mockup: false,
      text: 'Corriger',
      overrides:
          _withBusiness(BusinessStatus.rejected, motif: 'La photo est floue.')),
  A11yScreen('Profil : boutique en attente', Routes.profile, AccountScreen,
      mockup: false,
      text: 'En attente',
      overrides: _withBusiness(BusinessStatus.pending)),
  A11yScreen('Mes produits', Routes.profile, OffersScreen,
      mockup: false,
      text: 'Riz local',
      overrides: [
        ..._withBusiness(BusinessStatus.active),
        merchantRepositoryProvider
            .overrideWithValue(ScriptedMerchantRepository(const [
          MerchantOffer(
              id: 1, name: 'Riz local (sac de 25 kg)', priceFcfa: 18000),
          MerchantOffer(id: 2, name: 'Huile de palme', description: 'Le litre'),
        ])),
      ],
      prepare: (t) => _pushWidget(t, const OffersScreen())),
  A11yScreen('Mes produits : ajouter', Routes.profile, EditOfferScreen,
      mockup: false,
      overrides: _withBusiness(BusinessStatus.active),
      numericKeys: const [ValueKey('offer-price')],
      prepare: (t) => _pushWidget(t, const EditOfferScreen())),
  A11yScreen('Fiche publique : appel à l\'équipe', Routes.businessDetailPath(1),
      CallScreen,
      mockup: false,
      overrides: callOverrides(FakeCallChannel(), FakeCallRepository()),
      prepare: _openCall),
  A11yScreen('Fiche publique : signaler (fenêtre)',
      Routes.businessDetailPath(1), ReportSheet,
      mockup: false, prepare: _openReport),
  const A11yScreen(
      'Abonnement : bientôt', Routes.subscriptionSoon, SubscriptionSoonScreen,
      mockup: false),
  const A11yScreen('Aide', Routes.help, HelpScreen, mockup: false),
  const A11yScreen('Réglages', Routes.settings, SettingsScreen, mockup: false),
  const A11yScreen('À propos', Routes.about, AboutScreen, mockup: false),
  const A11yScreen('Mentions légales', Routes.legalNotice, LegalScreen,
      mockup: false),
  const A11yScreen('Conditions', Routes.terms, LegalScreen, mockup: false),
  const A11yScreen('Confidentialité', Routes.privacy, LegalScreen,
      mockup: false),
];
