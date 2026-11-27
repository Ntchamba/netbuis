import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/me.dart';

/// Identité (maquette Profil) : avatar rond avec initiales, nom, numéro masqué
/// suivi de « numéro vérifié ». Sans nom : icône personne et « Utilisateur NetBuis »,
/// jamais le numéro ni ses chiffres.
class ProfileIdentity extends StatelessWidget {
  const ProfileIdentity({super.key, required this.me});

  final Me me;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final initials = me.hasName ? initialsOf(me.name) : '';
    final name = me.hasName ? me.name : l10n.t('profile.defaultName');
    final verified =
        l10n.t('profile.verified').replaceAll('{phone}', me.phoneMasked);

    return Row(
      children: [
        Semantics(
          container: true,
          label: initials.isEmpty
              ? l10n.t('profile.avatarNone')
              : l10n.t('profile.avatar').replaceAll('{initials}', initials),
          excludeSemantics: true,
          child: Container(
            key: const ValueKey('profile-avatar'),
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.card,
              shape: BoxShape.circle,
              border: Border.all(color: c.border),
            ),
            child: initials.isEmpty
                ? Icon(Icons.person_outline, size: 30, color: c.accentText)
                : Text(
                    initials,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: c.accentText),
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                key: const ValueKey('profile-name'),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                verified,
                key: const ValueKey('profile-phone'),
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
