// T103b : gardes de connexion des écrans Aide, À propos, Modifier ma boutique et Historique.
// Les mentions légales sont seules ouvertes sans session (Routes.openLegalPaths) ; /about et /help
// sont donc protégés.
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/router/guards.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/auth/application/auth_state.dart';
import 'package:netbuis/features/auth/presentation/screens/login_screen.dart';
import 'package:netbuis/features/business/presentation/screens/business_edit_screen.dart';
import 'package:netbuis/features/call/presentation/screens/call_history_screen.dart';
import 'package:netbuis/features/settings/presentation/screens/about_screen.dart';
import 'package:netbuis/features/settings/presentation/screens/help_screen.dart';

import '../features/account/account_test_helpers.dart';

const _guarded = [Routes.help, Routes.about, Routes.editBusiness, Routes.callHistory];

void main() {
  test('/about n\'est pas dans les chemins légaux ouverts ; /help non plus', () {
    expect(Routes.openLegalPaths, isNot(contains(Routes.about)));
    expect(Routes.openLegalPaths, isNot(contains(Routes.help)));
  });

  test('la garde mène à la connexion sans session, laisse passer avec session', () {
    for (final path in _guarded) {
      expect(authRedirect(const AuthLoggedOut(), path), Routes.login, reason: path);
      expect(authRedirect(const AuthAuthenticated(), path), isNull, reason: path);
    }
  });

  final screens = <String, Type>{
    Routes.help: HelpScreen,
    Routes.about: AboutScreen,
    Routes.editBusiness: BusinessEditScreen,
    Routes.callHistory: CallHistoryScreen,
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} : sans session, l\'écran de connexion s\'affiche', (tester) async {
      await pumpAccountApp(tester,
          account: ScriptedAccountRepository(me: meWith(name: 'Jeff')),
          initialLocation: entry.key,
          signedIn: false);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(entry.value), findsNothing);
    });

    testWidgets('${entry.key} : avec session, l\'écran s\'ouvre', (tester) async {
      await pumpAccountApp(tester,
          account: ScriptedAccountRepository(me: meWith(name: 'Jeff')),
          initialLocation: entry.key);
      expect(find.byType(entry.value), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });
  }
}
