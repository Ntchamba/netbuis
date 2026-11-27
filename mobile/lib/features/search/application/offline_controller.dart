// « Hors connexion » : vrai quand la dernière requête a échoué faute de réseau, faux dès qu'une
// requête réussit. Les boutons Appeler / WhatsApp s'y réfèrent. Aucune dépendance de connectivité.
import 'package:flutter_riverpod/flutter_riverpod.dart';

final offlineProvider =
    NotifierProvider<OfflineController, bool>(OfflineController.new);

class OfflineController extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state != value) state = value;
  }
}
