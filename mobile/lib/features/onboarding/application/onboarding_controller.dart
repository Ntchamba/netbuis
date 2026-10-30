import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/di/providers.dart';

/// Nombre de diapositives de la Découverte (maquette Onboarding).
const int onboardingSlideCount = 5;

/// Clés de texte d'une diapositive.
class OnboardingSlideTexts {
  const OnboardingSlideTexts(this.titleKey, this.bodyKey);

  final String titleKey;
  final String bodyKey;
}

/// Textes des 5 diapositives. La 5ᵉ parle de l'équipe seulement si `teamEnabled`.
List<OnboardingSlideTexts> onboardingSlides({bool teamEnabled = FeatureFlags.teamEnabled}) => [
      const OnboardingSlideTexts('onboarding.slide1.title', 'onboarding.slide1.body'),
      const OnboardingSlideTexts('onboarding.slide2.title', 'onboarding.slide2.body'),
      const OnboardingSlideTexts('onboarding.slide3.title', 'onboarding.slide3.body'),
      const OnboardingSlideTexts('onboarding.slide4.title', 'onboarding.slide4.body'),
      teamEnabled
          ? const OnboardingSlideTexts('onboarding.slide5team.title', 'onboarding.slide5team.body')
          : const OnboardingSlideTexts('onboarding.slide5.title', 'onboarding.slide5.body'),
    ];

/// Numéro de la diapositive affichée (0 à 4).
final onboardingIndexProvider =
    NotifierProvider.autoDispose<OnboardingController, int>(OnboardingController.new);

class OnboardingController extends Notifier<int> {
  @override
  int build() => 0;

  /// Passe à la diapositive suivante ; ne dépasse jamais la dernière.
  void next() {
    if (state < onboardingSlideCount - 1) state = state + 1;
  }

  bool get isLast => state == onboardingSlideCount - 1;

  /// Mémorise que la Découverte a été vue (Passer ou fin).
  Future<void> markSeen() => ref.read(appPrefsProvider).markOnboardingSeen();
}

/// Vrai si la Découverte a déjà été vue.
final onboardingSeenProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.read(appPrefsProvider).isOnboardingSeen(),
);
