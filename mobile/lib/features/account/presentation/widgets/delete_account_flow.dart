import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_exception.dart';

/// Suppression du compte avec double confirmation. [onDelete] fait l'appel au serveur et
/// renvoie `null` en cas de succès, sinon l'erreur. Renvoie vrai seulement si le compte est
/// supprimé : l'appelant efface alors jetons et état. Sur une erreur, la seconde fenêtre
/// reste ouverte avec un message clair et rien n'est effacé.
Future<bool> confirmAndDeleteAccount(
  BuildContext context, {
  required Future<ApiException?> Function() onDelete,
}) async {
  final first = await showDialog<bool>(
    context: context,
    builder: (dialog) {
      final l10n = L10n.of(dialog);
      return AlertDialog(
        key: const ValueKey('profile-delete-first'),
        title: Text(l10n.t('profile.delete.first.title')),
        content: Text(l10n.t('profile.delete.first.body')),
        actions: [
          TextButton(
            key: const ValueKey('profile-delete-first-cancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.t('profile.delete.cancel')),
          ),
          TextButton(
            key: const ValueKey('profile-delete-first-continue'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.t('profile.delete.first.continue')),
          ),
        ],
      );
    },
  );
  if (first != true || !context.mounted) return false;
  final second = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => _FinalConfirmDialog(onDelete: onDelete),
  );
  return second == true;
}

class _FinalConfirmDialog extends StatefulWidget {
  const _FinalConfirmDialog({required this.onDelete});

  final Future<ApiException?> Function() onDelete;

  @override
  State<_FinalConfirmDialog> createState() => _FinalConfirmDialogState();
}

class _FinalConfirmDialogState extends State<_FinalConfirmDialog> {
  bool _working = false;
  String? _errorKey;

  Future<void> _confirm() async {
    if (_working) return;
    setState(() {
      _working = true;
      _errorKey = null;
    });
    final error = await widget.onDelete();
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _working = false;
      _errorKey = error.code == ApiErrorCode.network
          ? 'profile.delete.error.network'
          : 'profile.delete.error.unknown';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final errorKey = _errorKey;
    return AlertDialog(
      key: const ValueKey('profile-delete-second'),
      title: Text(l10n.t('profile.delete.second.title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t('profile.delete.second.body')),
          if (_working) ...[
            const SizedBox(height: 12),
            Semantics(
              label: l10n.t('profile.delete.working'),
              liveRegion: true,
              child: const LinearProgressIndicator(),
            ),
          ],
          if (errorKey != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.t(errorKey),
                key: const ValueKey('profile-delete-error'),
                style: TextStyle(fontWeight: FontWeight.w600, color: scheme.error),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('profile-delete-second-cancel'),
          onPressed: _working ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.t('profile.delete.cancel')),
        ),
        TextButton(
          key: const ValueKey('profile-delete-second-confirm'),
          onPressed: _working ? null : _confirm,
          style: TextButton.styleFrom(foregroundColor: scheme.error),
          child: Text(l10n.t('profile.delete.second.confirm')),
        ),
      ],
    );
  }
}
