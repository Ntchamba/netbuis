import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/settings/application/settings_controller.dart';
import 'features/settings/data/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Langue et thème choisis lus avant le premier affichage (défauts si le stockage échoue).
  final settings = await SharedSettingsStore().load();
  runApp(ProviderScope(
    overrides: [initialSettingsProvider.overrideWithValue(settings)],
    child: const NetBuisApp(),
  ));
}
