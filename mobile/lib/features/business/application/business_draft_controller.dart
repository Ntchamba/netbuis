import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Repart d'un brouillon vide.
  void reset() => state = const BusinessDraft();
}
