// Fiche publique d'un commerce (T047). Écran non maquetté : éléments de Main/Quartier
// (cartes, badges, bouton d'accent). Appeler : T052. Aucun numéro : il ne sort que de POST /api/calls/initiate/.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../call/presentation/widgets/call_button.dart';
import '../../../call/presentation/widgets/whatsapp_button.dart';
import '../../../search/application/offline_controller.dart';
import '../../application/public_business_controller.dart';
import '../../data/models/public_business.dart';
import '../widgets/contact_actions.dart';
import '../widgets/offer_tile.dart';
import '../widgets/photo_gallery.dart';
import '../widgets/public_info_section.dart';

const List<String> _typeCodes = [
  'boutique', 'entreprise', 'particulier_vendeur', 'prestataire_service', 'structure',
];

class BusinessDetailScreen extends ConsumerWidget {
  const BusinessDetailScreen({super.key, required this.businessId});

  final int businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final state = ref.watch(publicBusinessProvider(businessId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('business.detail.title'))),
      body: SafeArea(
        child: state.when(
          loading: () => Center(
            child: Semantics(
              label: l10n.t('business.detail.loading'),
              child: const CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => isBusinessNotFound(e)
              ? _Message(
                  key: const Key('detail-not-found'),
                  title: l10n.t('business.detail.notFound.title'),
                  body: l10n.t('business.detail.notFound.body'),
                  action: l10n.t('business.detail.back'),
                  onAction: () => context.canPop() ? context.pop() : context.go(Routes.home),
                )
              : _Message(
                  key: const Key('detail-error'),
                  title: l10n.t('business.detail.error'),
                  action: l10n.t('business.detail.retry'),
                  onAction: () => ref.invalidate(publicBusinessProvider(businessId)),
                ),
          data: (b) => _Content(business: b, offline: ref.watch(offlineProvider)),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.business, this.offline = false});

  final PublicBusiness business;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final b = business;
    final place = [b.repere, b.zone?.name ?? ''].where((s) => s.isNotEmpty).join(' — ');
    final rows = publicInfoRows(l10n, b);
    return ListView(
      key: const Key('detail-list'),
      padding: const EdgeInsets.all(20),
      children: [
        PhotoGallery(photos: b.photos),
        if (b.photos.isNotEmpty) const SizedBox(height: 16),
        Text(b.name, style: text.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (_typeCodes.contains(b.typeCompte))
              _Chip(l10n.t('business.create.type.${b.typeCompte}'), c.border, c.textSecondary),
            if (b.secteur.isNotEmpty) _Chip(b.secteur, c.border, c.textSecondary),
            if (b.verifie)
              _Chip(l10n.t('business.detail.verified'), AppColors.accent, AppColors.onAccent,
                  key: const Key('detail-verified')),
          ],
        ),
        if (place.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.place_outlined, size: 16, color: c.accentText),
              const SizedBox(width: 6),
              Expanded(child: Text(place, style: TextStyle(fontSize: 13, color: c.accentText))),
            ],
          ),
        ],
        if (b.descriptionActivite.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.t('business.detail.activity'), style: text.titleMedium),
          const SizedBox(height: 4),
          Text(b.descriptionActivite, style: text.bodyMedium),
        ],
        if (b.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.t('business.detail.about'), style: text.titleMedium),
          const SizedBox(height: 4),
          Text(b.description, style: text.bodyMedium),
        ],
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 16),
          PublicInfoSection(rows: rows),
        ],
        const SizedBox(height: 16),
        Text(l10n.t('business.detail.offers'), style: text.titleMedium),
        const SizedBox(height: 8),
        if (b.offers.isEmpty)
          Text(l10n.t('business.detail.offersEmpty'), style: text.bodySmall)
        else
          for (final o in b.offers) ...[OfferTile(offer: o), const SizedBox(height: 10)],
        const SizedBox(height: 12),
        ContactActions(
          businessName: b.name,
          whatsappAvailable: b.whatsappAvailable,
          offline: offline,
          onCall: () => startCall(context, businessId: b.id, businessName: b.name),
          onWhatsapp: () => startWhatsapp(context, businessId: b.id, businessName: b.name),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.background, this.foreground, {super.key});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: foreground)),
      );
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.title, this.body, required this.action, required this.onAction});

  final String title;
  final String? body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: text.titleMedium),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(body!, textAlign: TextAlign.center, style: text.bodyMedium),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('detail-action'),
              onPressed: onAction,
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}
