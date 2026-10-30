// Contrôles de saisie simples
/// Un numéro mobile camerounais saisi sans l'indicatif : 9 chiffres, le premier est 6.
final RegExp _cameroonMobile = RegExp(r'^6\d{8}$');

/// Vrai si [digits] (chiffres seuls, sans espace) est un numéro mobile camerounais complet.
bool isValidCameroonMobile(String digits) => _cameroonMobile.hasMatch(digits);

/// Vrai si la saisie ne peut déjà plus devenir un numéro valide (premier chiffre autre que 6).
bool startsWrongForCameroonMobile(String digits) =>
    digits.isNotEmpty && !digits.startsWith('6');

/// Vrai si [code] est un code de vérification complet : exactement 6 chiffres.
bool isCompleteOtp(String code) => RegExp(r'^\d{6}$').hasMatch(code);
