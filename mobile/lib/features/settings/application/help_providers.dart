import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env.dart';
import '../../../core/config/feature_flags.dart';

/// Crédits et paiements : reportés (décision D-16, `CREDITS_ENABLED=False`). Remplaçable dans les
/// tests pour vérifier les deux états de la FAQ.
final creditsEnabledProvider = Provider<bool>((ref) => false);

/// Équipe NetBuis et parrainage : reportés (`TEAM_ENABLED=False`).
final teamEnabledProvider = Provider<bool>((ref) => FeatureFlags.teamEnabled);

/// Les trois thèmes de la FAQ, dans l'ordre de la maquette.
enum FaqTheme { calls, business, security }

/// Une question de la FAQ : les textes sont les clés `help.faq.<id>.q` et `help.faq.<id>.a`.
class FaqItem {
  const FaqItem(this.id, this.theme,
      {this.needsCredits = false,
      this.needsTeam = false,
      this.creditsVariant = false});

  final String id;
  final FaqTheme theme;
  final bool needsCredits;
  final bool needsTeam;

  /// La question et la réponse parlent de l'abonnement : une version sans abonnement est affichée tant que les crédits sont désactivés.
  final bool creditsVariant;

  String questionKeyFor({required bool credits}) =>
      creditsVariant && credits ? 'help.faq.$id.q.credits' : 'help.faq.$id.q';
  String answerKeyFor({required bool credits}) =>
      creditsVariant && credits ? 'help.faq.$id.a.credits' : 'help.faq.$id.a';
}

const List<FaqItem> allFaqItems = [
  FaqItem('free_call', FaqTheme.calls, needsCredits: true),
  FaqItem('credit_pack', FaqTheme.calls, needsCredits: true),
  FaqItem('hidden_number', FaqTheme.calls),
  FaqItem('create_business', FaqTheme.business),
  FaqItem('pending', FaqTheme.business),
  FaqItem('product_limit', FaqTheme.business, creditsVariant: true),
  FaqItem('join_team', FaqTheme.security, needsTeam: true),
  FaqItem('sponsorship', FaqTheme.security, needsTeam: true),
  FaqItem('report_suspect', FaqTheme.security),
];

/// Questions visibles selon les drapeaux : sans crédits, aucune question de crédits ; sans équipe,
/// aucune question d'équipe ou de parrainage.
List<FaqItem> visibleFaqItems({required bool credits, required bool team}) => [
      for (final item in allFaqItems)
        if ((!item.needsCredits || credits) && (!item.needsTeam || team)) item
    ];

/// Coordonnées du support, lues dans la configuration (décision D-06).
class SupportContact {
  const SupportContact({
    this.whatsapp = Env.supportWhatsapp,
    this.phone = Env.supportPhone,
    this.email = Env.supportEmail,
  });

  final String whatsapp;
  final String phone;
  final String email;

  static final RegExp _phoneShape = RegExp(r'^\+?[0-9 ]{6,20}$');
  static final RegExp _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Chiffres du numéro WhatsApp (sans `+`, ni espaces), ou `null` si absent / `À REMPLACER`.
  String? get whatsappDigits {
    final v = whatsapp.trim();
    if (!_phoneShape.hasMatch(v)) return null;
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 8 && digits.length <= 15 ? digits : null;
  }

  /// Numéro de téléphone du support, ou `null` si absent / `À REMPLACER`.
  String? get phoneNumber {
    final v = phone.trim();
    return _phoneShape.hasMatch(v) ? v.replaceAll(' ', '') : null;
  }

  /// Adresse e-mail du support, ou `null` si absente / `À REMPLACER`.
  String? get emailAddress {
    final v = email.trim();
    return _emailShape.hasMatch(v) ? v : null;
  }

  /// Lien `https://wa.me/<numéro>` (avec [message] pré-rempli), ou `null` si le numéro n'est pas valide.
  String? whatsappLink({String? message}) {
    final digits = whatsappDigits;
    if (digits == null) return null;
    final base = 'https://wa.me/$digits';
    return message == null
        ? base
        : '$base?text=${Uri.encodeComponent(message)}';
  }

  bool get anyAvailable =>
      whatsappDigits != null || phoneNumber != null || emailAddress != null;
}

final supportContactProvider =
    Provider<SupportContact>((ref) => const SupportContact());

/// Ouvre un lien `mailto:` dans l'application de messagerie ; remplaçable dans les tests.
final mailLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => (uri) => launchUrl(uri),
);
