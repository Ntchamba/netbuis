import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/referentials/referential_models.dart';
import '../../../core/data/zones/zone.dart';
import '../../../core/storage/prefs.dart';
import '../data/models/business_draft.dart';

/// Brouillon de la demande, partagé par tous les écrans du parcours.
///
/// `autoDispose` : il vit tant qu'un écran du parcours est ouvert (le retour arrière
/// retrouve donc tout), et repart d'un brouillon neuf quand on quitte le parcours puis
/// qu'on y revient. Aucune écriture sur le disque.
final businessDraftProvider =
    NotifierProvider.autoDispose<BusinessDraftController, BusinessDraft>(
  BusinessDraftController.new,
);

class BusinessDraftController extends Notifier<BusinessDraft> {
  @override
  BusinessDraft build() => const BusinessDraft();

  /// Modification libre pour les écrans des étapes : `update((d) => d.copyWith(...))`.
  void update(BusinessDraft Function(BusinessDraft draft) change) => state = change(state);

  /// Change le type de compte (vide les champs devenus sans objet).
  void setType(BusinessAccountType type) => state = state.withType(type);

  /// Choisit la ville ou le village (vide le quartier si la ville change). Lève
  /// `InvalidBusinessZoneException` si la zone n'est pas de niveau `ville_village`.
  void setCity(Zone city) => state = state.withCity(city);

  /// Choisit le quartier de la ville choisie, ou `null` pour garder la ville seule.
  void setQuartier(Zone? district) => state = state.withQuartier(district);

  /// Reprend la ville mémorisée (T022) comme lieu de départ, seulement si aucun lieu
  /// n'est encore choisi. La ville mémorisée vient de la liste des zones `ville_village`
  /// (c'est la seule que l'écran de T022 propose) : son niveau est donc `ville_village`.
  void prefillCity(SelectedCity? city) {
    if (city == null || state.zoneId != null) return;
    setCity(Zone(id: city.id, name: city.name, level: ZoneLevel.villeVillage));
  }

  void setName(String value) => state = state.copyWith(name: value);
  void setRepere(String value) => state = state.copyWith(repere: value);
  void setRepresentantNom(String value) => state = state.copyWith(representantNom: value);
  void setPhotoPath(String? path) => state = state.copyWith(photoPath: path);
  void setRepresentantPhotoPath(String? path) =>
      state = state.copyWith(representantPhotoPath: path);
  void setFormeJuridique(LegalForm? form) => state = state.copyWith(formeJuridique: form);
  void setRccm(String value) => state = state.copyWith(rccm: value);

  /// Choisit le secteur ; un autre secteur vide sous-catégories, nom libre et description.
  void setSector(Sector sector) => state = state.withSector(sector);

  /// Choisit la catégorie de service ; une autre catégorie vide le texte libre.
  void setServiceCategory(ReferentialItem category) =>
      state = state.withServiceCategory(category);

  void setCategorieServiceLibre(String value) =>
      state = state.copyWith(categorieServiceLibre: value);
  void setCniPhotoPath(String? path) => state = state.copyWith(cniPhotoPath: path);
  void setDiplomePhotoPath(String? path) => state = state.copyWith(diplomePhotoPath: path);

  void setSecteurLibre(String value) => state = state.copyWith(secteurLibre: value);
  void setDescriptionActivite(String value) =>
      state = state.copyWith(descriptionActivite: value);

  /// Coche ou décoche une sous-catégorie. Renvoie **faux** quand la case n'a pas pu être
  /// cochée parce que [limit] est atteint (null = pas de plafond) : rien n'est ajouté.
  bool toggleSubcategory(int id, {required int? limit}) {
    final ids = state.sousCategorieIds;
    if (ids.contains(id)) {
      state = state.copyWith(sousCategorieIds: [for (final i in ids) if (i != id) i]);
      return true;
    }
    if (limit != null && ids.length >= limit) return false;
    state = state.copyWith(sousCategorieIds: [...ids, id]);
    return true;
  }

  /// Choisit le type d'établissement ; un autre type vide le texte libre et les détails.
  void setStructureType(ReferentialItem type) => state = state.withStructureType(type);

  void setStructureTypeLibre(String value) => state = state.copyWith(structureTypeLibre: value);
  void setDescription(String value) => state = state.copyWith(description: value);
  void setCuisine(String code) => state = state.copyWith(cuisine: code);
  void setLivraison(bool value) => state = state.copyWith(livraison: value);
  void setHoraires(String value) => state = state.copyWith(horaires: value);
  void setStanding(String code) => state = state.copyWith(standing: code);
  void setNombreChambres(int? value) => state = state.copyWith(nombreChambres: value);
  void setNumeroAgrement(String value) => state = state.copyWith(numeroAgrement: value);

  /// Coche ou décoche un équipement d'hôtel (pas de plafond).
  void toggleEquipement(String code) {
    final list = state.equipements;
    state = state.copyWith(
      equipements: list.contains(code) ? [for (final c in list) if (c != code) c] : [...list, code],
    );
  }

  /// Coche ou décoche un rayon de supermarché ; même règle que [toggleSubcategory] :
  /// renvoie **faux** (rien n'est ajouté) quand [limit] est atteint.
  bool toggleRayon(String code, {required int? limit}) {
    final r = _toggleCode(state.rayons, code, limit);
    if (r == null) return false;
    state = state.copyWith(rayons: r);
    return true;
  }

  /// Coche ou décoche une spécialité de centre de santé ; même règle que [toggleRayon].
  bool toggleSpecialite(String code, {required int? limit}) {
    final r = _toggleCode(state.specialites, code, limit);
    if (r == null) return false;
    state = state.copyWith(specialites: r);
    return true;
  }

  /// Nouvelle liste, ou null si l'ajout dépasse [limit].
  static List<String>? _toggleCode(List<String> list, String code, int? limit) {
    if (list.contains(code)) return [for (final c in list) if (c != code) c];
    if (limit != null && list.length >= limit) return null;
    return [...list, code];
  }

  /// Repart d'un brouillon vide.
  void reset() => state = const BusinessDraft();
}
