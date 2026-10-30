import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../business/presentation/widgets/labeled_text_field.dart';
import '../../application/offers_controller.dart';
import '../../data/repositories/merchant_repository.dart';
import 'photo_picker.dart';

/// Plus grand prix accepté par le serveur.
const int kMaxPriceFcfa = 2000000000;

/// Formulaire d'un produit : nom, description, prix (clavier numérique ; vide = « sur
/// demande »), photos. [onSubmit] n'est appelé que si les champs sont valides.
class OfferForm extends StatefulWidget {
  const OfferForm({
    super.key,
    this.existing,
    required this.saving,
    required this.onSubmit,
    this.errorText,
  });

  final MerchantOffer? existing;
  final bool saving;
  final String? errorText;
  final void Function(
    String name,
    String description,
    int? priceFcfa,
    List<OfferPhoto> photos,
  ) onSubmit;

  @override
  State<OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends State<OfferForm> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late List<OfferPhoto> _photos;
  String? _nameError;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    final o = widget.existing;
    _name = TextEditingController(text: o?.name ?? '');
    _description = TextEditingController(text: o?.description ?? '');
    _price = TextEditingController(text: o?.priceFcfa?.toString() ?? '');
    _photos = [for (final k in o?.photos ?? const <String>[]) OfferPhoto.stored(k)];
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = L10n.of(context);
    final name = _name.text.trim();
    final priceText = _price.text.trim();
    final price = priceText.isEmpty ? null : int.tryParse(priceText);
    setState(() {
      _nameError = name.isEmpty ? l10n.t('offers.form.name.required') : null;
      _priceError = priceText.isNotEmpty && (price == null || price > kMaxPriceFcfa)
          ? l10n.t('offers.form.price.invalid')
          : null;
    });
    if (_nameError != null || _priceError != null) return;
    widget.onSubmit(name, _description.text, price, _photos);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final error = Theme.of(context).colorScheme.error;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        LabeledTextField(
          fieldKey: const ValueKey('offer-name'),
          label: l10n.t('offers.form.name'),
          controller: _name,
          maxLength: 150,
          errorText: _nameError,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),
        LabeledTextField(
          fieldKey: const ValueKey('offer-description'),
          label: l10n.t('offers.form.description'),
          labelSuffix: l10n.t('offers.form.optional'),
          controller: _description,
          maxLength: 1000,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.newline,
          keyboardType: TextInputType.multiline,
        ),
        const SizedBox(height: 16),
        LabeledTextField(
          fieldKey: const ValueKey('offer-price'),
          label: l10n.t('offers.form.price'),
          labelSuffix: l10n.t('offers.form.optional'),
          controller: _price,
          maxLength: 10,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          extraFormatters: [FilteringTextInputFormatter.digitsOnly],
          hintText: l10n.t('offers.form.price.hint'),
          helper: l10n.t('offers.form.price.helper'),
          errorText: _priceError,
        ),
        const SizedBox(height: 16),
        OfferPhotoPicker(
          photos: _photos,
          onChanged: (photos) => setState(() => _photos = photos),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.errorText!,
                    key: const ValueKey('offer-form-error'),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: error),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        PrimaryButton(
          key: const ValueKey('offer-save'),
          label: l10n.t('offers.form.save'),
          loading: widget.saving,
          icon: Icons.check,
          onPressed: _submit,
        ),
      ],
    );
  }
}
