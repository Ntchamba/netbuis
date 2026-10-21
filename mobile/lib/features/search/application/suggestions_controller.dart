// Suggestions pendant la frappe (8 au plus, dès 2 caractères, anti-rebond 400 ms)
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/suggestion.dart';
import 'search_controller.dart';

final suggestionsControllerProvider =
    NotifierProvider.autoDispose<SuggestionsController, List<Suggestion>>(
  SuggestionsController.new,
);

class SuggestionsController extends Notifier<List<Suggestion>> {
  Timer? _timer;
  int _ticket = 0;

  @override
  List<Suggestion> build() {
    ref.onDispose(() {
      _timer?.cancel();
      _ticket++;
    });
    return const [];
  }

  /// À appeler à chaque frappe. Moins de 2 caractères : la liste se vide. Une erreur
  /// réseau vide aussi la liste (les suggestions ne bloquent jamais la recherche).
  void onTextChanged(String text) {
    _timer?.cancel();
    final q = text.trim();
    if (q.length < kMinSuggestionChars) {
      _ticket++;
      state = const [];
      return;
    }
    _timer = Timer(kSearchDebounce, () => _load(q));
  }

  void clear() {
    _timer?.cancel();
    _ticket++;
    state = const [];
  }

  Future<void> _load(String q) async {
    final ticket = ++_ticket;
    try {
      final found = await ref.read(searchRepositoryProvider).suggestions(q);
      if (!ref.mounted || ticket != _ticket) return;
      state = List.unmodifiable(found.take(kMaxSuggestions));
    } on Object {
      if (!ref.mounted || ticket != _ticket) return;
      state = const [];
    }
  }
}
