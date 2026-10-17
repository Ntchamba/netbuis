import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';

/// Longueur du code de vérification.
const int otpLength = 6;

/// Extrait le code d'un texte saisi ou collé : un bloc isolé de 6 chiffres s'il y en a un
/// (« Votre code NetBuis : 123456 »), sinon les chiffres du texte, au plus 6.
String otpDigitsOf(String raw) {
  final block = RegExp(r'(?<!\d)\d{6}(?!\d)').firstMatch(raw);
  if (block != null) return block.group(0)!;
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.length > otpLength ? digits.substring(0, otpLength) : digits;
}

/// Formateur : chiffres seuls, 6 au plus, collage d'un SMS entier accepté.
class OtpDigitsFormatter extends TextInputFormatter {
  const OtpDigitsFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = otpDigitsOf(newValue.text);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Source des codes reçus par SMS (lecture automatique), remplaçable dans les tests.
abstract class SmsCodeSource {
  /// Codes lus dans les SMS reçus. Vide si la lecture automatique n'est pas disponible.
  Stream<String> get codes;

  /// Commence à écouter les SMS (sans effet ailleurs que sur Android).
  Future<void> start();

  Future<void> stop();
}

/// Lecture automatique réelle, au-dessus de `sms_autofill`.
class SmsAutofillCodeSource implements SmsCodeSource {
  @override
  Stream<String> get codes => SmsAutoFill().code;

  @override
  Future<void> start() => SmsAutoFill().listenForCode(smsCodeRegexPattern: r'\d{6}');

  @override
  Future<void> stop() => SmsAutoFill().unregisterListener();
}

final smsCodeSourceProvider = Provider<SmsCodeSource>((ref) => SmsAutofillCodeSource());

/// Saisie du code en 6 cases (maquette Connexion, étape code). Un seul vrai champ numérique,
/// posé sur les cases, reçoit la frappe, le collage et la saisie automatique.
class OtpInput extends StatelessWidget {
  const OtpInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.hasError = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool hasError;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return SizedBox(
        height: 56,
        child: Stack(
          children: [
            ListenableBuilder(
              listenable: Listenable.merge([controller, focusNode]),
              builder: (context, _) => _Boxes(
                digits: controller.text,
                focused: focusNode.hasFocus,
                hasError: hasError,
              ),
            ),
            Positioned.fill(
              child: Semantics(
                label: l10n.t('auth.otp.label'),
                child: TextField(
                  key: const ValueKey('otp-field'),
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: const [OtpDigitsFormatter()],
                  showCursor: false,
                  enableSuggestions: false,
                  autocorrect: false,
                  style: const TextStyle(color: Colors.transparent, fontSize: 1),
                  cursorColor: Colors.transparent,
                  decoration: const InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    counterText: '',
                  ),
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
    );
  }
}

class _Boxes extends StatelessWidget {
  const _Boxes({required this.digits, required this.focused, required this.hasError});

  final String digits;
  final bool focused;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final error = Theme.of(context).colorScheme.error;
    return Row(
      children: [
        for (var i = 0; i < otpLength; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              label: l10n
                  .t('auth.otp.digit')
                  .replaceAll('{n}', '${i + 1}')
                  .replaceAll('{total}', '$otpLength'),
              value: i < digits.length ? digits[i] : l10n.t('auth.otp.empty'),
              excludeSemantics: true,
              child: Container(
                key: ValueKey('otp-box-$i'),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasError
                        ? error
                        : (focused && i == digits.length.clamp(0, otpLength - 1))
                            ? c.accentText
                            : c.border,
                    width: focused && i == digits.length.clamp(0, otpLength - 1) ? 2 : 1,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    i < digits.length ? digits[i] : '•',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: i < digits.length ? c.textPrimary : c.border,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
