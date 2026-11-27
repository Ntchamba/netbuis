// Retour facultatif après un appel : POST /api/calls/{id}/feedback/.

/// Résultat de l'appel, tel que l'API l'attend (`outcome`).
enum CallOutcome {
  answered('answered'),
  noAnswer('no_answer'),
  wrongNumber('wrong_number');

  const CallOutcome(this.value);
  final String value;
}
