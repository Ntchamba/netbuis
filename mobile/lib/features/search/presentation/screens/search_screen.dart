// Recherche écrite : champ, suggestions pendant la frappe, filtres, résultats
// (aucune maquette dédiée : champ et cartes repris de l'Accueil de `Main`)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../onboarding/application/city_controller.dart';
import '../../application/search_controller.dart';
import '../../application/suggestions_controller.dart';
import '../../data/models/suggestion.dart';
import '../../text_search/presentation/suggestions_list.dart';
import '../../text_search/presentation/text_search_field.dart';
import '../widgets/filters_sheet.dart';
import 'results_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _text;
  final _focus = FocusNode();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: ref.read(searchControllerProvider).query.q);
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 300) {
        ref.read(searchControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    ref.read(searchControllerProvider.notifier).onTextChanged(value);
    ref.read(suggestionsControllerProvider.notifier).onTextChanged(value);
  }

  void _submit(String value) {
    ref.read(suggestionsControllerProvider.notifier).clear();
    ref.read(searchControllerProvider.notifier).submit(value);
    _focus.unfocus();
  }

  void _pick(Suggestion s) {
    _text.value = TextEditingValue(
      text: s.text,
      selection: TextSelection.collapsed(offset: s.text.length),
    );
    _submit(s.text);
  }

  void _clear() {
    _text.clear();
    ref.read(suggestionsControllerProvider.notifier).clear();
    ref.read(searchControllerProvider.notifier).submit('');
    _focus.requestFocus();
  }

  Future<void> _changeCity() async {
    await context.push(Routes.chooseCity);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    // Nouvelle ville : la recherche repart de zéro, le champ aussi.
    ref.listen(selectedCityProvider, (previous, next) {
      if (previous?.value?.id != next.value?.id) {
        _text.clear();
        ref.read(suggestionsControllerProvider.notifier).clear();
      }
    });
    final suggestions = ref.watch(suggestionsControllerProvider);
    final query = ref.watch(searchControllerProvider.select((s) => s.query));
    final filtered = query.sector != null || query.zone != null;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('search-back'),
                    tooltip: l10n.t('search.back'),
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.arrow_back, color: c.textPrimary),
                    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  ),
                  Expanded(
                    child: TextSearchField(
                      controller: _text,
                      focusNode: _focus,
                      onChanged: _onChanged,
                      onSubmitted: _submit,
                      onClear: _clear,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('search-filters'),
                    tooltip: l10n.t('search.filters'),
                    onPressed: () => showFiltersSheet(context),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: filtered ? AppColors.accent : c.card,
                      side: BorderSide(color: filtered ? AppColors.accent : c.border),
                    ),
                    icon: Icon(Icons.tune,
                        size: 20, color: filtered ? AppColors.onAccent : c.textSecondary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: suggestions.isNotEmpty
                  ? SuggestionsList(suggestions: suggestions, onSelect: _pick)
                  : SearchResultsView(scroll: _scroll, onChangeCity: _changeCity),
            ),
          ],
        ),
      ),
    );
  }
}
