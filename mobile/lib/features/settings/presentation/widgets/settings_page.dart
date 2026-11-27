import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';

/// Gabarit des écrans de réglages et des pages légales : flèche de retour, titre, contenu qui défile.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('settings-back'),
                    tooltip: l10n.t('legal.back'),
                    onPressed: () => context.canPop() ? context.pop() : context.go(Routes.home),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
