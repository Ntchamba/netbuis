import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/referentials/referential_models.dart';
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

  /// Repart d'un brouillon vide.
  void reset() => state = const BusinessDraft();
}
