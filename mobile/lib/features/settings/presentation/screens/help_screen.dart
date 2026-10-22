import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../call/data/call_channel.dart';
import '../../application/help_providers.dart';
import '../../data/app_info.dart';
import '../widgets/legal_links.dart';
import '../widgets/listen_button.dart';
import '../widgets/settings_page.dart';

/// « Aide & support » (maquette Aide) : recherche, FAQ en accordéon par thème (une seule question
/// ouverte), 🔊 Écouter sur chaque réponse, contacts du support lus dans la configuration (D-06) et
/// « Signaler un problème ou un compte suspect ».
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  String _query = '';
  String? _openId;
  bool _opened = false;

  String _themeTitle(L10n l10n, FaqTheme theme,
          {required bool credits, required bool team}) =>
      switch (theme) {
        FaqTheme.calls =>
          l10n.t(credits ? 'help.theme.calls' : 'help.theme.calls.noCredits'),
        FaqTheme.business => l10n.t(
            credits ? 'help.theme.business' : 'help.theme.business.noCredits'),
        FaqTheme.security =>
          l10n.t(team ? 'help.theme.security' : 'help.theme.security.safety'),
      };

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openWhatsapp(String link) async {
    final l10n = L10n.of(context);
    WhatsappOpenResult result;
    try {
      result = await ref.read(callChannelProvider).openWhatsapp(link);
    } on Object {
      result = WhatsappOpenResult.failed;
    }
    if (!mounted) return;
    switch (result) {
      case WhatsappOpenResult.opened:
        break;
      case WhatsappOpenResult.notInstalled:
        _snack(l10n.t('help.whatsapp.notInstalled'));
      case WhatsappOpenResult.failed:
        _snack(l10n.t('help.whatsapp.failed'));
    }
  }

  Future<void> _callSupport(String phone) async {
    final l10n = L10n.of(context);
    bool ok;
    try {
      ok = await ref.read(callChannelProvider).dial(phone);
    } on Object {
      ok = false;
    }
    if (!ok && mounted) _snack(l10n.t('help.phone.failed'));
  }

  Future<void> _writeEmail(String address) async {
    final l10n = L10n.of(context);
    bool ok;
    try {
      ok = await ref
          .read(mailLauncherProvider)(Uri(scheme: 'mailto', path: address));
    } on Object {
      ok = false;
    }
    if (!ok && mounted) _snack(l10n.t('help.email.failed'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final credits = ref.watch(creditsEnabledProvider);
    final team = ref.watch(teamEnabledProvider);
    final contact = ref.watch(supportContactProvider);
    final items = visibleFaqItems(credits: credits, team: team);
    if (!_opened) {
      // Comme la maquette : la première question est ouverte au départ.
      _opened = true;
      _openId = items.isEmpty ? null : items.first.id;
    }
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final item in items)
        if (q.isEmpty ||
            l10n.t(item.questionKeyFor(credits: credits)).toLowerCase().contains(q) ||
            l10n
                .t(item.answerKeyFor(credits: credits))
                .toLowerCase()
                .contains(q))
          item
    ];
    final reportLink =
        contact.whatsappLink(message: l10n.t('help.report.message'));

    return SettingsPage(
      title: l10n.t('help.title'),
      children: [
        TextField(
          key: const ValueKey('help-search'),
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: l10n.t('help.search.hint'),
            prefixIcon: const Icon(Icons.search, size: 18),
            filled: true,
            fillColor: c.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: c.border),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text(
              l10n.t('help.search.empty'),
              key: const ValueKey('help-search-empty'),
              style: TextStyle(fontSize: 13.5, color: c.textSecondary),
            ),
          ),
        for (final theme in FaqTheme.values)
          if (shown.any((i) => i.theme == theme)) ...[
            Semantics(
              header: true,
              child: Text(
                _themeTitle(l10n, theme, credits: credits, team: team),
                key: ValueKey('help-theme-${theme.name}'),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: c.accentText),
              ),
            ),
            const SizedBox(height: 10),
            for (final item in shown.where((i) => i.theme == theme))
              _FaqTile(
                key: ValueKey('faq-${item.id}'),
                item: item,
                credits: credits,
                open: _openId == item.id,
                onToggle: () => setState(
                    () => _openId = _openId == item.id ? null : item.id),
              ),
            const SizedBox(height: 10),
          ],
        Divider(height: 28, color: c.border),
        Semantics(
          header: true,
          child: Text(l10n.t('help.contact.title'),
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 10),
        if (!contact.anyAvailable)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              l10n.t('help.contact.soon'),
              key: const ValueKey('help-contact-soon'),
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ),
        _ContactCard(
          key: const ValueKey('contact-whatsapp'),
          icon: '💬',
          title: l10n.t('help.contact.whatsapp'),
          subtitle: contact.whatsappDigits == null
              ? l10n.t('help.contact.soon')
              : l10n.t('help.contact.whatsapp.hint'),
          onTap: contact.whatsappLink() == null
              ? null
              : () => _openWhatsapp(contact.whatsappLink()!),
        ),
        const SizedBox(height: 8),
        _ContactCard(
          key: const ValueKey('contact-phone'),
          icon: '📞',
          title: l10n.t('help.contact.phone'),
          subtitle: contact.phoneNumber == null
              ? l10n.t('help.contact.soon')
              : l10n.t('help.contact.phone.hint'),
          onTap: contact.phoneNumber == null
              ? null
              : () => _callSupport(contact.phoneNumber!),
        ),
        const SizedBox(height: 8),
        _ContactCard(
          key: const ValueKey('contact-email'),
          icon: '✉️',
          title: l10n.t('help.contact.email'),
          subtitle: contact.emailAddress ?? l10n.t('help.contact.soon'),
          onTap: contact.emailAddress == null
              ? null
              : () => _writeEmail(contact.emailAddress!),
        ),
        const SizedBox(height: 18),
        _ReportCard(
          key: const ValueKey('help-report'),
          label: l10n.t('help.report'),
          soon: l10n.t('help.contact.soon'),
          onTap: reportLink == null ? null : () => _openWhatsapp(reportLink),
        ),
        const SizedBox(height: 12),
        const Center(child: LegalLinks()),
        Center(
          child: Text(
            l10n.t('about.version').replaceAll('{version}', appVersion),
            style: TextStyle(fontSize: 10.5, color: c.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile(
      {super.key,
      required this.item,
      required this.credits,
      required this.open,
      required this.onToggle});

  final FaqItem item;
  final bool credits;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final answer = l10n.t(item.answerKeyFor(credits: credits));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: open,
              excludeSemantics: true,
              label: l10n.t(item.questionKeyFor(credits: credits)),
              onTap: onToggle,
              child: InkWell(
                key: ValueKey('faq-toggle-${item.id}'),
                onTap: onToggle,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.t(item.questionKeyFor(credits: credits)),
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(open ? Icons.expand_less : Icons.expand_more,
                            size: 20, color: c.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      answer,
                      key: ValueKey('faq-answer-${item.id}'),
                      style: TextStyle(
                          fontSize: 12.5, height: 1.5, color: c.textSecondary),
                    ),
                    ListenButton(text: answer),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;

  /// `null` : coordonnées pas encore fournies, la carte est grisée et ne fait rien.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      label: '$title. $subtitle',
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: c.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: c.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w600)),
                          Text(subtitle,
                              style: TextStyle(
                                  fontSize: 11.5, color: c.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard(
      {super.key,
      required this.label,
      required this.soon,
      required this.onTap});

  final String label;
  final String soon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      label: enabled ? label : '$label. $soon',
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: AppColors.accent.withValues(alpha: 0.10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.accent.withValues(alpha: 0.35)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Text('🚩', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w600)),
                          if (!enabled)
                            Text(soon,
                                style: TextStyle(
                                    fontSize: 11.5, color: c.textSecondary)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: c.textSecondary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
