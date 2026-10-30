import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/phone_formatter.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../application/auth_controller.dart';
import '../../application/auth_state.dart';
import '../widgets/auth_messages.dart';
import '../widgets/auth_page.dart';
import '../widgets/otp_input.dart';
import 'login_screen.dart';

/// Étape 2 de la connexion (maquette Connexion) : code reçu par SMS, en 6 cases.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  AuthCodeSent? _sent;
  Timer? _timer;
  StreamSubscription<String>? _smsSubscription;
  SmsCodeSource? _smsSource;

  /// Secondes restantes avant de pouvoir renvoyer le code.
  int _remaining = 0;

  /// Texte d'erreur affiché ; effacé dès que l'on retape.
  String? _error;

  /// Vrai pendant une vérification (le bouton montre l'attente).
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(authControllerProvider);
    if (current is AuthCodeSent) _setSent(current);
    _listenForSms();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _smsSubscription?.cancel();
    final source = _smsSource;
    if (source != null) unawaited(_stopSms(source));
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _listenForSms() async {
    final source = ref.read(smsCodeSourceProvider);
    _smsSource = source;
    _smsSubscription = source.codes.listen(_onSmsCode, onError: (Object _) {});
    try {
      await source.start();
    } on Object {
      // Lecture automatique indisponible : la saisie à la main reste possible.
    }
  }

  Future<void> _stopSms(SmsCodeSource source) async {
    try {
      await source.stop();
    } on Object {
      // Rien à faire : l'écoute s'arrête avec l'application.
    }
  }

  void _onSmsCode(String raw) {
    if (!mounted) return;
    final code = otpDigitsOf(raw);
    if (!isCompleteOtp(code)) return;
    _controller.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    setState(() => _error = null);
    _verify(code);
  }

  void _setSent(AuthCodeSent sent) {
    _sent = sent;
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _refreshRemaining();
    if (_remaining <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(_refreshRemaining);
      if (_remaining <= 0) timer.cancel();
    });
  }

  void _refreshRemaining() {
    final sent = _sent;
    if (sent == null) {
      _remaining = 0;
      return;
    }
    final left = sent.resendAvailableAt.difference(ref.read(authClockProvider)());
    _remaining = left.isNegative || left == Duration.zero ? 0 : (left.inMilliseconds / 1000).ceil();
  }

  void _verify(String code) {
    if (!isCompleteOtp(code) || _verifying) return;
    if (ref.read(authControllerProvider) is AuthLoading) return;
    setState(() => _verifying = true);
    ref.read(authControllerProvider.notifier).verifyOtp(code);
  }

  void _resend() {
    if (_remaining > 0) return;
    final digits = ref.read(loginPhoneProvider);
    if (!isValidCameroonMobile(digits)) {
      _backToPhone();
      return;
    }
    setState(() => _error = null);
    ref.read(authControllerProvider.notifier).requestOtp('+237$digits');
  }

  void _backToPhone() {
    ref.read(authControllerProvider.notifier).reset();
    context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthCodeSent) {
        // Nouveau code : on repart d'une saisie vide.
        _controller.clear();
        setState(() {
          _error = null;
          _verifying = false;
          _setSent(next);
        });
        _focus.requestFocus();
      } else if (next is AuthFailure) {
        // Code faux ou expiré : la saisie est vidée pour retaper. Réseau coupé : le code reste, on peut réessayer.
        final clear = next.code == ApiErrorCode.otpInvalid || next.code == ApiErrorCode.otpExpired;
        if (clear) _controller.clear();
        setState(() {
          _verifying = false;
          _error = authFailureMessage(l10n, next);
        });
        _focus.requestFocus();
      } else if (next is AuthAuthenticated) {
        setState(() => _verifying = false);
      }
    });

    final auth = ref.watch(authControllerProvider);
    final digits = ref.watch(loginPhoneProvider);
    final masked = maskPhoneDigits(digits);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _backToPhone();
      },
      child: AuthPage(
        onBack: _backToPhone,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeading(
              title: l10n.t('auth.otp.title'),
              subtitle: l10n.t('auth.otp.sent').replaceAll('{phone}', masked),
            ),
            const SizedBox(height: 22),
            OtpInput(
              controller: _controller,
              focusNode: _focus,
              hasError: _error != null,
              onChanged: (value) {
                setState(() => _error = null);
                if (isCompleteOtp(value)) _verify(value);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              AuthErrorText(_error!),
            ],
            const SizedBox(height: 22),
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => PrimaryButton(
                label: l10n.t('auth.otp.submit'),
                loading: _verifying && auth is AuthLoading,
                onPressed: isCompleteOtp(_controller.text) ? () => _verify(_controller.text) : null,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                key: const ValueKey('otp-resend'),
                onPressed: _remaining > 0 || auth is AuthLoading ? null : _resend,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: c.accentText,
                  disabledForegroundColor: c.textSecondary,
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: Text(
                  _remaining > 0
                      ? l10n.t('auth.otp.resendIn').replaceAll('{s}', '$_remaining')
                      : l10n.t('auth.otp.resend'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
