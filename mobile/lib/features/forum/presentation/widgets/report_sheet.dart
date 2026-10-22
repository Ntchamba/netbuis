// Feuille « Signaler » (T093). Écran non maquetté : mêmes codes que la feuille d'appel
// (cadre arrondi, gros boutons de 64 px, « Annuler »). Le choix du motif EST la confirmation :
// un toucher envoie. Liste fermée de 4 motifs, aucune saisie libre.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../call/presentation/widgets/call_sheet.dart' show SheetFrame;
import '../../../search/application/offline_controller.dart';
import '../../application/report_controller.dart';
import '../../data/models/report.dart';

/// Ouvre la feuille, puis affiche le message « merci » (ou l'état) selon le résultat.
/// [onRemoved] est appelé quand le contenu signalé ne doit plus être montré (signalé, déjà
/// signalé ou disparu) : par exemple fermer la page de la publication.
Future<void> openReport(
  BuildContext context, {
  required ReportTarget target,
  required int id,
  VoidCallback? onRemoved,
}) async {
  final container = ProviderScope.containerOf(context);
  final l10n = L10n.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (container.read(offlineProvider)) {
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(l10n.t('report.offline'))));
    return;
  }
  final outcome = await showModalBottomSheet<ReportOutcome>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ReportSheet(target: target, id: id),
  );
  if (outcome == null) return;
  final text = switch (outcome) {
    ReportOutcome.done => l10n.t('report.thanks'),
    ReportOutcome.already => l10n.t('report.already.message'),
    ReportOutcome.gone => l10n.t(target == ReportTarget.business
        ? 'report.gone.business'
        : 'report.gone'),
    _ => null,
  };
  if (text != null) {
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(
      key: const Key('report-snack'),
      content: Text(text),
    ));
  }
  final removed = outcome == ReportOutcome.done ||
      outcome == ReportOutcome.already ||
      (outcome == ReportOutcome.gone && target != ReportTarget.business);
  if (removed) onRemoved?.call();
}

class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({super.key, required this.target, required this.id});

  final ReportTarget target;
  final int id;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  bool _sending = false;
  ReportReason? _reason;
  ReportOutcome? _error;

  Future<void> _send(ReportReason reason) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _reason = reason;
      _error = null;
    });
    final outcome = await ref
        .read(reportsProvider.notifier)
        .submit(widget.target, widget.id, reason);
    if (!mounted) return;
    if (outcome == null) return;
    if (outcome == ReportOutcome.network ||
        outcome == ReportOutcome.failed ||
        outcome == ReportOutcome.own) {
      setState(() {
        _sending = false;
        _error = outcome;
      });
      return;
    }
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final error = _error;
    final title = l10n.t('report.title.${widget.target.value}');
    return PopScope(
      canPop: !_sending,
      child: SheetFrame(
        key: const Key('report-sheet'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            if (error == ReportOutcome.own) ...[
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Text(l10n.t('report.error.own'),
                    key: const Key('report-error'),
                    style: TextStyle(fontSize: 14, color: c.textPrimary)),
              ),
              const SizedBox(height: 12),
              TextButton(
                key: const Key('report-close'),
                onPressed: () => Navigator.of(context).pop(error),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: c.textSecondary,
                ),
                child: Text(l10n.t('report.close'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ] else ...[
              Text(l10n.t('report.subtitle'),
                  style: TextStyle(fontSize: 13, color: c.textSecondary)),
              const SizedBox(height: 14),
              if (error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                      l10n.t(error == ReportOutcome.network
                          ? 'report.error.network'
                          : 'report.error.unknown'),
                      key: const Key('report-error'),
                      style: TextStyle(fontSize: 13, color: c.textPrimary)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    key: const Key('report-retry'),
                    onPressed: () => _send(_reason ?? ReportReason.autre),
                    child: Text(l10n.t('profile.retry')),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              for (final reason in ReportReason.values) ...[
                _ReasonButton(
                  key: Key('report-reason-${reason.value}'),
                  reason: reason,
                  label: l10n.t('report.reason.${reason.value}'),
                  busy: _sending && _reason == reason,
                  onTap: _sending ? null : () => _send(reason),
                ),
                const SizedBox(height: 12),
              ],
              TextButton(
                key: const Key('report-cancel'),
                onPressed: _sending ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: c.textSecondary,
                ),
                child: Text(l10n.t('report.cancel'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReasonButton extends StatelessWidget {
  const _ReasonButton({
    super.key,
    required this.reason,
    required this.label,
    required this.onTap,
    required this.busy,
  });

  final ReportReason reason;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: c.background,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.border, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: AppColors.accent),
                    child: busy
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: AppColors.onAccent),
                          )
                        : Icon(reason.icon,
                            size: 20, color: AppColors.onAccent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: onTap == null && !busy
                                ? c.textSecondary
                                : c.textPrimary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
