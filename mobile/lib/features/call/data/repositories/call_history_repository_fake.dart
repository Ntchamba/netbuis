// Version factice (USE_FAKE_API) : 25 contacts fictifs (2 pages), dates relatives à maintenant.
// Des appels à l'équipe (sessions) et des liens WhatsApp, comme l'API fusionnée.
import '../models/call_history_entry.dart';
import '../models/call_session.dart';
import 'call_history_repository.dart';

class CallHistoryRepositoryFake implements CallHistoryRepository {
  CallHistoryRepositoryFake({DateTime Function()? now, this.total = 25})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final int total;

  static const int pageSize = 20;
  static const _names = [
    ('Électricien qualifié', 'Hardé'),
    ('Boutique Mama Aïcha', 'Dougoï'),
    ('Couturier Ibrahim', 'Domayo'),
    ('Quincaillerie Hardé', 'Hardé'),
  ];
  static const _states = [
    CallState.ended,
    CallState.missed,
    CallState.unavailable,
    CallState.cancelled,
  ];

  @override
  Future<CallHistoryPage> history({int page = 1}) async {
    final start = (page - 1) * pageSize;
    final end = (start + pageSize).clamp(0, total);
    final now = _now();
    return CallHistoryPage(
      count: total,
      hasNext: end < total,
      results: [
        for (var i = start; i < end; i++)
          if (i % 3 == 1)
            CallHistoryEntry(
              id: 1000 - i,
              businessId: 1 + i % _names.length,
              businessName: _names[i % _names.length].$1,
              zone: _names[i % _names.length].$2,
              date: now.subtract(Duration(hours: 5 + i * 20)),
              type: HistoryType.whatsapp,
            )
          else
            CallHistoryEntry(
              sessionId: '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
              businessId: 1 + i % _names.length,
              businessName: _names[i % _names.length].$1,
              zone: _names[i % _names.length].$2,
              date: now.subtract(Duration(hours: 5 + i * 20)),
              type: HistoryType.call,
              state: _states[i % _states.length],
            ),
      ],
    );
  }
}
