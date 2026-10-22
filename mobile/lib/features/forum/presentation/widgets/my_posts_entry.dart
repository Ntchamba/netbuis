import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';

/// Ligne « Mes publications → » du Profil (bloc COMPTE BUSINESS). Elle ouvre [Routes.myPosts],
/// qui explique « en attente de validation » tant que le compte business n'est pas actif.
class MyPostsEntry extends StatelessWidget {
  const MyPostsEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final label = l10n.t('posts.mine.title');
    void open() => context.push(Routes.myPosts);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Semantics(
        button: true,
        label: label,
        onTap: open,
        excludeSemantics: true,
        child: InkWell(
          key: const ValueKey('profile-my-posts'),
          borderRadius: BorderRadius.circular(16),
          onTap: open,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
                  const SizedBox(width: 8),
                  Text('→', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
