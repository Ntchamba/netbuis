// Une ligne de GET /api/calls/history/ : jamais de numéro, seulement ce que l'écran affiche.
import 'call_session.dart';

/// Canal d'un contact : appel ou ouverture de WhatsApp.
enum HistoryType { call, whatsapp }

class CallHistoryEntry {
  const CallHistoryEntry({
    this.id,
    this.sessionId,
    this.businessId,
    this.businessName,
    this.zone = '',
    required this.date,
    required this.type,
    this.state,
    this.feedback,
  });

  /// Identifiant du journal WhatsApp (ou d'un ancien appel) ; null pour une session d'appel.
  final int? id;

  /// Identifiant de la session d'appel à l'équipe ; null pour un lien WhatsApp.
  final String? sessionId;

  /// Commerce consulté au moment de l'appel (null si l'appel n'en portait pas).
  final int? businessId;
  final String? businessName;
  final String zone;
  final DateTime date;
  final HistoryType type;

  /// État de la session (null pour WhatsApp).
  final CallState? state;
  final String? feedback;

  /// Clé stable de la ligne : `s<session>` ou `w<journal>`.
  String get key => sessionId != null ? 's$sessionId' : 'w$id';

  /// Lève [FormatException] si la ligne n'a pas la forme du contrat
  /// (`session_id` OU `id`, l'autre est null).
  factory CallHistoryEntry.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('ligne inattendue');
    final id = json['id'];
    final sessionId = json['session_id'];
    final businessId = json['business_id'];
    final name = json['business_name'];
    final zone = json['zone'];
    final date = json['date'];
    final type = json['type'];
    final state = json['state'];
    final feedback = json['feedback'];
    if ((id is! int && sessionId is! String) ||
        date is! String ||
        type is! String) {
      throw const FormatException('ligne incomplète');
    }
    final parsed = DateTime.tryParse(date);
    if (parsed == null) throw const FormatException('date invalide');
    return CallHistoryEntry(
      id: id is int ? id : null,
      sessionId: sessionId is String ? sessionId : null,
      businessId: businessId is int ? businessId : null,
      businessName: name is String && name.isNotEmpty ? name : null,
      zone: zone is String ? zone : '',
      date: parsed.toLocal(),
      type: type == 'whatsapp' ? HistoryType.whatsapp : HistoryType.call,
      state: state is String ? CallState.parse(state) : null,
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
