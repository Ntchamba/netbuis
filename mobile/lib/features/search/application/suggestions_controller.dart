// Suggestions pendant la frappe (8 au plus, dès 2 caractères, anti-rebond 400 ms)
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/models/suggestion.dart';
import 'search_controller.dart';

final suggestionsControllerProvider =
    NotifierProvider.autoDispose<SuggestionsController, List<Suggestion>>(
  SuggestionsController.new,
);

/// Vrai quand le serveur a répondu « trop de requêtes » (429 `throttled`) : l'écran affiche un
/// message dédié et les suggestions se taisent le temps de l'attente demandée.
final suggestionsThrottledProvider =
    NotifierProvider.autoDispose<SuggestionsThrottled, bool>(SuggestionsThrottled.new);

class SuggestionsThrottled extends Notifier<bool> {
  @override
  bool build() => false;

  // ignore: use_setters_to_change_properties
  void set(bool value) => state = value;
}

/// Attente par défaut quand le serveur ne donne pas de `Retry-After`.
const Duration kThrottleDefaultWait = Duration(seconds: 10);

/// Vrai pour un refus « trop de requêtes » du serveur (code `throttled` ou HTTP 429).
bool isThrottledError(Object? e) =>
    e is ApiException &&
    (e.serverCode == ServerCodes.throttled || e.statusCode == 429);

class SuggestionsController extends Notifier<List<Suggestion>> {
  Timer? _timer;
  Timer? _cooldown;
  int _ticket = 0;

  @override
  List<Suggestion> build() {
    ref.onDispose(() {
      _timer?.cancel();
      _cooldown?.cancel();
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
    // Pendant l'attente imposée par le serveur, aucune requête n'est envoyée.
    if (_cooldown?.isActive ?? false) {
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
    } on Object catch (e) {
      if (!ref.mounted || ticket != _ticket) return;
      state = const [];
      if (isThrottledError(e)) {
        ref.read(suggestionsThrottledProvider.notifier).set(true);
        final wait = (e as ApiException).retryAfter ?? kThrottleDefaultWait;
        _cooldown?.cancel();
        _cooldown = Timer(wait, () {
          if (ref.mounted) ref.read(suggestionsThrottledProvider.notifier).set(false);
        });
      }
    }
  }
}
