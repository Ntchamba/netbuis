import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/storage/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('aucune ville au départ', () async {
    expect(await SharedAppPrefs().getCity(), isNull);
  });

  test('la ville enregistrée (id et nom) est relue, et remplaçable', () async {
    final prefs = SharedAppPrefs();
    await prefs.saveCity(const SelectedCity(id: 16, name: 'Maroua'));
    expect(await SharedAppPrefs().getCity(), const SelectedCity(id: 16, name: 'Maroua'));
    await prefs.saveCity(const SelectedCity(id: 30, name: 'Garoua'));
    expect(await prefs.getCity(), const SelectedCity(id: 30, name: 'Garoua'));
  });

  test('une valeur incomplète est ignorée', () async {
    SharedPreferences.setMockInitialValues({SharedAppPrefs.cityIdKey: 4});
    expect(await SharedAppPrefs().getCity(), isNull);
  });
}
