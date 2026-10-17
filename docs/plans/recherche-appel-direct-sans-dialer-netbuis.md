# Appel direct depuis NetBuis (sans ouvrir le dialer, sans voir le numéro, SIM par défaut) — recherche d'ingénierie

Date : 2026-10-05

## Objectif
Un seul clic sur "Appeler" dans NetBuis lance l'appel immédiatement sur la SIM par défaut, sans ouvrir l'app Téléphone, sans afficher le numéro, sans second clic.

## Résumé
- **Android : faisable** avec `ACTION_CALL` ou `TelecomManager.placeCall()` + permission runtime `CALL_PHONE`. Le numéro n'est jamais affiché (l'écran d'appel du système apparaît ensuite, normal).
- **iOS : impossible avec les API publiques.** Depuis iOS 10.3, tout `tel://` déclenche une confirmation système ("Appeler ce numéro ?"), sans contournement officiel. Les API privées sont refusées à l'App Store.
- Cela **corrige** la décision v1 (`decision-finale-appels.md`) qui écartait `ACTION_CALL` : c'est le seul moyen d'obtenir l'UX voulue sur Android.

## Android — solutions
1. **Intent ACTION_CALL** : `Intent(Intent.ACTION_CALL, Uri.parse("tel:+237..."))`. Demander `CALL_PHONE` à l'exécution (une seule fois). Appel lancé immédiatement sur la SIM par défaut pour les appels sortants.
2. **TelecomManager.placeCall(uri, extras)** (permissions `CALL_PHONE`, + `READ_PHONE_STATE` pour lister les comptes) : permet de choisir la SIM via `EXTRA_PHONE_ACCOUNT_HANDLE`, avec `getDefaultOutgoingPhoneAccount("tel")` pour la SIM par défaut, ou `getCallCapablePhoneAccounts()` pour proposer un choix (ex. SIM Orange / SIM MTN).
3. **Plugins prêts à l'emploi** : React Native — `react-native-immediate-phone-call` ; Flutter — `flutter_phone_direct_caller`, `direct_call_plus` (Android uniquement, peu éprouvés : à tester ou à écrire en Kotlin via MethodChannel, ~20 lignes).
4. **Google Play** : `CALL_PHONE` n'apparaît pas dans la liste des permissions "restreintes" (SMS / Journal d'appels) d'après les pages d'aide Play consultées ; en revanche à déclarer et justifier dans la fiche Play Console (fonction centrale : appeler un commerçant). À revérifier dans la politique complète avant publication.
5. **Bonne pratique** : bouton avec libellé explicite, nom du commerçant visible, éventuel écran de confirmation maison optionnel ; fallback automatique sur `ACTION_DIAL` si la permission est refusée.

## iOS — options réalistes
- `tel://` : confirmation système obligatoire (mesure anti-abus/911, introduite en iOS 10.3, aucune dérogation documentée). Même `CallKit` ne permet pas de lancer un appel cellulaire sans confirmation.
- API privées : possibles techniquement selon un forum Apple, mais rejet/retrait App Store quasi certain. Déconseillé.
- **Contournement légitime** : appel VoIP intégré (Twilio Voice, Agora, etc. via CallKit) = vrai "un clic", mais ce n'est plus un appel opérateur (data, coût par minute, retour à la v2 historique), ou bien WhatsApp (`wa.me`) comme canal alternatif.

## Recommandation
1. **Android (cible principale Cameroun)** : implémenter `ACTION_CALL`/`placeCall` + sélecteur de SIM mémorisé dans les réglages ; fallback `ACTION_DIAL`.
2. **iOS** : garder `tel://` (une confirmation système inévitable) et l'indiquer dans l'UX, ou proposer VoIP/WhatsApp en phase ultérieure.
3. Mettre à jour `decision-finale-appels.md` en conséquence et préparer la justification `CALL_PHONE` pour Play Console.

## Sources
- [TelecomManager — Android Developers](https://developer.android.com/reference/android/telecom/TelecomManager)
- [Declare permissions — Play Console Help](https://support.google.com/googleplay/android-developer/answer/9214102?hl=en)
- [Permissions and APIs that access sensitive information — Play Console Help](https://support.google.com/googleplay/android-developer/answer/16909972?hl=en)
- [Apple Forums — tel:// confirmation iOS 10.3](https://developer.apple.com/forums/thread/73406)
- [Apple Forums — cellular call without confirmation](https://developer.apple.com/forums/thread/748406)
- [flutter_direct_call_plus](https://pub.dev/packages/flutter_direct_call_plus)
- [react-native-immediate-phone-call](https://www.npmjs.com/package/react-native-immediate-phone-call)
