import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/guards.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/core/utils/phone_formatter.dart';
import 'package:netbuis/core/utils/validators.dart';
import 'package:netbuis/features/auth/application/auth_state.dart';
import 'package:netbuis/features/auth/presentation/widgets/otp_input.dart';

void main() {
  group('garde de connexion', () {
    const out = AuthLoggedOut();
    final sent = AuthCodeSent(
      expiresIn: const Duration(minutes: 5),
      expiresAt: _t,
      resendAvailableAt: _t,
    );
    const authed = AuthAuthenticated();

    test('non connecté : un écran protégé mène à la connexion', () {
      for (final path in [Routes.home, Routes.map, Routes.forum, Routes.profile]) {
        expect(authRedirect(out, path), Routes.login, reason: path);
      }
    });

    test('connecté : les écrans protégés restent ouverts', () {
      for (final path in [Routes.home, Routes.map, Routes.forum, Routes.profile]) {
        expect(authRedirect(authed, path), isNull, reason: path);
      }
    });

    test('connecté : la connexion et le code mènent à l\'Accueil', () {
      expect(authRedirect(authed, Routes.login), Routes.home);
      expect(authRedirect(authed, Routes.otp), Routes.home);
    });

    test('Splash et Découverte restent ouverts sans session', () {
      for (final state in [out, sent, authed, const AuthFailure(ApiErrorCode.network)]) {
        expect(authRedirect(state, Routes.splash), isNull);
        expect(authRedirect(state, Routes.onboarding), isNull);
      }
    });

    test('pendant un chargement, aucune redirection (pas de clignotement)', () {
      for (final path in [Routes.home, Routes.login, Routes.otp, Routes.profile]) {
        expect(authRedirect(const AuthLoading(), path), isNull, reason: path);
      }
    });

    test('l\'écran du code n\'est ouvert qu\'après l\'envoi d\'un code', () {
      expect(authRedirect(out, Routes.otp), Routes.login);
      expect(authRedirect(sent, Routes.otp), isNull);
      expect(authRedirect(const AuthFailure(ApiErrorCode.otpInvalid, hasPendingCode: true), Routes.otp), isNull);
    });

    test('un échec n\'ouvre pas les écrans protégés', () {
      expect(authRedirect(const AuthFailure(ApiErrorCode.tooManyRequests), Routes.home), Routes.login);
    });
  });

  group('numéro', () {
    test('format « 6 12 34 56 78 »', () {
      expect(formatPhoneDigits('612345678'), '6 12 34 56 78');
      expect(formatPhoneDigits('6123'), '6 12 3');
      expect(formatPhoneDigits(''), '');
    });

    test('collage avec indicatif et espaces', () {
      expect(phoneDigitsOf('+237 6 12 34 56 78'), '612345678');
      expect(phoneDigitsOf('237612345678'), '612345678');
      expect(phoneDigitsOf('6 12 34 56 78 99'), '612345678');
      expect(phoneDigitsOf('abc'), '');
    });

    test('le formateur ne garde que des chiffres, 9 au plus', () {
      const f = PhoneNumberFormatter();
      final v = f.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '6a1b2c3d4e5f6g7h8i9'),
      );
      expect(v.text, '6 12 34 56 78');
    });

    test('masque : le numéro n\'est jamais montré en entier', () {
      expect(maskPhoneDigits('612345678'), '6•• •• •• 78');
      expect(maskPhoneDigits('6123'), '');
    });

    test('validité : 9 chiffres commençant par 6', () {
      expect(isValidCameroonMobile('612345678'), isTrue);
      expect(isValidCameroonMobile('512345678'), isFalse);
      expect(isValidCameroonMobile('61234567'), isFalse);
      expect(isValidCameroonMobile('6123456789'), isFalse);
      expect(startsWrongForCameroonMobile('5'), isTrue);
      expect(startsWrongForCameroonMobile('6'), isFalse);
      expect(startsWrongForCameroonMobile(''), isFalse);
    });
  });

  group('code', () {
    test('extrait le code d\'un SMS collé', () {
      expect(otpDigitsOf('Votre code NetBuis : 123456. Valable 5 min.'), '123456');
      expect(otpDigitsOf('12 34 56'), '123456');
      expect(otpDigitsOf('12ab34'), '1234');
      expect(otpDigitsOf('1234567890'), '123456');
      expect(otpDigitsOf('abc'), '');
    });

    test('code complet = exactement 6 chiffres', () {
      expect(isCompleteOtp('123456'), isTrue);
      expect(isCompleteOtp('12345'), isFalse);
      expect(isCompleteOtp('1234567'), isFalse);
      expect(isCompleteOtp('12345a'), isFalse);
    });
  });
}

final DateTime _t = DateTime.utc(2026, 1, 1);
