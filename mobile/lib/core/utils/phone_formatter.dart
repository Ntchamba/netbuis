// Mise en forme de la saisie du numéro
import 'package:flutter/services.dart';

/// Nombre de chiffres d'un numéro mobile camerounais sans l'indicatif.
const int phoneDigitCount = 9;

/// Garde les chiffres d'une saisie ou d'un collage. Un numéro collé avec l'indicatif
/// (« +237 6 12 34 56 78 ») perd son « 237 » ; au plus 9 chiffres sont gardés.
String phoneDigitsOf(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length > phoneDigitCount && digits.startsWith('237')) {
    digits = digits.substring(3);
  }
  return digits.length > phoneDigitCount ? digits.substring(0, phoneDigitCount) : digits;
}

/// « 612345678 » devient « 6 12 34 56 78 » (groupes de 1, 2, 2, 2, 2).
String formatPhoneDigits(String digits) {
  const groups = [1, 2, 2, 2, 2];
  final parts = <String>[];
  var start = 0;
  for (final size in groups) {
    if (start >= digits.length) break;
    final end = start + size > digits.length ? digits.length : start + size;
    parts.add(digits.substring(start, end));
    start = end;
  }
  return parts.join(' ');
}

/// « 612345678 » devient « 6•• •• •• 78 » : le numéro n'est jamais montré en entier.
String maskPhoneDigits(String digits) {
  if (digits.length != phoneDigitCount) return '';
  return '${digits[0]}•• •• •• ${digits.substring(7)}';
}

/// Formateur de champ : chiffres seuls, mis en forme « 6 12 34 56 78 ».
class PhoneNumberFormatter extends TextInputFormatter {
  const PhoneNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = formatPhoneDigits(phoneDigitsOf(newValue.text));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
