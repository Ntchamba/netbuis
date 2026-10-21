// Une ligne de GET /api/calls/history/ : jamais de numéro, seulement ce que l'écran affiche.

/// Canal d'un contact : appel ou ouverture de WhatsApp.
enum HistoryType { call, whatsapp }

class CallHistoryEntry {
  const CallHistoryEntry({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.zone,
    required this.date,
    required this.type,
    this.feedback,
  });

  final int id;
  final int businessId;
  final String businessName;
  final String zone;
  final DateTime date;
  final HistoryType type;
  final String? feedback;

  /// Lève [FormatException] si la ligne n'a pas la forme du contrat.
  factory CallHistoryEntry.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('ligne inattendue');
    final id = json['id'];
    final businessId = json['business_id'];
    final name = json['business_name'];
    final zone = json['zone'];
    final date = json['date'];
    final type = json['type'];
    final feedback = json['feedback'];
    if (id is! int ||
        businessId is! int ||
        name is! String ||
        zone is! String ||
        date is! String ||
        type is! String) {
      throw const FormatException('ligne incomplète');
    }
    final parsed = DateTime.tryParse(date);
    if (parsed == null) throw const FormatException('date invalide');
    return CallHistoryEntry(
      id: id,
      businessId: businessId,
      businessName: name,
      zone: zone,
      date: parsed.toLocal(),
      type: type == 'whatsapp' ? HistoryType.whatsapp : HistoryType.call,
      feedback: feedback is String ? feedback : null,
    );
  }
}

/// Une page de l'historique (20 lignes).
class CallHistoryPage {
  const CallHistoryPage(
      {required this.count, required this.results, required this.hasNext});

  final int count;
  final List<CallHistoryEntry> results;
  final bool hasNext;

  factory CallHistoryPage.fromJson(Object? data) {
    if (data is! Map) throw const FormatException('page inattendue');
    final results = data['results'];
    final count = data['count'];
    if (results is! List || count is! int) {
      throw const FormatException('page inattendue');
    }
    return CallHistoryPage(
      count: count,
      hasNext: data['next'] != null,
      results: List.unmodifiable(
          [for (final r in results) CallHistoryEntry.fromJson(r)]),
    );
  }
}
