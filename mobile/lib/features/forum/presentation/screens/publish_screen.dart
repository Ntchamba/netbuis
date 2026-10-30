
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/local_image.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/dashed_border.dart';
import '../../../business/data/photo_service.dart' show PhotoSource;
import '../../../merchant/data/repositories/merchant_repository.dart';
import '../../../search/application/offline_controller.dart';
import '../../application/forum_services.dart';
import '../../application/post_publisher.dart';
import '../../data/models/post.dart';
import '../../data/post_media.dart';
import '../../data/repositories/forum_repository.dart';
import '../widgets/active_business_gate.dart';
import '../widgets/offer_choice_sheet.dart';

/// Les 4 façons d'ajouter un média.
enum _MediaChoice { takePhoto, pickPhoto, takeVideo, pickVideo }

/// « Nouvelle publication » (maquette Publier) : photo ou vidéo, légende, produit associé
/// facultatif, bouton Publier. Réservé au compte business actif.
class PublishScreen extends ConsumerStatefulWidget {
  const PublishScreen({super.key});

  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen> {
  final _caption = TextEditingController();
  String? _path;
  PostMediaType? _mediaType;
  MerchantOffer? _offer;
  bool _sending = false;
  PublishStage? _stage;
  String? _errorKey;
  String? _mediaErrorKey;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _chooseMedia() async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showModalBottomSheet<_MediaChoice>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetTile(sheet, 'post-media-camera', Icons.photo_camera_outlined,
                l10n.t('posts.media.takePhoto'), _MediaChoice.takePhoto),
            _sheetTile(
                sheet,
                'post-media-gallery',
                Icons.photo_library_outlined,
                l10n.t('posts.media.pickPhoto'),
                _MediaChoice.pickPhoto),
            _sheetTile(
                sheet,
                'post-media-video-camera',
                Icons.videocam_outlined,
                l10n.t('posts.media.takeVideo'),
                _MediaChoice.takeVideo),
            _sheetTile(
                sheet,
                'post-media-video-gallery',
                Icons.video_library_outlined,
                l10n.t('posts.media.pickVideo'),
                _MediaChoice.pickVideo),
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.close),
              title: Text(l10n.t('business.create.photo.cancel')),
              onTap: () => Navigator.of(sheet).pop(),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final video =
        choice == _MediaChoice.takeVideo || choice == _MediaChoice.pickVideo;
    final camera =
        choice == _MediaChoice.takePhoto || choice == _MediaChoice.takeVideo;
    final String? path;
    try {
      path = await ref.read(postMediaPickerProvider).pick(
          camera ? PhotoSource.camera : PhotoSource.gallery,
          video: video);
    } on Object {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.t('posts.media.pickError'))));
      return;
    }
    if (path == null || !mounted) return;
    try {
      final info = await ref.read(postPublisherProvider).inspect(path);
      if (!mounted) return;
      setState(() {
        _path = path;
        _mediaType = info.type;
        _mediaErrorKey = null;
        _errorKey = null;
      });
    } on PostMediaException catch (e) {
      if (!mounted) return;
      setState(() {
        _path = null;
        _mediaType = null;
        _mediaErrorKey = postErrorKey(e);
      });
    }
  }

  Widget _sheetTile(BuildContext sheet, String key, IconData icon, String label,
          _MediaChoice v) =>
      ListTile(
        key: ValueKey(key),
        minTileHeight: 56,
        leading: Icon(icon),
        title: Text(label),
        onTap: () => Navigator.of(sheet).pop(v),
      );

  Future<void> _chooseOffer() async {
    final choice = await showModalBottomSheet<OfferChoice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => OfferChoiceSheet(selectedId: _offer?.id),
    );
    if (choice != null && mounted) setState(() => _offer = choice.offer);
  }

  bool get _captionTooLong => _caption.text.trim().length > kMaxCaptionLength;

  Future<void> _publish() async {
    final path = _path;
    // Garde synchrone : un second appui, même immédiat, ne lance rien.
    if (_sending || path == null || _captionTooLong) return;
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() {
      _sending = true;
      _stage = PublishStage.uploading;
      _errorKey = null;
    });
    try {
      await ref.read(postPublisherProvider).publish(
            path: path,
            caption: _caption.text,
            offerId: _offer?.id,
            onStage: (s) {
              if (mounted) setState(() => _stage = s);
            },
          );
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.t('posts.published'))));
      if (mounted) router.pop();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _stage = null;
        _errorKey = postErrorKey(e);
      });
    }
  }

  Future<void> _retryConnection() async {
    await ref.read(postPublisherProvider).checkConnection();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final offline = ref.watch(offlineProvider);
    final canPublish =
        _path != null && !_sending && !offline && !_captionTooLong;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: const ValueKey('post-close'),
          tooltip: l10n.t('posts.close'),
          icon: const Icon(Icons.close),
          onPressed: _sending ? null : () => context.pop(),
        ),
        title: Text(l10n.t('posts.new.title'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              key: const ValueKey('post-publish'),
              onPressed: canPublish ? _publish : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: const StadiumBorder(),
              ),
              child: Text(l10n.t('posts.publish'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ActiveBusinessGate(
          builder: (context) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_sending) ...[
                const LinearProgressIndicator(key: ValueKey('post-progress')),
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.t(_stage == PublishStage.publishing
                        ? 'posts.progress.publishing'
                        : 'posts.progress.uploading'),
                    key: const ValueKey('post-stage'),
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_errorKey != null) ...[
                _ErrorText(
                    fieldKey: const ValueKey('post-error'),
                    text: l10n.t(_errorKey!)),
                if (_errorKey == 'posts.error.cap')
                  TextButton(
                    key: const ValueKey('post-see-mine'),
                    onPressed: () => context.pushReplacement(Routes.myPosts),
                    style:
                        TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    child: Text(l10n.t('posts.error.cap.action')),
                  ),
                const SizedBox(height: 16),
              ],
              if (offline) ...[
                _OfflineNote(onRetry: _retryConnection),
                const SizedBox(height: 16),
              ],
              _MediaBox(
                path: _path,
                type: _mediaType,
                enabled: !_sending,
                onTap: _chooseMedia,
              ),
              if (_mediaErrorKey != null) ...[
                const SizedBox(height: 8),
                _ErrorText(
                  fieldKey: const ValueKey('post-media-error'),
                  text: l10n.t(_mediaErrorKey!),
                ),
              ],
              const SizedBox(height: 16),
              Text(l10n.t('posts.caption.label'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('post-caption'),
                controller: _caption,
                enabled: !_sending,
                minLines: 4,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: l10n.t('posts.caption.hint'),
                  filled: true,
                  fillColor: c.card,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_caption.text.trim().length}/$kMaxCaptionLength',
                  key: const ValueKey('post-caption-counter'),
                  style: TextStyle(
                    fontSize: 12,
                    color: _captionTooLong
                        ? Theme.of(context).colorScheme.error
                        : c.textSecondary,
                  ),
                ),
              ),
              if (_captionTooLong)
                _ErrorText(
                  fieldKey: const ValueKey('post-caption-error'),
                  text: l10n.t('posts.error.caption'),
                ),
              const SizedBox(height: 16),
              _OfferRow(
                offer: _offer,
                enabled: !_sending,
                onTap: _chooseOffer,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.t('posts.visibility'),
                key: const ValueKey('post-visibility'),
                style: TextStyle(
                    fontSize: 12, height: 1.5, color: c.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.fieldKey, required this.text});

  final Key fieldKey;
  final String text;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                key: fieldKey,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: error)),
          ),
        ],
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_off_outlined, size: 18, color: c.accentText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.t('posts.offline'),
                    key: const ValueKey('post-offline'),
                    style: TextStyle(
                        fontSize: 13, height: 1.4, color: c.textSecondary)),
              ),
            ],
          ),
        ),
        TextButton(
          key: const ValueKey('post-offline-retry'),
          onPressed: onRetry,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(l10n.t('offline.retry')),
        ),
      ],
    );
  }
}

