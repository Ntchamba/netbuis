import '../../../core/l10n/l10n.dart';

/// « Il y a 2h », « Il y a 3 jours », « Il y a 1 semaine » (textes de la maquette).
/// Au-delà de 5 semaines : la date « 04/03/2026 ».
String postAgo(L10n l10n, DateTime date, DateTime now) {
  final diff = now.difference(date);
  String fill(String key, int n) => l10n.t(key).replaceAll('{n}', '$n');
  if (diff.inMinutes < 1) return l10n.t('posts.ago.now');
  if (diff.inHours < 1) return fill('posts.ago.minutes', diff.inMinutes);
  if (diff.inDays < 1) return fill('posts.ago.hours', diff.inHours);
  if (diff.inDays < 7) {
    return fill(diff.inDays == 1 ? 'posts.ago.day.one' : 'posts.ago.day.other', diff.inDays);
  }
  final weeks = diff.inDays ~/ 7;
  if (weeks < 5) {
    return fill(weeks == 1 ? 'posts.ago.week.one' : 'posts.ago.week.other', weeks);
  }
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}
