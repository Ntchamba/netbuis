import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../application/offers_controller.dart';
import '../../data/repositories/merchant_repository.dart';
import '../widgets/offer_form.dart';

/// Ajout ou modification d'un produit ([existing] absent = ajout). Revient à la liste
/// quand l'enregistrement a réussi ; sinon le formulaire reste rempli avec un message.
class EditOfferScreen extends ConsumerStatefulWidget {
  const EditOfferScreen({super.key, this.existing});

  final MerchantOffer? existing;

  @override
  ConsumerState<EditOfferScreen> createState() => _EditOfferScreenState();
}

class _EditOfferScreenState extends ConsumerState<EditOfferScreen> {
  bool _saving = false;
  String? _errorKey;

  Future<void> _save(
    String name,
    String description,
    int? price,
    List<OfferPhoto> photos,
  ) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errorKey = null;
    });
    try {
      await ref.read(offersProvider.notifier).save(
            existing: widget.existing,
            name: name,
            description: description,
            priceFcfa: price,
            photos: photos,
          );
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorKey = offerErrorKey(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final key = _errorKey;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t(widget.existing == null ? 'offers.add.title' : 'offers.edit.title')),
      ),
      body: SafeArea(
        child: OfferForm(
          existing: widget.existing,
          saving: _saving,
          errorText: key == null ? null : l10n.t(key),
          onSubmit: _save,
        ),
      ),
    );
  }
}