class _MediaBox extends StatelessWidget {
  const _MediaBox({
    required this.path,
    required this.type,
    required this.enabled,
    required this.onTap,
  });

  final String? path;
  final PostMediaType? type;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = path;
    final Widget content;
    if (p == null) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 30, color: c.textSecondary),
          const SizedBox(height: 10),
          Text(l10n.t('posts.media.add'),
              style: TextStyle(fontSize: 13, color: c.textSecondary)),
        ],
      );
    } else if (type == PostMediaType.video) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_outlined, size: 36, color: c.accentText),
          const SizedBox(height: 10),
          Text(l10n.t('posts.media.videoChosen'),
              key: const ValueKey('post-media-video'),
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(l10n.t('posts.media.change'),
              style: TextStyle(fontSize: 12, color: c.textSecondary)),
        ],
      );
    } else {
      content = Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: localImage(
              p,
              key: const ValueKey('post-media-image'),
              fit: BoxFit.cover,
              cacheWidth: 780,
              errorBuilder: (context, _, __) => Center(
                child: Icon(Icons.image_outlined,
                    size: 36, color: c.textSecondary),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(l10n.t('posts.media.change'),
                    style: const TextStyle(fontSize: 12, color: Colors.white)),
              ),
            ),
          ),
        ],
      );
    }
    return Semantics(
      button: true,
      label: l10n.t(p == null ? 'posts.media.add' : 'posts.media.change'),
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: InkWell(
        key: const ValueKey('post-media'),
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: DashedBorderBox(
          color: dark ? const Color(0xFF3A3A40) : const Color(0xFFC9C9CE),
          background: dark ? const Color(0xFF15151A) : const Color(0xFFEFEFF2),
          radius: 16,
          child: SizedBox(width: double.infinity, height: 220, child: content),
        ),
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow(
      {required this.offer, required this.enabled, required this.onTap});

  final MerchantOffer? offer;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final value = offer?.name ?? l10n.t('posts.offer.noneSelected');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Semantics(
        button: true,
        label: '${l10n.t('posts.offer.label')} : $value',
        excludeSemantics: true,
        onTap: enabled ? onTap : null,
        child: InkWell(
          key: const ValueKey('post-offer'),
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('posts.offer.label'),
                            style: TextStyle(
                                fontSize: 12, color: c.textSecondary)),
                        const SizedBox(height: 2),
                        Text(value,
                            key: const ValueKey('post-offer-value'),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: c.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
