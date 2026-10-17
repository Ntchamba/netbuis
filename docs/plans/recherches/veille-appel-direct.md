# Veille : appel direct sans composeur (passages de vérification)

> Regroupement automatique (2026-10-17) de 212 fichiers de veille produits par les routines du Projet Claude, du plus ancien au plus récent. Historique seulement : en cas de contradiction, `docs/DECISIONS_JEFF.md` et `docs/BACKLOG.md` font foi.


---

<!-- source : recherche-appel-direct-verification-2026-10-05-netbuis.md -->


## Mise à jour de vérification (2026-10-05, 2e passage)
Nouvelle recherche web : conclusions inchangées.
- **iOS** : toujours aucune solution officielle. Un fil du forum Apple Developer (thread 818813, développeur d'app compagnon de lunettes connectées) pose exactement la question « appel cellulaire sans confirmation » et reste sans réponse. Seul Siri / App Intents (action initiée par l'utilisateur via Siri) évite le clic, mais ce n'est pas un bouton dans NetBuis.
- **Google Play** : la page « Preview: Use of SMS or Call Log permission groups » (changement effectif 27 janvier 2027) concerne `READ_CALL_LOG`, `WRITE_CALL_LOG`, `PROCESS_OUTGOING_CALLS`, pas `CALL_PHONE`. Le guide « default handlers » d'Android ne liste pas `CALL_PHONE` comme restreinte. Confirme qu'il faut éviter `READ_CALL_LOG`.
- **Android** : `TelecomManager.placeCall()` + `EXTRA_PHONE_ACCOUNT_HANDLE` reste la méthode documentée pour viser une SIM. Prévoir des tests sur Samsung/Tecno/Infinix/Itel (comportements OEM variables avec le sélecteur double SIM).

Sources : [Apple forum 818813](https://developer.apple.com/forums/thread/818813) · [Play Console — SMS/Call Log preview](https://support.google.com/googleplay/android-developer/answer/17225965?hl=en) · [Android — default handlers](https://developer.android.com/guide/topics/permissions/default-handlers) · [TelecomManager](https://developer.android.com/reference/kotlin/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-netbuis.md -->

# Appel direct sans dialer — vérification du 2026-10-06 (3e passage)

Question : au clic sur « Appeler » dans NetBuis, lancer l'appel directement sur la SIM par défaut (ou choisie), sans ouvrir l'app Téléphone, sans afficher le numéro, sans second clic. Conclusions des passages précédents (voir `decision-finale-appels.md`) : **inchangées**.

## Android — la solution d'ingénierie existe et est officielle
- `TelecomManager.placeCall(Uri, Bundle)` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (un `PhoneAccountHandle`) cible une SIM précise. Permission `CALL_PHONE` (dangereuse, demandée à l'exécution, une seule fois). `Intent.ACTION_CALL` suffit pour la SIM par défaut.
- Lister les SIM : `TelecomManager.getCallCapablePhoneAccounts()` / `SubscriptionManager` (nécessite `READ_PHONE_STATE`), pour faire correspondre « Orange » / « MTN » au bon handle.
- Plugin Flutter `direct_call_plus` (v1.0.4, nov. 2024, MIT) : **n'expose pas** de choix de SIM. Les plugins `flutter_phone_direct_caller` / `flutter_direct_caller_plugin` font l'appel direct mais sans ciblage de SIM. Conclusion : garder le **module Kotlin maison via MethodChannel** (~50 lignes) prévu dans la décision.
- Les ROM Samsung/Tecno/Infinix/Itel peuvent afficher leur propre sélecteur de SIM malgré le handle : à tester sur appareils réels.
- Repli si permission refusée : `ACTION_DIAL`.

## iOS — toujours impossible officiellement
- Fil Apple Developer 748406 : aucune API publique ne permet d'initier un appel cellulaire sans confirmation ; CallKit n'est destiné qu'aux apps VoIP ; `CTCallCenter` ne fait que lire l'état ; les API privées = rejet App Store.
- Fil 818813 (compagnon de lunettes) : toujours sans réponse.
- Seuls contournements légitimes : Siri / App Intents (action vocale ou raccourci, pas un bouton dans l'app) ou passer en VoIP/WhatsApp (plus un appel opérateur).

## Recommandation (inchangée)
Android : appel direct par `placeCall` + choix Orange/MTN (v2.1). iOS : `tel://` avec confirmation système, acceptée pour le MVP. Rappel : « sans voir le numéro » ne vaut que pour l'interface NetBuis ; l'écran d'appel système et le journal d'appels l'affichent.

## Sources
[TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Apple forum 748406](https://developer.apple.com/forums/thread/748406) · [Apple forum 818813](https://developer.apple.com/forums/thread/818813) · [direct_call_plus](https://pub.dev/packages/direct_call_plus) · [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage4-netbuis.md -->

# Appel direct sans dialer — 4e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** par rapport à `decision-finale-appels.md` (v2.1) et au 3e passage du même jour.

## Nouveau vérifié aujourd'hui
- **Google Play, politique SMS / Journal d'appels** (annonce du 15 juillet 2026, aperçu du groupe de permissions) : le groupe « Call Log » = `READ_CALL_LOG`, `WRITE_CALL_LOG`, `PROCESS_OUTGOING_CALLS`. Le changement (effectif 27 janvier 2027 pour l'aperçu) supprime la vérification de compte par appel comme cas d'usage de `READ_CALL_LOG`. **`CALL_PHONE` n'est pas dans ce groupe** : l'appel direct par `ACTION_CALL` / `TelecomManager.placeCall` n'est donc pas visé. Cela lève la réserve « à revérifier avant publication » de la décision, au moins pour l'état actuel de la politique (revérifier juste avant la soumission).
- Confirmation : ne pas demander `READ_CALL_LOG` (déjà exclu dans la décision).
- **iOS** : aucune nouvelle API trouvée ; fils Apple 748406 et 818813 toujours sans solution officielle. `tel://` avec confirmation système reste la seule voie.
- **Android 16 / TelecomManager** : aucune documentation indiquant une restriction nouvelle de `placeCall` / `ACTION_CALL`.

## Recommandation (inchangée)
Android : `placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE` via module Kotlin (MethodChannel), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système.

## Sources
[Play Console — aperçu SMS/Call Log](https://support.google.com/googleplay/android-developer/answer/17225965?hl=en) · [Play Console — annonce 15 juillet 2026](https://support.google.com/googleplay/android-developer/answer/17134731) · [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Apple forum 748406](https://developer.apple.com/forums/thread/748406) · [Apple forum 818813](https://developer.apple.com/forums/thread/818813)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage5-netbuis.md -->

# Appel direct sans dialer — 5e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** par rapport à `decision-finale-appels.md` (v2.1) et aux passages 1 à 4.

## Vérifié aujourd'hui
- **Plugins Flutter d'appel direct** : `direct_call_plus` (v1.0.4, nov. 2024, éditeur non vérifié) et `flutter_direct_caller_plugin` (v0.0.4, fév. 2025) lancent un appel sans dialer, mais **leur documentation ne mentionne aucun choix de SIM / PhoneAccountHandle**. Ils sont peu maintenus. Cela confirme la décision : **module Kotlin maison via MethodChannel** (`TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE`) pour viser la ligne Orange ou MTN choisie.
- **iOS** : aucune nouvelle API d'appel direct. Les nouveautés iOS 26 (appels cellulaires par apps tierces) concernent uniquement l'UE ; iOS 27 « Call Context » est une fonction d'affichage d'infos pendant les appels professionnels, sans effet sur la confirmation `tel://`. Pas de solution pour supprimer la confirmation système.
- **Android 16 / TelecomManager** : toujours aucune restriction documentée sur `placeCall` / `ACTION_CALL` avec `CALL_PHONE`.

## Recommandation (inchangée)
Android : module Kotlin `placeCall` + choix de SIM, permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système (numéro visible, choix de SIM impossible).

## Sources
[direct_call_plus](https://pub.dev/packages/direct_call_plus) · [flutter_direct_caller_plugin](https://pub.dev/packages/flutter_direct_caller_plugin) · [MacRumors — iOS 26 UE](https://www.macrumors.com/2025/07/08/ios-26-third-party-cellular-phone-message-apps-eu/) · [Call Context iOS 27](https://applemagazine.com/call-context-ios-27-business-calls/) · [TelecomManager](https://developer.android.com/reference/kotlin/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage6-netbuis.md -->

# Appel direct sans dialer — 6e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** par rapport à `decision-finale-appels.md` (v2.1) et aux passages 1 à 5. Aucune nouveauté trouvée.

## Vérifié aujourd'hui
- **Android (Android 16 / 17)** : recherche sur d'éventuelles restrictions de `ACTION_CALL` / `CALL_PHONE` / `TelecomManager.placeCall` : aucun résultat nouveau ni changement documenté.
- **Flutter** : les paquets d'appel direct (`flutter_phone_direct_caller`, `direct_call`, etc.) lancent l'appel sans dialer mais ne documentent pas le choix de SIM par `PhoneAccountHandle`. Le projet open source `DualSimDialer` (GitHub, jaggerjack61) est une piste de référence pour le code Kotlin double SIM, à examiner avant d'écrire le module maison. Décision inchangée : module Kotlin via MethodChannel.
- **iOS** : les forums Apple (« Can we do cellular call without user confirmation? », « Why does openURL tel:// require user confirm ») confirment toujours qu'aucun moyen officiel de supprimer la confirmation système n'existe.

## Recommandation (inchangée)
Android : `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE`, permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système.

## Sources
[flutter_phone_direct_caller](https://fluttergems.dev/packages/flutter_phone_direct_caller/) · [direct_call](https://pub.dev/packages/direct_call) · [DualSimDialer](https://github.com/jaggerjack61/DualSimDialer) · [Apple Forums — appel sans confirmation](https://developer.apple.com/forums/thread/748406) · [Apple Forums — tel:// confirmation](https://developer.apple.com/forums/thread/73406)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage7-netbuis.md -->

# Appel direct sans dialer — 7e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` v2.1 et passages 1 à 6). Rien de nouveau.

## Vérifié
- **Android 17 / CALL_PHONE / placeCall** : nouvelle recherche, aucune restriction ni changement documenté. La doc `TelecomManager` reste la référence.
- **Politique Google Play du 15 juillet 2026** : ne concerne que `READ_CALL_LOG` / SMS (la vérification de compte par appel n'est plus un motif valable). **Sans impact pour NETBUIS** : l'app n'utilise ni `READ_CALL_LOG` ni SMS ; elle demande seulement `CALL_PHONE` + `READ_PHONE_STATE`. Point de vigilance : ne jamais ajouter `READ_CALL_LOG`.
- Un exemple open source supplémentaire de « placer l'appel au lieu d'ouvrir le dialer » (PR colonelpanic8/eva #14) confirme le schéma `ACTION_CALL` / `placeCall`.

## Recommandation (inchangée)
Android : `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut choisie), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système obligatoire (aucun contournement officiel).

## Sources
[Policy announcement 15 juillet 2026](https://support.google.com/googleplay/android-developer/answer/17134731) · [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [PR eva #14](https://github.com/colonelpanic8/eva/pull/14) · [Dual-SIM Flutter](https://medium.com/easy-flutter/unlock-dual-sim-power-in-flutter-build-smarter-android-apps-for-global-markets-7f99bc78d21a)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage8-netbuis.md -->

# Appel direct sans dialer — 8e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` v2.1 et passages 1 à 7). Rien de nouveau.

## Vérifié
- **Android** : recherches sur `TelecomManager.placeCall` + `PhoneAccountHandle` (double SIM) et sur Android 17 / `CALL_PHONE` : aucune restriction ni changement nouveau. La doc `TelecomManager` reste la référence ; le PR eva #14 (placer l'appel au lieu d'ouvrir le dialer) confirme le schéma.
- **iOS** : forums Apple (fils 73406, 106147, 748406, 685230) — la confirmation système « Appeler ce numéro ? » pour `tel://` reste obligatoire ; CallKit ne permet pas d'appel cellulaire sans confirmation. Aucun contournement officiel.

## Recommandation (inchangée)
Android : `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE`, permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système.

## Sources
[TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [PR eva #14](https://github.com/colonelpanic8/eva/pull/14) · [Apple forums 748406](https://developer.apple.com/forums/thread/748406) · [Apple forums 73406](https://developer.apple.com/forums/thread/73406)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage9-netbuis.md -->

# Appel direct sans dialer — 9e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` v2.1 et passages 1 à 8). Rien de nouveau.

## Vérifié
- Recherches « TelecomManager.placeCall + PhoneAccountHandle » et « React Native direct call dual SIM » : mêmes sources que précédemment (doc TelecomManager, PR eva #14, `react-native-immediate-phone-call`, `expo-direct-call`, fil Apple 679119). Aucune nouvelle API ni restriction.
- `expo-direct-call` (aguglie) : plugin supplémentaire d'appel direct Android, sans choix de SIM documenté ; ne change pas la décision (module Kotlin maison).

## Recommandation (inchangée)
Android : `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE`, permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système obligatoire.

## Sources
[TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [PR eva #14](https://github.com/colonelpanic8/eva/pull/14) · [expo-direct-call](https://github.com/aguglie/expo-direct-call) · [react-native-immediate-phone-call](https://www.npmjs.com/package/react-native-immediate-phone-call) · [Apple forums 679119](https://developer.apple.com/forums/thread/679119)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage10-netbuis.md -->

# Appel direct sans dialer — 10e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` v2.1 et passages 1 à 9). Aucune nouvelle API, restriction ni bibliothèque.

## Vérifié
- Recherche « TelecomManager.placeCall + PhoneAccountHandle » : mêmes sources (doc TelecomManager, guide « default phone application », doc Microsoft placeCall).
- Recherche « React Native direct call dual SIM » : mêmes bibliothèques (`expo-direct-call`, `react-native-immediate-phone-call`, `react-native-phone-call`).

## Recommandation (inchangée)
Android : `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système obligatoire.

## Sources
[TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Default phone app](https://developer.android.com/develop/connectivity/telecom/dialer-app) · [expo-direct-call](https://github.com/aguglie/expo-direct-call) · [react-native-immediate-phone-call](https://www.npmjs.com/package/react-native-immediate-phone-call)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage11-netbuis.md -->

# Appel direct sans dialer — 11e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` v2.1 et passages 1 à 10). Aucune nouvelle API, restriction (Android 17 QPR2 inclus) ni bibliothèque.

## Vérifié
- Recherche « Android 17 CALL_PHONE placeCall restriction » : seules les sources déjà connues remontent (doc TelecomManager, guide « default phone app », release notes Android 17 QPR2 sans mention de restriction sur CALL_PHONE).

## Recommandation (inchangée)
Android : `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système obligatoire (pas de contournement possible).

## Sources
[TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Default phone app](https://developer.android.com/develop/connectivity/telecom/dialer-app) · [Android 17 QPR2 release notes](https://developer.android.com/about/versions/17/qpr2/release-notes)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage12-netbuis.md -->

# Appel direct sans dialer — 12e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` v2.1 et passages 1 à 11). Aucune nouvelle API, restriction ni bibliothèque.

## Vérifié
- Recherche « TelecomManager placeCall direct call CALL_PHONE restriction 2026 » : mêmes sources (doc TelecomManager, doc Microsoft placeCall, commit AOSP).
- Recherche « React Native direct call SIM » : mêmes bibliothèques (`expo-direct-call`, `react-native-immediate-phone-call`, `react-native-phone-call`).

## Recommandation (inchangée)
Android : `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système obligatoire.

## Sources
[TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [expo-direct-call](https://github.com/aguglie/expo-direct-call) · [react-native-immediate-phone-call](https://www.npmjs.com/package/react-native-immediate-phone-call)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage13-netbuis.md -->

# Appel direct sans dialer — 13e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` v2.1 et passages 1 à 12). Aucune nouvelle API, restriction Android 17 ni bibliothèque.

## Vérifié
- « TelecomManager placeCall ... Android 17 2026 » : mêmes sources (doc TelecomManager, guide default dialer, blog Telecom VoIP alpha mai 2026 — hors sujet : VoIP).
- « React Native direct phone call default SIM » : mêmes bibliothèques (`expo-direct-call`, `react-native-immediate-phone-call`, `react-native-phone-call`, `react-native-callkeep` — VoIP).

## Recommandation (inchangée)
Android : `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système obligatoire.

## Sources
[TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [expo-direct-call](https://github.com/aguglie/expo-direct-call) · [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage14-netbuis.md -->

# Appel direct sans dialer — 14e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` v2.1 et passages 1 à 13). Aucune nouvelle API, restriction Android 17 ni bibliothèque.

## Vérifié
- « TelecomManager placeCall default SIM CALL_PHONE 2026 » : seulement doc Android (TelecomManager, InCallService) et tutoriels génériques ; rien de nouveau.
- « Android 17 CALL_PHONE ACTION_CALL restriction change » : aucune restriction annoncée ; résultats hors sujet (CVE, bloqueurs d'appels).

## Recommandation (inchangée)
Android : `TelecomManager.placeCall` (ou `ACTION_CALL`) + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système obligatoire (non contournable).

## Sources
[TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [InCallService](https://developer.android.com/reference/android/telecom/InCallService) · [Android Dial Phone Programmatically](https://itnext.io/android-dial-phone-programmatically-5ea3714d801d)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage15-netbuis.md -->

# Appel direct sans dialer — 15e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` v2.1 et passages 1 à 14). Aucune nouvelle API ni restriction.

## Vérifié
- « Android 17 ACTION_CALL CALL_PHONE permission change » : aucune restriction annoncée ; seulement tutoriels génériques.
- « react native direct call without dialer default SIM » : paquets déjà connus (react-native-immediate-phone-call, react-native-phone-call, direct_caller_sim_choice, direct_call_plus pour Flutter) ; rien de nouveau.

## Recommandation (inchangée)
Android : `TelecomManager.placeCall` (ou `ACTION_CALL`) + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système obligatoire (non contournable).

## Sources
[react-native-immediate-phone-call](https://www.jsdelivr.com/package/npm/react-native-immediate-phone-call) · [direct_caller_sim_choice](https://pub-web-s2.flutter-io.cn/packages/direct_caller_sim_choice/versions/1.0.3) · [direct_call_plus](https://pub.dev/documentation/direct_call_plus/latest/)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage16-netbuis.md -->

# Appel direct sans dialer — 16e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` v2.1 et passages 1 à 15). Aucune nouvelle API ni restriction.

## Vérifié
- Recherche « Android CALL_PHONE ACTION_CALL restriction Play Console policy 2026 » : seules les pages de politique Play déjà connues (permissions Appels/SMS) ; aucune nouveauté.

## Recommandation (inchangée)
Android : `TelecomManager.placeCall` (ou `ACTION_CALL`) + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système obligatoire (non contournable).

## Sources
[Play Console – politique permissions](https://support.google.com/googleplay/android-developer/answer/9047303) · [Play Console – answer 16909972](https://support.google.com/googleplay/android-developer/answer/16909972)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage17-netbuis.md -->

# Appel direct sans dialer — 17e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` v2.1 et passages 1 à 16). Aucune nouvelle API ni restriction.

## Vérifié
- « TelecomManager placeCall CALL_PHONE PhoneAccountHandle » : documentation Android Telecom/PhoneAccount, rien de nouveau.
- « React Native direct call without dialer » : paquets connus (`react-native-immediate-phone-call`, `react-native-phone-call`, Flutter `direct_caller_sim_choice`) — tous reposent sur `ACTION_CALL` + `CALL_PHONE`, Android uniquement.

## Recommandation (inchangée)
Android : `TelecomManager.placeCall` (ou `ACTION_CALL`) + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système obligatoire (non contournable).

## Sources
[Android Telecom](https://developer.android.com/develop/connectivity/telecom) · [PhoneAccount](https://developer.android.com/reference/kotlin/android/telecom/PhoneAccount) · [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call) · [direct_caller_sim_choice](https://pub-web-s2.flutter-io.cn/packages/direct_caller_sim_choice/versions/1.0.3)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage18-netbuis.md -->

# Appel direct sans dialer — 18e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 17). Aucune nouvelle API ni restriction trouvée.

## Vérifié
- « Android 17 CALL_PHONE placeCall direct call » : seulement documentation TelecomManager et tutoriels ACTION_CALL / flutter_phone_dialer, rien de nouveau.
- « Google Play policy 2026 CALL_PHONE » : la politique Play restreint SMS / Call Log ; CALL_PHONE n'est pas dans le groupe restreint (déjà noté aux passages précédents).

## Recommandation (inchangée)
Android : `TelecomManager.placeCall` (ou `ACTION_CALL`) + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système obligatoire (non contournable).

## Sources
[TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Play policy](https://support.google.com/googleplay/android-developer/answer/17225965) · [flutter_phone_dialer](https://pub.dev/packages/flutter_phone_dialer)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage19-netbuis.md -->

# Appel direct sans dialer — 19e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 18). Aucune nouvelle API ni restriction trouvée.

## Vérifié
- « TelecomManager placeCall PhoneAccountHandle SIM selection 2026 » : documentation Android Telecom, redirection d'appel (Android 10+), commits AOSP/OmniROM sur la SIM préférée pour ACTION_CALL — rien de nouveau.
- « Android 17 behavior changes CALL_PHONE ACTION_CALL » : pages de changements de comportement Android 17 et QPR2 beta 3 (protection contre la fraude par renvoi d'appel) ; aucune restriction de CALL_PHONE / ACTION_CALL.

## Recommandation (inchangée)
Android : `TelecomManager.placeCall` (ou `ACTION_CALL`) + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système obligatoire (non contournable).

## Sources
[Android Telecom](https://developer.android.com/develop/connectivity/telecom) · [Redirect a call](https://developer.android.com/develop/connectivity/telecom/dialer-app/redirect-a-call) · [Android 17 behavior changes](https://developer.android.com/about/versions/17/behavior-changes-all?hl=en) · [Android 17 QPR2 beta 3](https://9to5google.com/2026/08/14/android-17-qpr2-beta-3-everything-new/)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage20-netbuis.md -->

# Appel direct sans dialer — 20e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 19). Aucune nouvelle API ni restriction.

## Vérifié
- TelecomManager.placeCall / ACTION_CALL / SIM par défaut : seule la doc Android officielle ressort, rien de nouveau.
- React Native : `react-native-immediate-phone-call`, `react-native-phone-call`, `direct_call_plus` (Flutter) — wrappers d'ACTION_CALL sur Android, déjà connus.

## Recommandation (inchangée)
Android : `TelecomManager.placeCall` (ou `ACTION_CALL`) + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système obligatoire (non contournable).

## Sources
[TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call) · [direct_call_plus](https://pub.dev/documentation/direct_call_plus/latest/)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage21-netbuis.md -->

# Appel direct sans dialer — 21e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 20). Aucune nouvelle API ni restriction détectée.

## Vérifié
- Recherche « TelecomManager placeCall / SIM par défaut / PhoneAccountHandle » : uniquement la doc Android officielle (TelecomManager, PhoneAccount, framework Telecom) et un commit Dialer AOSP sur la gestion de la SIM préférée pour ACTION_CALL. Rien de nouveau.

## Recommandation (inchangée)
Android : `TelecomManager.placeCall` (ou `ACTION_CALL`) + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système obligatoire (non contournable).

## Sources
[TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Telecom framework](https://developer.android.com/develop/connectivity/telecom) · [PhoneAccount](https://developer.android.google.cn/reference/android/telecom/PhoneAccount?hl=bg)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage22-netbuis.md -->

# Appel direct sans dialer — 22e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 21). Aucune nouvelle API ni restriction détectée ; les résultats de recherche sont les mêmes que le passage 21.

## Recommandation (inchangée)
Android : `TelecomManager.placeCall` (ou `ACTION_CALL`) + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système obligatoire (non contournable).

## Sources
[TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Telecom framework](https://developer.android.com/develop/connectivity/telecom) · [PhoneAccount](https://developer.android.google.cn/reference/android/telecom/PhoneAccount?hl=bg)


---

<!-- source : recherche-appel-direct-verification-2026-10-06-passage23-netbuis.md -->

# Appel direct sans dialer — 23e passage (2026-10-06, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 22). Aucune nouvelle API ni restriction affectant `CALL_PHONE` / `ACTION_CALL` / `TelecomManager.placeCall`.

## Seule précision (non bloquante)
La politique Google Play d'avril 2026 sur les permissions d'appels/SMS (effective le **27 janvier 2027**) vise `READ_CALL_LOG`, `WRITE_CALL_LOG`, `PROCESS_OUTGOING_CALLS` (réservées aux apps handler Téléphone/Assistant par défaut). `CALL_PHONE` n'est pas mentionnée. => NETBUIS ne doit **pas** demander les permissions de journal d'appels ; `CALL_PHONE` + `READ_PHONE_STATE` suffisent.

## Recommandation (inchangée)
Android : `TelecomManager.placeCall` (ou `ACTION_CALL`) + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. iOS : `tel://` avec confirmation système obligatoire (non contournable).

## Sources
[TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Play policy permissions SMS/appels](https://support.google.com/googleplay/android-developer/answer/16909972) · [Android Developers Blog avril 2026](https://android-developers.googleblog.com/2026/04/giving-users-clearer-choice-and-everyone-a-safer-more-trusted-app-ecosystem.html)


---

<!-- source : recherche-appel-direct-verification-2026-10-07-passage24-netbuis.md -->

# Appel direct sans dialer — 24e passage (2026-10-07, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 23). Deux recherches de contrôle (politique Google Play / CALL_PHONE ; libs React Native `react-native-immediate-phone-call`, `PhoneAccountHandle`) : aucune nouvelle API, aucune nouvelle restriction sur `CALL_PHONE` / `ACTION_CALL` / `TelecomManager.placeCall`.

## Rappel de la recommandation
- Android : `TelecomManager.placeCall` (ou `ACTION_CALL`) + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. Ne pas demander `READ_CALL_LOG` / `WRITE_CALL_LOG` / `PROCESS_OUTGOING_CALLS` (politique Play effective 27 janv. 2027).
- iOS : `tel://` avec confirmation système obligatoire (non contournable) ; alternative Twilio/VoIP si besoin.

## Sources
[Android Developers Blog avril 2026](https://android-developers.googleblog.com/2026/04/giving-users-clearer-choice-and-everyone-a-safer-more-trusted-app-ecosystem.html) · [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call) · [PhoneAccount](https://developer.android.com/reference/kotlin/android/telecom/PhoneAccount)


---

<!-- source : recherche-appel-direct-verification-2026-10-07-passage25-netbuis.md -->

# Appel direct sans dialer — 25e passage (2026-10-07, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 24). Deux recherches de contrôle (politique Google Play / CALL_PHONE / ACTION_CALL ; libs React Native + PhoneAccountHandle / TelecomManager.placeCall) : aucun résultat nouveau, aucune nouvelle API, aucune nouvelle restriction.

## Rappel de la recommandation
- Android : `TelecomManager.placeCall` (ou `ACTION_CALL`) + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. Éviter `READ_CALL_LOG` / `WRITE_CALL_LOG` / `PROCESS_OUTGOING_CALLS`.
- iOS : `tel://` avec confirmation système obligatoire (non contournable) ; alternative VoIP/Twilio.

## Sources
[PhoneAccount](https://developer.android.com/reference/kotlin/android/telecom/PhoneAccount) · [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-07-passage26-netbuis.md -->

# Appel direct sans dialer — 26e passage (2026-10-07, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 25). Deux recherches de contrôle (TelecomManager.placeCall / ACTION_CALL / PhoneAccountHandle / politique Play ; libs React Native d'appel direct) : aucune nouvelle API ni restriction.

## Rappel de la recommandation
- Android : `TelecomManager.placeCall` (ou `ACTION_CALL`) + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. Lib RN existante : react-native-immediate-phone-call. Éviter `READ_CALL_LOG` / `WRITE_CALL_LOG` / `PROCESS_OUTGOING_CALLS`.
- iOS : `tel://` avec confirmation système obligatoire (non contournable) ; alternative VoIP/Twilio.

## Sources
[TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call)


---

<!-- source : recherche-appel-direct-verification-2026-10-07-passage27-netbuis.md -->

# Appel direct sans dialer — 27e passage (2026-10-07, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 26). Deux recherches de contrôle (TelecomManager.placeCall / PhoneAccountHandle / CALL_PHONE ; libs d'appel direct RN/Flutter) : aucune nouvelle API ni restriction.

## Rappel
- Android : `TelecomManager.placeCall` (ou `ACTION_CALL`) + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. Lib RN : react-native-immediate-phone-call. Équivalents Flutter : direct_call_plus, direct_caller_sim_choice, flutter_direct_caller_plugin.
- iOS : `tel://` avec confirmation système obligatoire (non contournable) ; alternative VoIP/Twilio.

## Sources
[Telecom framework](https://developer.android.com/develop/connectivity/telecom) · [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call) · [direct_call_plus](https://fluttergems.dev/packages/direct_call_plus/)


---

<!-- source : recherche-appel-direct-verification-2026-10-07-passage28-netbuis.md -->

# Appel direct sans dialer — 28e passage (2026-10-07, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 27). Deux recherches de contrôle (restrictions Android CALL_PHONE/ACTION_CALL ; libs d'appel direct RN/Flutter avec choix de SIM) : aucune nouvelle API ni restriction.

## Rappel
- Android : `TelecomManager.placeCall` (ou `ACTION_CALL`) + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. Lib RN : react-native-immediate-phone-call. Flutter : direct_call_plus, direct_caller_sim_choice, flutter_direct_caller_plugin.
- iOS : `tel://` avec confirmation système obligatoire (non contournable) ; alternative VoIP/Twilio.

## Sources
[react-native-immediate-phone-call](https://www.jsdelivr.com/package/npm/react-native-immediate-phone-call) · [direct_call_plus](https://pub.dev/documentation/direct_call_plus/latest/) · [direct_caller_sim_choice](https://pub-web-s2.flutter-io.cn/packages/direct_caller_sim_choice/versions/1.0.3)


---

<!-- source : recherche-appel-direct-verification-2026-10-07-passage29-netbuis.md -->

# Appel direct sans dialer — 29e passage (2026-10-07, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 28). Deux recherches de contrôle (doc TelecomManager / CALL_PHONE ; plugins Flutter/RN d'appel direct) : aucune nouvelle API ni restriction détectée.

## Rappel
- Android : `TelecomManager.placeCall` (ou `ACTION_CALL`) + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. Lib RN : react-native-immediate-phone-call. Flutter : direct_call_plus (1.0.4), flutter_direct_caller_plugin (0.0.4), direct_caller_sim_choice.
- iOS : `tel://` avec confirmation système obligatoire (non contournable) ; alternative VoIP/Twilio.

## Sources
[TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [direct_call_plus](https://pub.dev/documentation/direct_call_plus/latest/) · [flutter_direct_caller_plugin](https://pub-web-s1.flutter-io.cn/packages/flutter_direct_caller_plugin)


---

<!-- source : recherche-appel-direct-verification-2026-10-07-passage30-netbuis.md -->

# Appel direct sans dialer — 30e passage (2026-10-07, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 29). Deux recherches de contrôle (restrictions Play Store / CALL_PHONE / TelecomManager ; plugins Flutter d'appel direct) : aucune nouvelle API ni restriction. Les résultats Play Store concernent les permissions SMS/Journal d'appels et l'enregistrement d'appels, pas CALL_PHONE pour lancer un appel.

## Rappel
- Android : `TelecomManager.placeCall` / `ACTION_CALL` + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. Flutter : direct_call_plus 1.0.4, flutter_direct_caller_plugin 0.0.4, direct_caller_sim_choice 1.0.3.
- iOS : `tel://` avec confirmation système obligatoire ; alternative VoIP/Twilio.

## Sources
[direct_call_plus](https://pub.dev/documentation/direct_call_plus/latest/) · [Play policy SMS/Call Log](https://proandroiddev.com/no-more-sms-call-log-permissions-now-what-9b8226de7827)


---

<!-- source : recherche-appel-direct-verification-2026-10-07-passage31-netbuis.md -->

# Appel direct sans dialer — 31e passage (2026-10-07, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 30). Deux recherches de contrôle (plugins Flutter / TelecomManager.placeCall ; iOS CallKit vs tel://) : aucune nouvelle API ni restriction.

## Rappel
- Android : `TelecomManager.placeCall` / `ACTION_CALL` + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut), permissions `CALL_PHONE` + `READ_PHONE_STATE`, repli `ACTION_DIAL`. Plugins Flutter : direct_call_plus 1.0.4, flutter_direct_caller_plugin 0.0.4, direct_call 1.0.0.
- iOS : `tel://` impose la confirmation système ; CallKit sert aux appels VoIP (Twilio), pas au PSTN natif sans confirmation.

## Sources
[direct_call_plus](https://pub.dev/documentation/direct_call_plus/latest/) · [flutter_direct_caller_plugin](https://pub-web-s1.flutter-io.cn/packages/flutter_direct_caller_plugin) · [CallKit](https://developer.apple.com/documentation/callkit/making-and-receiving-voip-calls.md)


---

<!-- source : recherche-appel-direct-verification-2026-10-07-passage32-netbuis.md -->

# Appel direct sans dialer — 32e passage (2026-10-07, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 31). Deux recherches de contrôle (TelecomManager.placeCall / restrictions CALL_PHONE ; plugins Flutter d'appel direct) : aucune nouvelle API, aucune nouvelle restriction, mêmes plugins (direct_call, direct_call_plus, flutter_direct_caller_plugin).

## Rappel de la solution
- **Android** : `ACTION_CALL` ou `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE` (choix de la SIM par défaut). Permissions `CALL_PHONE` + `READ_PHONE_STATE`. Repli sur `ACTION_DIAL` si permission refusée. Le numéro n'est pas affiché, l'appel part immédiatement.
- **iOS** : `tel://` impose une confirmation système, impossible à contourner pour le PSTN natif. Alternative : appel VoIP via Twilio + CallKit (aucun écran de composition).

## Sources
[TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager.html) · [direct_call](https://pub.dev/packages/direct_call) · [direct_call_plus](https://pub.dev/documentation/direct_call_plus/latest/) · [flutter_direct_caller_plugin](https://pub-web-s1.flutter-io.cn/packages/flutter_direct_caller_plugin)


---

<!-- source : recherche-appel-direct-verification-2026-10-07-passage33-netbuis.md -->

# Appel direct sans dialer — 33e passage (2026-10-07, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 32). Deux recherches de contrôle (TelecomManager/PhoneAccountHandle pour le choix de SIM ; plugins Flutter d'appel direct) : aucune nouvelle API ni restriction.

Seule précision : le plugin **direct_caller_sim_choice** (v1.0.3) apparaît en plus de direct_call, direct_call_plus et flutter_direct_caller_plugin ; il permet de choisir la SIM. Recommandation inchangée : implémentation native via MethodChannel (ACTION_CALL / TelecomManager.placeCall + EXTRA_PHONE_ACCOUNT_HANDLE), plus fiable que les plugins peu maintenus.

## Rappel
- **Android** : permissions CALL_PHONE + READ_PHONE_STATE ; SIM par défaut via PhoneAccountHandle ; repli ACTION_DIAL si permission refusée. Aucun numéro affiché, appel immédiat.
- **iOS** : `tel://` impose une confirmation système (incontournable) ; alternative VoIP Twilio + CallKit.

## Sources
[PhoneAccount](https://developer.android.com/reference/android/telecom/PhoneAccount.html) · [direct_caller_sim_choice](https://pub-web-s2.flutter-io.cn/packages/direct_caller_sim_choice/versions/1.0.3) · [direct_call](https://pub.dev/packages/direct_call) · [direct_call_plus](https://pub.dev/documentation/direct_call_plus/latest/)


---

<!-- source : recherche-appel-direct-verification-2026-10-07-passage34-netbuis.md -->

# Appel direct sans dialer — 34e passage (2026-10-07, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 33). Deux recherches de contrôle (restrictions Android/Play sur CALL_PHONE/ACTION_CALL ; plugins Flutter + TelecomManager/PhoneAccountHandle) : aucune nouvelle API, aucune nouvelle restriction, aucun nouveau plugin.

## Rappel de la solution
- **Android** : permission CALL_PHONE (+ READ_PHONE_STATE pour lister les SIM) ; `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` pour imposer la SIM par défaut choisie ; l'appel part immédiatement, sans afficher le numéro ni ouvrir le dialer. Repli `ACTION_DIAL` si permission refusée. Implémentation native via MethodChannel recommandée (plugins direct_call, direct_call_plus, direct_caller_sim_choice peu maintenus).
- **iOS** : `tel://` impose une confirmation système incontournable ; alternative : appel VoIP Twilio + CallKit.

## Sources
[direct_call](https://pub.dev/packages/direct_call) · [direct_caller_sim_choice](https://pub-web-s2.flutter-io.cn/packages/direct_caller_sim_choice/versions/1.0.3) · [flutter_phone_dialer](https://pub.dev/packages/flutter_phone_dialer)


---

<!-- source : recherche-appel-direct-verification-2026-10-07-passage35-netbuis.md -->

# Appel direct sans dialer — 35e passage (2026-10-07, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 34). Deux recherches de contrôle (politique Google Play / CALL_PHONE & ACTION_CALL ; plugins Flutter + TelecomManager.placeCall / PhoneAccountHandle) : aucun nouveau résultat pertinent, aucune nouvelle API, aucune nouvelle restriction.

## Rappel
- **Android** : CALL_PHONE (+ READ_PHONE_STATE) ; `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` pour la SIM par défaut ; appel immédiat sans dialer. Repli `ACTION_DIAL`. Implémentation native via MethodChannel recommandée.
- **iOS** : confirmation système incontournable pour `tel://` ; alternative VoIP Twilio + CallKit.

Sources : [direct_call](https://pub.dev/packages/direct_call) · [direct_caller_sim_choice](https://pub-web-s2.flutter-io.cn/packages/direct_caller_sim_choice/versions/1.0.3) · [TelecomManager](https://developer.android.com/reference/kotlin/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-07-passage36-netbuis.md -->

# Appel direct sans dialer — 36e passage (2026-10-07, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 35). Deux recherches de contrôle (Android ACTION_CALL / TelecomManager.placeCall + SIM par défaut ; iOS tel:// sans confirmation / CallKit) : aucun résultat nouveau, aucune nouvelle API ni restriction.

## Rappel
- **Android** : permission CALL_PHONE (+ READ_PHONE_STATE) ; `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` pour choisir la SIM par défaut ; appel immédiat, sans ouvrir le dialer ni afficher le numéro. Repli `ACTION_DIAL`. Implémentation native via MethodChannel (ou plugin direct_call).
- **iOS** : la confirmation système pour `tel://` est incontournable (Apple n'offre aucun contournement, cf. forums développeurs) ; alternative : appel VoIP Twilio + CallKit.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Apple Dev Forums – tel:// confirmation](https://developer.apple.com/forums/thread/73406) · [Apple Dev Forums – appels natifs sans confirmation](https://developer.apple.com/forums/thread/818813)


---

<!-- source : recherche-appel-direct-verification-2026-10-07-passage37-netbuis.md -->

# Appel direct sans dialer — 37e passage (2026-10-07, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 36). Deux recherches de contrôle (Android ACTION_CALL / SIM par défaut / plugins Flutter ; iOS tel:// sans confirmation / CallKit-VoIP) : aucun résultat nouveau, aucune nouvelle API ni restriction.

## Rappel
- **Android** : permission CALL_PHONE (+ READ_PHONE_STATE) ; `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` pour la SIM par défaut ; appel immédiat sans dialer ni numéro affiché. Repli `ACTION_DIAL`. Plugins Flutter existants : direct_call_plus, flutter_direct_caller_plugin ; sinon MethodChannel natif.
- **iOS** : confirmation système pour `tel://` incontournable (forums Apple) ; alternative : appel VoIP Twilio + CallKit.

Sources : [Apple Dev Forums – tel:// confirmation](https://developer.apple.com/forums/thread/73406) · [CallKit VoIP](https://developer.apple.com/documentation/callkit/making-and-receiving-voip-calls.md) · [direct_call_plus](https://pub.dev/packages/direct_call_plus/score) · [flutter_direct_caller_plugin](https://pub-web-s2.flutter-io.cn/documentation/flutter_direct_caller_plugin/0.0.4)


---

<!-- source : recherche-appel-direct-verification-2026-10-07-passage38-netbuis.md -->

# Appel direct sans dialer — 38e passage (2026-10-07, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 37). Une recherche de contrôle (Android ACTION_CALL / SIM par défaut / TelecomManager.placeCall / restrictions récentes) : aucun résultat nouveau.

## Rappel de la solution
- **Android** : permission CALL_PHONE (+ READ_PHONE_STATE) ; `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` pour imposer la SIM par défaut. L'appel part immédiatement, sans dialer ni numéro affiché. Repli : `ACTION_DIAL`.
- **iOS** : la confirmation système de `tel://` est incontournable ; alternative : appel VoIP Twilio + CallKit.

## Recommandation
Voir audit v39 : suspendre cette routine (ou la passer en hebdomadaire) et lancer le jalon 0 (30 commerçants dans un quartier pilote).

Sources : [TelecomManager (Android Developers)](https://developer.android.com/reference/android/telecom/TelecomManager) · [Handle preferred SIM for ACTION_CALL (OmniROM)](https://gerrit.omnirom.org/plugins/gitiles/android_packages_apps_Dialer/+/01d9f64d245965d30a76bc6889c878f143fc86d7%5E)


---

<!-- source : recherche-appel-direct-verification-2026-10-07-passage39-netbuis.md -->

# Appel direct sans dialer — 39e passage (2026-10-07, tâche planifiée)

Conclusion : **inchangée** (cf. `decision-finale-appels.md` et passages 1 à 38).

## Solution d'ingénierie
- **Android** : permission CALL_PHONE (runtime) ; `Intent.ACTION_CALL` (ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` pour forcer la SIM choisie/par défaut). L'appel démarre immédiatement, sans ouvrir le dialer ni afficher le numéro de façon interactive. Repli si permission refusée : `ACTION_DIAL`.
- **Flutter** : plugins qui encapsulent ACTION_CALL : `direct_call_plus` (v1.0.4) et `flutter_direct_caller_plugin` (v0.0.4) ; `url_launcher` seul ouvre le dialer (pas d'appel direct). Pour un contrôle SIM fiable, un petit MethodChannel natif Kotlin autour de TelecomManager est préférable à un plugin peu maintenu.
- **iOS** : `tel://` impose une confirmation système (incontournable) ; alternative : appel VoIP Twilio + CallKit.
- **Point de vigilance** : CALL_PHONE est une permission sensible côté Google Play (déclaration/justification à prévoir, usage cœur de l'app = autorisé).

## Recommandation
Voir audit v39 : suspendre/passer cette routine en hebdomadaire et lancer le jalon 0 (30 commerçants).

Sources : [Handle preferred SIM for ACTION_CALL (OmniROM)](https://gerrit.omnirom.org/plugins/gitiles/android_packages_apps_Dialer/+/01d9f64d245965d30a76bc6889c878f143fc86d7%5E) · [direct_call_plus (pub.dev)](https://pub.dev/documentation/direct_call_plus/latest/) · [flutter_direct_caller_plugin](https://pub.dev/packages/flutter_direct_caller_plugin/example) · [Android Dial Phone Programmatically](https://itnext.io/android-dial-phone-programmatically-5ea3714d801d)


---

<!-- source : recherche-appel-direct-verification-2026-10-07-passage40-netbuis.md -->

# Appel direct sans dialer — 40e passage (2026-10-07, tâche planifiée)

Conclusion : **inchangée** (cf. passage 39 et `decision-finale-appels.md`). Aucune nouveauté trouvée.

## Solution d'ingénierie (rappel)
- **Android** : permission runtime CALL_PHONE ; `Intent.ACTION_CALL` lance l'appel immédiatement, sans dialer. Choix de SIM : `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut ou choisie). Repli si permission refusée : `ACTION_DIAL`.
- **Flutter** : `url_launcher` seul ouvre le dialer ; utiliser `direct_call_plus` / `flutter_direct_caller_plugin`, ou mieux un petit MethodChannel Kotlin autour de TelecomManager pour contrôler la SIM.
- **iOS** : confirmation système obligatoire sur `tel://` ; alternative = appel VoIP Twilio + CallKit.
- **Google Play** : CALL_PHONE est sensible, déclaration à prévoir (usage cœur de l'app).

## Recommandation
Inchangée : passer cette routine en hebdomadaire/suspendre et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager (Android)](https://developer.android.com/reference/android/telecom/TelecomManager) · [Handle preferred SIM for ACTION_CALL](https://gerrit.omnirom.org/plugins/gitiles/android_packages_apps_Dialer/+/01d9f64d245965d30a76bc6889c878f143fc86d7%5E)


---

<!-- source : recherche-appel-direct-verification-2026-10-07-passage41-netbuis.md -->

# Appel direct sans dialer — 41e passage (2026-10-07, tâche planifiée)

Conclusion : **inchangée** (cf. passage 40 et `decision-finale-appels.md`). Nouvelle recherche : aucune nouveauté.

- Android : permission CALL_PHONE + `Intent.ACTION_CALL` = appel immédiat sans dialer ; SIM via `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE`. Repli `ACTION_DIAL`.
- Flutter : `direct_call_plus` / `flutter_direct_caller_plugin` ou MethodChannel Kotlin.
- iOS : confirmation système obligatoire sur `tel://` ; alternative VoIP Twilio + CallKit.
- Play Store : déclaration CALL_PHONE à prévoir.

Recommandation : suspendre/passer en hebdomadaire cette routine et avancer sur le jalon 0.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager.html) · [Intent.ActionCall](https://developer.xamarin.com/api/field/Android.Content.Intent.ActionCall/)


---

<!-- source : recherche-appel-direct-verification-2026-10-08-passage42-netbuis.md -->

# Appel direct sans dialer — 42e passage (2026-10-08, tâche planifiée)

Conclusion : **inchangée** (cf. passages 40-41 et `decision-finale-appels.md`). Nouvelle recherche : aucune nouveauté.

- Android : permission CALL_PHONE + `Intent.ACTION_CALL` = appel immédiat sans passer par le dialer ; choix de SIM via `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut sinon). Repli `ACTION_DIAL` si permission refusée.
- Flutter : `direct_call_plus` (1.0.x) / `flutter_direct_caller_plugin` (0.0.4) ou MethodChannel Kotlin maison.
- iOS : confirmation système obligatoire sur `tel://` ; alternative VoIP Twilio + CallKit.
- Play Store : déclaration de la permission CALL_PHONE à prévoir.

Recommandation : suspendre ou passer cette routine en hebdomadaire et avancer sur le jalon 0 (30 commerçants dans un quartier).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [direct_call_plus](https://pub.dev/documentation/direct_call_plus/latest/) · [flutter_direct_caller_plugin](https://pub.dev/packages/flutter_direct_caller_plugin)


---

<!-- source : recherche-appel-direct-verification-2026-10-08-passage43-netbuis.md -->

# Appel direct sans dialer — 43e passage (2026-10-08, tâche planifiée)

Conclusion : **inchangée** (cf. passage 42 et `decision-finale-appels.md`). Aucune nouveauté trouvée.

- Android : permission CALL_PHONE + `Intent.ACTION_CALL` = appel immédiat sans dialer ; choix de SIM via `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE`. Repli `ACTION_DIAL`.
- Flutter : `direct_call_plus`, `flutter_direct_caller_plugin`, `direct_caller_sim_choice` (1.0.3, choix de SIM), ou MethodChannel Kotlin.
- iOS : confirmation système obligatoire sur `tel://` ; alternative VoIP Twilio + CallKit.
- Play Store : la politique restrictive concerne surtout SMS/journal d'appels ; CALL_PHONE reste utilisable avec déclaration (à revérifier dans la console au moment de la publication).

Recommandation : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [direct_caller_sim_choice](https://pub-web-s2.flutter-io.cn/packages/direct_caller_sim_choice/versions/1.0.3) · [Politique Google Play](https://support.google.com/googleplay/android-developer/answer/16909972) · [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-08-passage44-netbuis.md -->

# Appel direct sans dialer — 44e passage (2026-10-08, tâche planifiée)

Conclusion : **inchangée** (cf. passage 43 et `decision-finale-appels.md`). Aucune nouveauté.

- Android : CALL_PHONE + `Intent.ACTION_CALL` = appel immédiat sans dialer ; choix de SIM via `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE`. Repli `ACTION_DIAL`.
- Flutter : `direct_call_plus`, `flutter_direct_caller_plugin`, `direct_caller_sim_choice`, ou MethodChannel Kotlin.
- iOS : confirmation système obligatoire sur `tel://` ; alternative VoIP Twilio + CallKit.

Recommandation : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [flutter_phone_dialer](https://pub.dev/packages/flutter_phone_dialer)


---

<!-- source : recherche-appel-direct-verification-2026-10-08-passage45-netbuis.md -->

# Appel direct sans dialer — 45e passage (2026-10-08, tâche planifiée)

Conclusion : **inchangée** (cf. passages 43-44 et `decision-finale-appels.md`). Aucune nouveauté, aucune nouvelle restriction trouvée.

- Android : permission CALL_PHONE + `Intent.ACTION_CALL` = appel immédiat sans ouvrir le dialer ; choix de SIM par défaut via `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE`. Repli `ACTION_DIAL`.
- Flutter : `direct_call_plus` (1.0.4), `flutter_direct_caller_plugin` (0.0.4), `direct_call`, ou MethodChannel Kotlin.
- iOS : confirmation système obligatoire sur `tel://` (non contournable) ; alternative VoIP Twilio + CallKit.

Recommandation : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [direct_call_plus](https://pub.dev/packages/direct_call_plus/score) · [flutter_direct_caller_plugin](https://pub-web-s1.flutter-io.cn/packages/flutter_direct_caller_plugin) · [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-08-passage46-netbuis.md -->

# Appel direct sans dialer — 46e passage (2026-10-08, tâche planifiée)

Conclusion : **inchangée**. Recherche web rapide : aucune nouveauté ni restriction nouvelle.

- Android : `CALL_PHONE` + `Intent.ACTION_CALL` = appel immédiat sans dialer ; SIM par défaut via `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE` ; repli `ACTION_DIAL`.
- iOS : confirmation système obligatoire sur `tel://` ; alternative VoIP Twilio + CallKit.

Recommandation (inchangée) : suspendre cette routine, avancer sur le jalon 0 (30 commerçants).

Sources : [codemia](https://codemia.io/knowledge-hub/path/how_to_make_a_phone_call_using_intent_in_android) · [Xamarin Intent.ActionCall](https://developer.xamarin.com/api/field/Android.Content.Intent.ActionCall/)


---

<!-- source : recherche-appel-direct-verification-2026-10-08-passage47-netbuis.md -->

# Appel direct sans dialer — 47e passage (2026-10-08, tâche planifiée)

Conclusion : **inchangée**. Nouvelle recherche web : aucune nouveauté ni restriction (doc officielle TelecomManager inchangée).

- Android : `CALL_PHONE` + `ACTION_CALL` = appel immédiat sans dialer ; SIM par défaut via `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE` ; repli `ACTION_DIAL`.
- iOS : confirmation système obligatoire sur `tel://` ; alternative VoIP Twilio + CallKit.

Recommandation (inchangée) : suspendre cette routine, avancer sur le jalon 0 (30 commerçants).

Source : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-08-passage48-netbuis.md -->

# Appel direct sans dialer — 48e passage (2026-10-08, tâche planifiée)

Conclusion : **inchangée**. Recherche web sur d'éventuelles restrictions Play/Android 2026 sur `CALL_PHONE`/`ACTION_CALL` : seules les permissions SMS/Journal d'appels sont restreintes (et l'enregistrement d'appels), pas `CALL_PHONE`.

- Android : `CALL_PHONE` + `ACTION_CALL` = appel immédiat sans dialer ; SIM par défaut via `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE` ; repli `ACTION_DIAL`.
- iOS : confirmation système obligatoire sur `tel://` ; alternative VoIP Twilio + CallKit.

Recommandation (inchangée) : suspendre cette routine ; avancer sur le jalon 0 (30 commerçants).

Sources : [Play Console – politique SMS/Call Log](https://support.google.com/googleplay/android-developer/answer/17225965), [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-08-passage49-netbuis.md -->

# Appel direct sans dialer — 49e passage (2026-10-08, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté**. Nouvelle recherche web sur `ACTION_CALL` / `CALL_PHONE` : aucune restriction supplémentaire trouvée.

- Android : `CALL_PHONE` + `ACTION_CALL` = appel immédiat sans dialer, numéro non affiché ; choix de SIM par défaut via `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE` ; repli `ACTION_DIAL` si permission refusée.
- iOS : confirmation système obligatoire sur `tel://` ; alternative VoIP (Twilio Voice + CallKit).

Recommandation (inchangée) : suspendre cette routine ; avancer sur le jalon 0 (30 commerçants).

Sources : [Android Intent.ActionCall](https://developer.xamarin.com/api/field/Android.Content.Intent.ActionCall/), [how to make a phone call using intent](https://codemia.io/knowledge-hub/path/how_to_make_a_phone_call_using_intent_in_android)


---

<!-- source : recherche-appel-direct-verification-2026-10-08-passage50-netbuis.md -->

# Appel direct sans dialer — 50e passage (2026-10-08, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté**. Nouvelle recherche web (CALL_PHONE / ACTION_CALL / TelecomManager.placeCall, politique Google Play) : aucun changement trouvé.

- Android : permission `CALL_PHONE` + `Intent.ACTION_CALL` = appel immédiat, numéro non affiché dans le dialer ; SIM par défaut via `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` ; repli `ACTION_DIAL` si permission refusée. Attention : Google Play restreint surtout les permissions SMS / journal d'appels (`READ_CALL_LOG`, `PROCESS_OUTGOING_CALLS`), pas `CALL_PHONE` pour un usage de type « appeler ce commerçant ».
- iOS : confirmation système obligatoire sur `tel://`, impossible à contourner ; alternative = appel VoIP in-app (Twilio Voice + CallKit).

Recommandation (inchangée) : suspendre cette routine ; avancer sur le jalon 0 (30 commerçants).

Sources : [Intent.ActionCall](https://developer.xamarin.com/api/field/Android.Content.Intent.ActionCall/), [call via intent](https://codemia.io/knowledge-hub/path/how_to_make_a_phone_call_using_intent_in_android), [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-08-passage51-netbuis.md -->

# Appel direct sans dialer — 51e passage (2026-10-08, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté**.

- Android : `CALL_PHONE` + `Intent.ACTION_CALL` = appel immédiat sans afficher le dialer ; SIM par défaut via `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE` ; repli `ACTION_DIAL` si permission refusée.
- iOS : confirmation système obligatoire sur `tel://` (non contournable) ; alternative = VoIP in-app (Twilio Voice + CallKit).

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants).

Sources : [Handle preferred SIM for ACTION_CALL](https://gerrit.omnirom.org/plugins/gitiles/android_packages_apps_Dialer/+/01d9f64d245965d30a76bc6889c878f143fc86d7%5E), [call via intent](https://codemia.io/knowledge-hub/path/how_to_make_a_phone_call_using_intent_in_android), [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-08-passage52-netbuis.md -->

# Appel direct sans dialer — 52e passage (2026-10-08, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté**.

- Android : `CALL_PHONE` + `Intent.ACTION_CALL` (ex. lib `react-native-immediate-phone-call`) = appel immédiat sans dialer ; SIM par défaut via `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE` ; repli `ACTION_DIAL` si permission refusée.
- iOS : confirmation système obligatoire sur `tel://` (non contournable) ; alternative = VoIP in-app (Twilio Voice + CallKit).

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants).

Sources : [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call), [call via intent](https://codemia.io/knowledge-hub/path/how_to_make_a_phone_call_using_intent_in_android)


---

<!-- source : recherche-appel-direct-verification-2026-10-08-passage53-netbuis.md -->

# Appel direct sans dialer — 53e passage (2026-10-08, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté**.

- Android : permission `CALL_PHONE` + `Intent.ACTION_CALL` (ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` pour choisir la SIM par défaut) = appel immédiat sans afficher le dialer. Repli `ACTION_DIAL` si permission refusée.
- iOS : confirmation système obligatoire sur `tel://`, non contournable ; alternative = VoIP in-app (Twilio Voice + CallKit).

Recommandation : suspendre cette routine ; avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager.html), [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call)


---

<!-- source : recherche-appel-direct-verification-2026-10-08-passage54-netbuis.md -->

# Appel direct sans dialer — 54e passage (2026-10-08, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté**.

- Android : `CALL_PHONE` + `Intent.ACTION_CALL` (ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` pour la SIM par défaut) = appel immédiat sans dialer. Repli `ACTION_DIAL` si permission refusée. Paquets existants : react-native-immediate-phone-call, react-native-phone-call, Flutter direct_caller_sim_choice.
- iOS : confirmation système obligatoire sur `tel://`, non contournable ; alternative = VoIP in-app (Twilio Voice + CallKit).

Recommandation : suspendre cette routine ; avancer sur le jalon 0 (30 commerçants).

Sources : [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call), [direct_caller_sim_choice](https://pub-web-s2.flutter-io.cn/packages/direct_caller_sim_choice/versions/1.0.3), [react-native-phone-call](https://github.com/tiaanduplessis/react-native-phone-call/blob/master/)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage55-netbuis.md -->

# Appel direct sans dialer — 55e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**. Deux recherches de contrôle (Android TelecomManager.placeCall / SIM par défaut / restrictions 2026 ; iOS tel:// sans confirmation / CallKit) : aucune nouvelle API ni restriction.

- Android : `CALL_PHONE` (+ `READ_PHONE_STATE`) ; `ACTION_CALL` ou `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut) = appel immédiat sans dialer ni numéro affiché ; repli `ACTION_DIAL`.
- iOS : confirmation système de `tel://` incontournable ; alternative VoIP Twilio + CallKit.

Recommandation (inchangée) : suspendre cette routine ; avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Apple Dev Forums tel://](https://developer.apple.com/forums/thread/73406) · [CallKit VoIP](https://developer.apple.com/documentation/callkit/making-and-receiving-voip-calls.md)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage56-netbuis.md -->

# Appel direct sans dialer — 56e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**. Deux recherches de contrôle (Android TelecomManager/CALL_PHONE/SIM par défaut ; iOS tel:// sans confirmation) : aucune nouvelle API ni restriction. Seul résultat notable côté iOS : un fil Apple Dev Forums (818813) sur l'appel cellulaire natif sans confirmation depuis une app compagnon — il confirme que ce n'est pas possible pour une app standard.

- Android : `CALL_PHONE` (+ `READ_PHONE_STATE`) ; `ACTION_CALL` ou `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut) = appel immédiat sans dialer ni numéro affiché ; repli `ACTION_DIAL`.
- iOS : confirmation système de `tel://` incontournable ; alternative VoIP Twilio + CallKit.

Recommandation (inchangée) : suspendre cette routine ; avancer sur le jalon 0 (30 commerçants). Aucune notification : rien de nouveau.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Apple Dev Forums 818813](https://developer.apple.com/forums/thread/818813)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage57-netbuis.md -->

# Appel direct sans dialer — 57e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**. Deux recherches de contrôle (TelecomManager/CALL_PHONE ; react-native-immediate-phone-call) : aucune nouvelle API ni restriction.

- Android : `CALL_PHONE` + `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut) = appel immédiat sans dialer. Package RN : react-native-immediate-phone-call (Android seulement).
- iOS : confirmation système de `tel://` incontournable ; alternative VoIP Twilio + CallKit.

Recommandation (inchangée) : suspendre cette routine ; avancer sur le jalon 0 (30 commerçants). Aucune notification : rien de nouveau.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage58-netbuis.md -->

# Appel direct sans dialer — 58e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**. Contrôle de la politique Google Play (juillet 2026, effective 27 janv. 2027) : elle ne touche que READ_CALL_LOG pour la vérification de compte ; CALL_PHONE / ACTION_CALL non restreints. Aucun nouveau package pertinent (react-native-immediate-phone-call, direct_caller_sim_choice pour Flutter).

- Android : CALL_PHONE + ACTION_CALL ou TelecomManager.placeCall avec EXTRA_PHONE_ACCOUNT_HANDLE (SIM par défaut) = appel immédiat.
- iOS : confirmation système de tel:// incontournable ; alternative VoIP Twilio + CallKit.

Recommandation : suspendre cette routine ; avancer sur le jalon 0. Aucune notification : rien de nouveau.

Sources : [Politique Play SMS/Call Log](https://support.google.com/googleplay/android-developer/answer/17225965) · [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage59-netbuis.md -->

# Appel direct sans dialer — 59e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**, aucune nouveauté.

- Android : permission CALL_PHONE + Intent ACTION_CALL, ou TelecomManager.placeCall avec EXTRA_PHONE_ACCOUNT_HANDLE (choix de SIM par défaut) = appel lancé immédiatement, sans afficher le dialer ni le numéro. Plugins : react-native-immediate-phone-call, flutter_phone_direct_caller (2.2.1), direct_call_plus.
- iOS : la confirmation système de tel:// est incontournable ; alternative = appel VoIP Twilio + CallKit.

Recommandation : suspendre cette routine ; avancer sur le jalon 0. Aucune notification envoyée : rien de nouveau.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call) · [flutter_phone_direct_caller](https://pub-web-s1.flutter-io.cn/packages/flutter_phone_direct_caller/changelog)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage60-netbuis.md -->

# Appel direct sans dialer — 60e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**, aucune nouveauté (flutter_phone_direct_caller toujours en 2.2.1, doc TelecomManager sans changement).

- Android : CALL_PHONE + Intent ACTION_CALL, ou TelecomManager.placeCall avec EXTRA_PHONE_ACCOUNT_HANDLE (SIM par défaut) = appel immédiat sans dialer ni numéro affiché.
- iOS : confirmation système de tel:// incontournable ; alternative = VoIP Twilio + CallKit.

Recommandation : suspendre cette routine ; avancer sur le jalon 0. Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller/versions) · [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage61-netbuis.md -->

# Appel direct sans dialer — 61e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**, aucune nouveauté (flutter_phone_direct_caller toujours en 2.2.1, publié le 8 avril 2025 ; doc TelecomManager sans changement).

- Android : CALL_PHONE + Intent ACTION_CALL, ou TelecomManager.placeCall avec EXTRA_PHONE_ACCOUNT_HANDLE (SIM par défaut) = appel immédiat sans dialer ni numéro affiché.
- iOS : confirmation système de tel:// incontournable ; alternative = VoIP Twilio + CallKit.

Recommandation : suspendre cette routine ; avancer sur le jalon 0. Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller/versions)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage62-netbuis.md -->

# Appel direct sans dialer — 62e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**, aucune nouveauté (flutter_phone_direct_caller toujours en 2.2.1, publié le 8 avril 2025 ; doc TelecomManager sans changement).

- Android : CALL_PHONE + Intent ACTION_CALL, ou TelecomManager.placeCall avec EXTRA_PHONE_ACCOUNT_HANDLE (SIM par défaut) = appel immédiat sans dialer ni numéro affiché.
- iOS : confirmation système de tel:// incontournable ; alternative = VoIP Twilio + CallKit.

Recommandation : suspendre cette routine ; avancer sur le jalon 0. Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller/versions)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage63-netbuis.md -->

# Appel direct sans dialer — 63e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**, aucune nouveauté (flutter_phone_direct_caller toujours en 2.2.1, publié le 8 avril 2025).

- Android : CALL_PHONE + Intent ACTION_CALL, ou TelecomManager.placeCall avec EXTRA_PHONE_ACCOUNT_HANDLE (SIM par défaut) = appel immédiat sans dialer ni numéro affiché.
- iOS : confirmation système de tel:// incontournable ; alternative = VoIP Twilio + CallKit.

Recommandation : suspendre cette routine ; avancer sur le jalon 0. Aucune notification envoyée.

Sources : [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller/versions) · [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage64-netbuis.md -->

# Appel direct sans dialer — 64e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**, aucune nouveauté (flutter_phone_direct_caller toujours en 2.2.1, publié le 8 avril 2025).

- Android : CALL_PHONE + Intent ACTION_CALL, ou TelecomManager.placeCall avec EXTRA_PHONE_ACCOUNT_HANDLE (SIM par défaut) = appel immédiat sans dialer ni numéro affiché.
- iOS : confirmation système de tel:// incontournable ; alternative = VoIP Twilio + CallKit.

Recommandation : suspendre cette routine ; avancer sur le jalon 0. Aucune notification envoyée.

Sources : [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller/versions) · [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage65-netbuis.md -->

# Appel direct sans dialer — 65e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**, aucune nouveauté (flutter_phone_direct_caller toujours en 2.2.1, publié le 8 avril 2025).

- Android : CALL_PHONE + Intent ACTION_CALL, ou TelecomManager.placeCall avec EXTRA_PHONE_ACCOUNT_HANDLE (SIM par défaut) = appel immédiat sans dialer ni numéro affiché.
- iOS : confirmation système de tel:// incontournable ; alternative = VoIP Twilio + CallKit.

Recommandation : suspendre cette routine ; avancer sur le jalon 0. Aucune notification envoyée.

Sources : [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller/versions) · [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage66-netbuis.md -->

# Appel direct sans dialer — 66e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**, aucune nouveauté (flutter_phone_direct_caller toujours en 2.2.1, publié le 8 avril 2025 ; doc TelecomManager inchangée).

- Android : CALL_PHONE + Intent ACTION_CALL, ou TelecomManager.placeCall avec EXTRA_PHONE_ACCOUNT_HANDLE (SIM par défaut) = appel immédiat sans dialer ni numéro affiché.
- iOS : confirmation système de tel:// incontournable ; alternative = VoIP Twilio + CallKit.

Recommandation : suspendre cette routine ; avancer sur le jalon 0. Aucune notification envoyée.

Sources : [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller/versions) · [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage67-netbuis.md -->

# Appel direct sans dialer — 67e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**, aucune nouveauté (flutter_phone_direct_caller toujours en 2.2.1 ; aucune évolution de TelecomManager / CALL_PHONE repérée).

- Android : CALL_PHONE + Intent ACTION_CALL, ou TelecomManager.placeCall avec EXTRA_PHONE_ACCOUNT_HANDLE (SIM par défaut) = appel immédiat sans dialer ni numéro affiché.
- iOS : confirmation système de tel:// incontournable ; alternative = VoIP Twilio + CallKit.

Recommandation : suspendre cette routine ; avancer sur le jalon 0. Aucune notification envoyée.

Sources : [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller/score) · [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage68-netbuis.md -->

# Appel direct sans dialer — 68e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**, aucune nouveauté (flutter_phone_direct_caller toujours en 2.2.1, publié le 8 avril 2025 ; aucune évolution de TelecomManager repérée).

- Android : CALL_PHONE + Intent ACTION_CALL, ou TelecomManager.placeCall avec EXTRA_PHONE_ACCOUNT_HANDLE (SIM par défaut) = appel immédiat sans dialer ni numéro affiché.
- iOS : confirmation système de tel:// incontournable ; alternative = VoIP Twilio + CallKit.

Recommandation : suspendre cette routine ; avancer sur le jalon 0. Aucune notification envoyée.

Sources : [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller) · [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage69-netbuis.md -->

# Appel direct sans dialer — 69e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**, aucune nouveauté (flutter_phone_direct_caller toujours en 2.2.1).

- Android : CALL_PHONE + ACTION_CALL, ou TelecomManager.placeCall avec PhoneAccountHandle (SIM par défaut) = appel immédiat, sans dialer ni numéro affiché.
- iOS : confirmation système de tel:// incontournable ; alternative = VoIP Twilio + CallKit.

Recommandation : suspendre cette routine ; avancer sur le jalon 0. Aucune notification envoyée.

Sources : [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller/score) · [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage70-netbuis.md -->

# Appel direct sans dialer — 70e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**, aucune nouveauté (flutter_phone_direct_caller toujours en 2.2.1 ; API TelecomManager inchangée).

- Android : permission CALL_PHONE + ACTION_CALL, ou TelecomManager.placeCall avec PhoneAccountHandle (SIM par défaut) = appel immédiat, sans dialer ni numéro affiché.
- iOS : confirmation système de tel:// incontournable ; alternative = VoIP Twilio + CallKit.

Recommandation : suspendre cette routine ; avancer sur le jalon 0. Aucune notification envoyée.

Sources : [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller/score) · [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage71-netbuis.md -->

# Appel direct sans dialer — 71e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**, aucune nouveauté (flutter_phone_direct_caller toujours en 2.2.1, publié le 8 avril 2025 ; API TelecomManager inchangée).

- Android : permission CALL_PHONE + ACTION_CALL, ou TelecomManager.placeCall avec PhoneAccountHandle (SIM par défaut) = appel immédiat, sans dialer ni numéro affiché.
- iOS : confirmation système de tel:// incontournable ; alternative = VoIP Twilio + CallKit.

Recommandation : suspendre cette routine ; avancer sur le jalon 0. Aucune notification envoyée.

Sources : [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller) · [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage72-netbuis.md -->

# Appel direct sans dialer — 72e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**, aucune nouveauté (flutter_phone_direct_caller toujours en 2.2.1, publié le 8 avril 2025).

- Android : permission CALL_PHONE + ACTION_CALL, ou TelecomManager.placeCall avec PhoneAccountHandle (SIM par défaut) = appel immédiat, sans dialer ni numéro affiché.
- iOS : confirmation système de tel:// incontournable ; alternative = VoIP Twilio + CallKit.

Recommandation : suspendre cette routine ; avancer sur le jalon 0. Aucune notification envoyée.

Sources : [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller) · [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage73-netbuis.md -->

# Appel direct sans dialer — 73e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**, aucune nouveauté (flutter_phone_direct_caller toujours en 2.2.1, publié le 8 avril 2025).

- Android : CALL_PHONE + ACTION_CALL, ou TelecomManager.placeCall avec PhoneAccountHandle (SIM par défaut) = appel immédiat, sans dialer ni numéro affiché.
- iOS : confirmation système de tel:// incontournable ; alternative = VoIP Twilio + CallKit.

Recommandation : suspendre cette routine ; avancer sur le jalon 0. Aucune notification envoyée.

Sources : [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller) · [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-09-passage74-netbuis.md -->

# Appel direct sans dialer — 74e passage (2026-10-09, tâche planifiée)

Conclusion : **inchangée**, aucune nouveauté (flutter_phone_direct_caller toujours en 2.2.1, publié le 8 avril 2025).

- Android : CALL_PHONE + ACTION_CALL, ou TelecomManager.placeCall avec PhoneAccountHandle (SIM par défaut) = appel immédiat, sans dialer ni numéro affiché.
- iOS : confirmation système de tel:// incontournable ; alternative = VoIP Twilio + CallKit.

Recommandation : suspendre cette routine ; avancer sur le jalon 0. Aucune notification envoyée.

Sources : [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller) · [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage75-netbuis.md -->

# Appel direct sans dialer — 75e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 74). Deux recherches de contrôle (Android ACTION_CALL / TelecomManager.placeCall + SIM par défaut + politique Play ; iOS tel:// sans confirmation / CallKit) : aucune nouvelle API, restriction ou plugin.

- **Android** : permission CALL_PHONE (+ READ_PHONE_STATE) ; `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` pour imposer la SIM par défaut ; appel immédiat sans dialer ni numéro affiché. Repli `ACTION_DIAL` si permission refusée. Implémentation via MethodChannel natif.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : appel VoIP Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Apple Dev Forums – tel:// confirmation](https://developer.apple.com/forums/thread/73406) · [Apple Dev Forums – appels natifs sans confirmation](https://developer.apple.com/forums/thread/818813)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage76-netbuis.md -->

# Appel direct sans dialer — 76e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 75). Une recherche de contrôle (Android ACTION_CALL / TelecomManager.placeCall + SIM par défaut + CALL_PHONE) : seule la documentation officielle TelecomManager ressort, aucune nouvelle API ni restriction.

- **Android** : permission CALL_PHONE (+ READ_PHONE_STATE) ; `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` pour la SIM par défaut ; appel immédiat sans dialer ni numéro affiché. Repli `ACTION_DIAL` si permission refusée. Via MethodChannel natif.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : appel VoIP Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage77-netbuis.md -->

# Appel direct sans dialer — 77e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 76).

Contrôle : politique Google Play « permissions sensibles » (aperçu des changements d'avril 2026). Elle restreint READ_CALL_LOG / PROCESS_OUTGOING_CALLS (réservés au gestionnaire Téléphone par défaut) ; elle ne mentionne ni CALL_PHONE ni ACTION_CALL. Nouvelles règles localisation et contacts : effectives le 27/01/2027, sans impact sur NETBUIS (le sélecteur de contacts n'est pas utilisé).

- **Android** : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut) : appel immédiat sans dialer. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [Play policy permissions](https://support.google.com/googleplay/android-developer/answer/16909972), [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage78-netbuis.md -->

# Appel direct sans dialer — 78e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 77).

Contrôle : recherches sur ACTION_CALL / TelecomManager.placeCall (SIM par défaut) et sur les paquets React Native (react-native-immediate-phone-call, react-native-phone-call) : aucun changement de politique ni nouvelle solution.

- **Android** : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` : appel immédiat sans dialer. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager), [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage79-netbuis.md -->

# Appel direct sans dialer — 79e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 78).

Contrôle : recherches sur ACTION_CALL / TelecomManager.placeCall et sur les paquets React Native / Flutter d'appel direct (react-native-immediate-phone-call, flutter_direct_caller_plugin, direct_call_plus) : aucune nouvelle solution ni changement de politique.

- **Android** : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (`EXTRA_PHONE_ACCOUNT_HANDLE` pour choisir la SIM) : appel immédiat sans dialer. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager), [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage80-netbuis.md -->

# Appel direct sans dialer — 80e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 79).

Contrôle : recherches sur ACTION_CALL / TelecomManager.placeCall (choix de SIM via EXTRA_PHONE_ACCOUNT_HANDLE) et sur les paquets react-native-immediate-phone-call, flutter_direct_caller_plugin, direct_call_plus, flutter_phone_direct_caller : aucune nouvelle solution, aucun changement de politique détecté.

- **Android** : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` : appel immédiat sans dialer, SIM par défaut ou choisie. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager), [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call), [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage81-netbuis.md -->

# Appel direct sans dialer — 81e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 80).

Contrôle : recherches sur TelecomManager.placeCall / ACTION_CALL (choix de SIM) et sur les plugins Flutter d'appel direct (flutter_tele, direct_call, direct_call_plus, flutter_direct_caller_plugin) : aucune nouvelle solution ni changement de politique.

- **Android** : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (EXTRA_PHONE_ACCOUNT_HANDLE pour la SIM) : appel immédiat sans dialer. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager), [direct_call_plus](https://pub.dev/documentation/direct_call_plus/latest/), [flutter_tele](https://pub.dev/packages/flutter_tele)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage82-netbuis.md -->

# Appel direct sans dialer — 82e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 81).

Contrôle : recherches sur TelecomManager.placeCall / ACTION_CALL / plugins Flutter (flutter_tele, direct_call, direct_call_plus, direct_caller_sim_choice, flutter_direct_caller_plugin) et sur les politiques Google Play (permissions appels/SMS) : aucune nouvelle solution, aucun changement.

- **Android** : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (EXTRA_PHONE_ACCOUNT_HANDLE pour la SIM par défaut) = appel immédiat sans dialer ni affichage du numéro. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [flutter_tele](https://pub.dev/packages/flutter_tele), [direct_call](https://pub.dev/packages/direct_call), [Google Play policy](https://support.google.com/googleplay/android-developer/answer/17225965)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage83-netbuis.md -->

# Appel direct sans dialer — 83e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 82).

Contrôle : nouvelle recherche (TelecomManager.placeCall, plugins Flutter direct call). Seuls les plugins déjà connus ressortent (flutter_phone_direct_caller, direct_call_plus 1.0.4, flutter_direct_caller_plugin 0.0.4). Aucune nouvelle solution.

- **Android** : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (EXTRA_PHONE_ACCOUNT_HANDLE pour la SIM par défaut) = appel immédiat, sans dialer ni affichage du numéro. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [flutter_phone_direct_caller](https://fluttergems.dev/packages/flutter_phone_direct_caller/), [direct_call_plus](https://pub.dev/packages/direct_call_plus/score)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage84-netbuis.md -->

# Appel direct sans dialer — 84e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 83).

Contrôle : nouvelles recherches (plugins Flutter d'appel direct / TelecomManager.placeCall ; iOS tel:// sans confirmation). Seuls les plugins déjà connus ressortent (flutter_phone_direct_caller 2.2.1, direct_call_plus 1.0.4, flutter_direct_caller_plugin 0.0.4). Côté iOS, les forums Apple confirment toujours qu'aucune API publique ne permet d'appeler sans confirmation système.

- **Android** : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (EXTRA_PHONE_ACCOUNT_HANDLE pour choisir la SIM par défaut) = appel immédiat, sans dialer ni affichage du numéro. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : Twilio Voice + CallKit (appel VoIP in-app).

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller/score), [direct_call_plus](https://pub.dev/documentation/direct_call_plus/latest/), [Apple Dev Forums – appel sans confirmation](https://developer.apple.com/forums/thread/818813)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage85-netbuis.md -->

# Appel direct sans dialer — 85e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 84).

Contrôle : recherche sur d'éventuelles nouvelles restrictions Android 16 / ACTION_CALL / TelecomManager.placeCall : rien de nouveau (seulement la doc TelecomManager et les sources déjà connues).

- **Android** : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (EXTRA_PHONE_ACCOUNT_HANDLE pour la SIM par défaut) = appel immédiat, sans dialer ni numéro affiché. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Handle preferred SIM for ACTION_CALL](https://gerrit.omnirom.org/plugins/gitiles/android_packages_apps_Dialer/+/01d9f64d245965d30a76bc6889c878f143fc86d7%5E) · [call via intent](https://codemia.io/knowledge-hub/path/how_to_make_a_phone_call_using_intent_in_android)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage86-netbuis.md -->

# Appel direct sans dialer — 86e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 85).

Contrôle : nouvelle recherche (Android 16 / ACTION_CALL / TelecomManager.placeCall / choix de SIM) : mêmes sources que d'habitude, aucune restriction ni solution nouvelle.

- **Android** : permission CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (avec `EXTRA_PHONE_ACCOUNT_HANDLE` pour la SIM par défaut) = appel immédiat, sans dialer ni numéro affiché. Repli `ACTION_DIAL` si la permission est refusée.
- **iOS** : la confirmation système sur `tel://` est incontournable ; alternative : Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Handle preferred SIM for ACTION_CALL](https://gerrit.omnirom.org/plugins/gitiles/android_packages_apps_Dialer/+/01d9f64d245965d30a76bc6889c878f143fc86d7%5E)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage87-netbuis.md -->

# Appel direct sans dialer — 87e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 86).

Contrôle : nouvelle recherche (ACTION_CALL / TelecomManager.placeCall / politique CALL_PHONE) : mêmes sources, aucune restriction ni solution nouvelle.

- **Android** : permission CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (avec `EXTRA_PHONE_ACCOUNT_HANDLE` pour la SIM par défaut) = appel immédiat, sans dialer ni numéro affiché. Repli `ACTION_DIAL` si la permission est refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager.html) · [ACTION_CALL par intent](https://codemia.io/knowledge-hub/path/how_to_make_a_phone_call_using_intent_in_android)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage88-netbuis.md -->

# Appel direct sans dialer — 88e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 87).

Contrôle : nouvelle recherche (ACTION_CALL / TelecomManager.placeCall / politique CALL_PHONE) : mêmes sources officielles, aucune restriction ni solution nouvelle.

- **Android** : permission CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (avec `EXTRA_PHONE_ACCOUNT_HANDLE` pour la SIM par défaut) = appel immédiat, sans dialer ni numéro affiché. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager.html)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage89-netbuis.md -->

# Appel direct sans dialer — 89e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 88). Recherche de contrôle (ACTION_CALL / TelecomManager.placeCall / SIM par défaut / restrictions 2026) : seule la documentation officielle et le commit Dialer AOSP ressortent.

- **Android** : CALL_PHONE (+ READ_PHONE_STATE) ; `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut) : l'appel part sans dialer ni numéro affiché. Repli `ACTION_DIAL` si permission refusée. Via MethodChannel natif.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Handle preferred SIM for ACTION_CALL](https://gerrit.omnirom.org/plugins/gitiles/android_packages_apps_Dialer/+/01d9f64d245965d30a76bc6889c878f143fc86d7%5E)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage90-netbuis.md -->

# Appel direct sans dialer — 90e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 89). Recherche de contrôle (TelecomManager.placeCall / PhoneAccountHandle SIM par défaut / Flutter) : seule la documentation officielle Android ressort.

- **Android** : CALL_PHONE (+ READ_PHONE_STATE) ; `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` : l'appel part sans dialer ni numéro affiché. Repli `ACTION_DIAL` si permission refusée. Via MethodChannel natif.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Telecom framework](https://developer.android.com/develop/connectivity/telecom)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage91-netbuis.md -->

# Appel direct sans dialer — 91e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 90). Recherche de contrôle (TelecomManager.placeCall / PhoneAccountHandle / SIM par défaut) : seule la documentation officielle Android ressort.

- **Android** : permissions CALL_PHONE (+ READ_PHONE_STATE) ; `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM choisie) : l'appel part sans dialer ni numéro affiché. Repli `ACTION_DIAL` si permission refusée. Via MethodChannel natif (Flutter).
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Telecom framework](https://developer.android.com/develop/connectivity/telecom)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage92-netbuis.md -->

# Appel direct sans dialer — 92e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 91).

- **Android** : CALL_PHONE (+ READ_PHONE_STATE) ; `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM choisie) → l'appel part sans dialer ni numéro affiché. Repli `ACTION_DIAL` si permission refusée.
- **Flutter** : plugins existants (`flutter_phone_direct_caller`, `direct_call_plus` 1.0.4) ou MethodChannel natif ; aucun changement notable.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [Telecom framework](https://developer.android.com/develop/connectivity/telecom) · [direct_call_plus](https://pub.dev/packages/direct_call_plus) · [flutter_phone_direct_caller](https://pub-web-s1.flutter-io.cn/packages/flutter_phone_direct_caller/changelog)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage93-netbuis.md -->

# Appel direct sans dialer — 93e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 92).

- Android : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (choix de SIM) → appel sans dialer ni numéro affiché. Repli `ACTION_DIAL`.
- Flutter : plugins existants (`flutter_phone_direct_caller`, `direct_call_plus`, `direct_caller_sim_choice` 1.0.3 avec choix de SIM) ou MethodChannel natif.
- iOS : confirmation système sur `tel://` incontournable ; alternative Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [direct_caller_sim_choice](https://pub-web-s2.flutter-io.cn/packages/direct_caller_sim_choice/versions/1.0.3)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage94-netbuis.md -->

# Appel direct sans dialer — 94e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 93).

- Android : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (choix de SIM). Repli `ACTION_DIAL`.
- Flutter : `flutter_phone_direct_caller`, `direct_call_plus` 1.0.4, `direct_caller_sim_choice` 1.0.3, `flutter_direct_caller_plugin` 0.0.4.
- iOS : confirmation système sur `tel://` incontournable ; alternative Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [direct_caller_sim_choice](https://pub-web-s2.flutter-io.cn/packages/direct_caller_sim_choice/versions/1.0.3) · [direct_call_plus](https://pub-web-s1.flutter-io.cn/packages/direct_call_plus/changelog)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage95-netbuis.md -->

# Appel direct sans dialer — 95e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 94).

- Android : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut). Repli `ACTION_DIAL`.
- Flutter : `flutter_phone_direct_caller`, `direct_call_plus` 1.0.4, `direct_caller_sim_choice` 1.0.3, `flutter_direct_caller_plugin` 0.0.4, `flutter_tele`, `direct_call` — aucune nouvelle version marquante.
- iOS : confirmation système sur `tel://` incontournable ; alternative Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [direct_caller_sim_choice](https://pub-web-s2.flutter-io.cn/packages/direct_caller_sim_choice/versions/1.0.3) · [direct_call_plus](https://pub-web-s1.flutter-io.cn/packages/direct_call_plus/changelog) · [flutter_tele](https://pub.dev/packages/flutter_tele)


---

<!-- source : recherche-appel-direct-verification-2026-10-10-passage96-netbuis.md -->

# Appel direct sans dialer — 96e passage (2026-10-10, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 95).

- Android : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` avec `PhoneAccountHandle` (choix SIM). Repli `ACTION_DIAL`.
- Flutter : `flutter_direct_caller_plugin` 0.0.4, `direct_call_plus`, `flutter_tele` 2.0.5+105 — aucune nouvelle version marquante.
- iOS : confirmation système sur `tel://` incontournable ; alternative Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [flutter_direct_caller_plugin](https://pub.dev/packages/flutter_direct_caller_plugin) · [flutter_tele](https://pub.dev/packages/flutter_tele) · [Android PhoneAccount](https://developer.android.com/reference/android/telecom/PhoneAccount)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage97-netbuis.md -->

# Appel direct sans dialer — 97e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 96).

- Android : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` avec `PhoneAccountHandle` (choix SIM par défaut). Repli `ACTION_DIAL`.
- Flutter : `flutter_direct_caller_plugin` 0.0.4 (publié fév. 2025, toujours la dernière), `flutter_tele` 2.0.5+105, `direct_call_plus` — aucune nouvelle version.
- iOS : confirmation système sur `tel://` incontournable ; alternative Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [flutter_direct_caller_plugin](https://pub.dev/packages/flutter_direct_caller_plugin) · [flutter_tele](https://pub.dev/packages/flutter_tele)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage98-netbuis.md -->

# Appel direct sans dialer — 98e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 97).

- Android : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` avec `PhoneAccountHandle` (SIM par défaut). Repli `ACTION_DIAL`.
- Flutter : `flutter_direct_caller_plugin` toujours 0.0.4 (23 fév. 2025), `flutter_tele`, `direct_call_plus` 1.0.4 — aucune nouvelle version.
- iOS : confirmation système sur `tel://` incontournable ; alternative Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [flutter_direct_caller_plugin](https://pub.dev/packages/flutter_direct_caller_plugin/versions) · [direct_call_plus](https://fluttergems.dev/packages/direct_call_plus/)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage99-netbuis.md -->

# Appel direct sans dialer — 99e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 98).

- Android : permission CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` avec `PhoneAccountHandle` (SIM par défaut ou choisie). Repli `ACTION_DIAL`. Doc TelecomManager inchangée.
- Flutter : `flutter_direct_caller_plugin` toujours 0.0.4 (23 fév. 2025) — vérifié ce jour.
- iOS : confirmation système sur `tel://` incontournable ; alternative Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [flutter_direct_caller_plugin](https://pub.dev/packages/flutter_direct_caller_plugin/versions) · [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage100-netbuis.md -->

# Appel direct sans dialer — 100e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 99).

- Android : `ACTION_CALL` (permission CALL_PHONE) ou `TelecomManager.placeCall` avec `PhoneAccountHandle` (SIM par défaut ou choisie). Repli `ACTION_DIAL`.
- Flutter : `flutter_direct_caller_plugin` toujours 0.0.4 (23 fév. 2025) — revérifié. Alternatives existantes : `flutter_phone_direct_caller` 2.2.1, `direct_call_plus` 1.0.4 — pas de changement.
- iOS : confirmation système sur `tel://` incontournable ; alternative Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine (100 passages sans changement) et avancer sur le jalon 0 (30 commerçants).

Sources : [flutter_direct_caller_plugin](https://pub.dev/packages/flutter_direct_caller_plugin/versions) · [direct_call_plus](https://pub.dev/packages/direct_call_plus/score) · [flutter_phone_direct_caller](https://pub-web-s1.flutter-io.cn/packages/flutter_phone_direct_caller/changelog)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage101-netbuis.md -->

# Appel direct sans dialer — 101e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 100).

- Android : `ACTION_CALL` (CALL_PHONE) ou `TelecomManager.placeCall` avec `PhoneAccountHandle` (SIM par défaut/choisie). Repli `ACTION_DIAL`.
- Flutter : `flutter_direct_caller_plugin` toujours 0.0.4 (23 fév. 2025) ; `flutter_phone_direct_caller` toujours 2.2.1 (8 avr. 2025) — revérifiés sur pub.dev.
- iOS : confirmation système sur `tel://` incontournable ; alternative Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [flutter_direct_caller_plugin](https://pub.dev/packages/flutter_direct_caller_plugin/versions) · [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller/versions)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage102-netbuis.md -->

# Appel direct sans dialer — 102e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 101).

- Android : `ACTION_CALL` (permission CALL_PHONE) ou `TelecomManager.placeCall` avec `PhoneAccountHandle` (choix de SIM). Repli `ACTION_DIAL`.
- Flutter : `flutter_direct_caller_plugin` 0.0.4 et `flutter_phone_direct_caller` 2.2.1 — aucun nouveau résultat de recherche.
- iOS : confirmation système sur `tel://` incontournable ; alternative Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [flutter_direct_caller_plugin](https://pub-web-s2.flutter-io.cn/documentation/flutter_direct_caller_plugin/0.0.4)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage103-netbuis.md -->

# Appel direct sans dialer — 103e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 102).

- Android : `ACTION_CALL` (CALL_PHONE) ou `TelecomManager.placeCall` + `PhoneAccountHandle` (choix de SIM). Repli `ACTION_DIAL`.
- Flutter : `flutter_direct_caller_plugin` 0.0.4, `flutter_phone_direct_caller` 2.2.1, `flutter_tele` 2.0.5 — rien de nouveau.
- iOS : confirmation système sur `tel://` incontournable ; alternative Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [flutter_direct_caller_plugin](https://pub-web-s2.flutter-io.cn/documentation/flutter_direct_caller_plugin/0.0.4) · [flutter_tele](https://pub.dev/packages/flutter_tele)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage104-netbuis.md -->

# Appel direct sans dialer — 104e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 103).

- Android : `ACTION_CALL` (CALL_PHONE) ou `TelecomManager.placeCall` + `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut). Repli `ACTION_DIAL`.
- Flutter : `flutter_phone_direct_caller` 2.2.1, `direct_caller_sim_choice` 1.0.3, `flutter_direct_caller_plugin` 0.0.4, `flutter_tele` 2.0.5 — aucune nouvelle version.
- iOS : confirmation système sur `tel://` incontournable ; alternative Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [direct_caller_sim_choice](https://pub-web-s2.flutter-io.cn/packages/direct_caller_sim_choice/versions/1.0.3) · [flutter_phone_direct_caller](https://pub-web-s1.flutter-io.cn/packages/flutter_phone_direct_caller/changelog)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage105-netbuis.md -->

# Appel direct sans dialer — 105e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 104).

Contrôle : deux recherches standard (Android ACTION_CALL / TelecomManager.placeCall / choix SIM ; bibliothèques RN/Flutter d'appel direct dual SIM). Mêmes sources, aucune restriction ni solution nouvelle. Bibliothèques déjà connues : react-native-immediate-phone-call, direct_call_plus, direct_caller_sim_choice, flutter_direct_caller_plugin.

- **Android** : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (+ `EXTRA_PHONE_ACCOUNT_HANDLE` pour la SIM par défaut) = appel immédiat, sans dialer ni numéro affiché. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants). Aucune notification envoyée (rien d'actionnable).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call) · [direct_call_plus](https://pub.dev/documentation/direct_call_plus/latest/)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage106-netbuis.md -->

# Appel direct sans dialer — 106e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 105).

Contrôle : deux recherches standard (Android ACTION_CALL / TelecomManager.placeCall / PhoneAccountHandle ; paquets RN/Flutter d'appel direct dual SIM). Mêmes sources, mêmes paquets (direct_call_plus, direct_caller_sim_choice, flutter_direct_caller_plugin, react-native-immediate-phone-call). Aucune restriction ni solution nouvelle.

- **Android** : permission CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (+ `EXTRA_PHONE_ACCOUNT_HANDLE` pour imposer la SIM par défaut) = appel immédiat, sans dialer ni numéro affiché. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants). Aucune notification envoyée (rien d'actionnable).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Telecom framework](https://developer.android.com/develop/connectivity/telecom) · [direct_call_plus](https://pub.dev/documentation/direct_call_plus/latest/) · [direct_caller_sim_choice](https://pub-web-s2.flutter-io.cn/packages/direct_caller_sim_choice/versions/1.0.3)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage107-netbuis.md -->

# Appel direct sans dialer — 107e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 106).

Contrôle : deux recherches standard (Android ACTION_CALL / TelecomManager.placeCall / PhoneAccountHandle ; paquets Flutter/RN d'appel direct dual SIM). Mêmes sources et mêmes paquets (direct_call_plus, direct_caller_sim_choice, flutter_direct_caller_plugin). Aucune restriction ni solution nouvelle.

- **Android** : permission CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (+ `EXTRA_PHONE_ACCOUNT_HANDLE` pour imposer la SIM par défaut) = appel immédiat, sans dialer ni numéro affiché. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants). Aucune notification envoyée (rien d'actionnable).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [direct_call_plus](https://pub.dev/documentation/direct_call_plus/latest/) · [direct_caller_sim_choice](https://pub-web-s2.flutter-io.cn/packages/direct_caller_sim_choice/versions/1.0.3)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage108-netbuis.md -->

# Appel direct sans dialer — 108e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 107).

Contrôle : deux recherches standard (Android ACTION_CALL / TelecomManager.placeCall / PhoneAccountHandle ; paquets Flutter d'appel direct dual SIM). Mêmes sources et mêmes paquets (direct_call_plus, direct_caller_sim_choice, flutter_direct_caller_plugin, direct_call). Aucune restriction ni solution nouvelle.

- **Android** : permission CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (+ `EXTRA_PHONE_ACCOUNT_HANDLE` pour imposer la SIM par défaut) = appel immédiat, sans dialer ni numéro affiché. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants). Aucune notification envoyée (rien d'actionnable).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [direct_call_plus](https://pub.dev/documentation/direct_call_plus/latest/) · [direct_caller_sim_choice](https://pub-web-s2.flutter-io.cn/packages/direct_caller_sim_choice/versions/1.0.3)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage109-netbuis.md -->

# Appel direct sans dialer — 109e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 108).

Contrôle : une recherche standard (TelecomManager.placeCall / PhoneAccountHandle / CALL_PHONE / Flutter dual SIM). Mêmes sources et mêmes paquets (direct_caller_sim_choice, flutter_phone_dialer). Aucune restriction ni solution nouvelle.

- **Android** : permission CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (+ `EXTRA_PHONE_ACCOUNT_HANDLE` pour imposer la SIM par défaut) = appel immédiat, sans dialer ni numéro affiché. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants). Aucune notification envoyée (rien d'actionnable).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Telecom framework](https://developer.android.com/develop/connectivity/telecom) · [direct_caller_sim_choice](https://pub-web-s2.flutter-io.cn/packages/direct_caller_sim_choice/versions/1.0.3)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage110-netbuis.md -->

# Appel direct sans dialer — 110e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 109).

Contrôle : une recherche standard (TelecomManager.placeCall / PhoneAccountHandle / default SIM / Flutter). Mêmes sources officielles Android, rien de nouveau.

- **Android** : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (+ `EXTRA_PHONE_ACCOUNT_HANDLE` pour la SIM par défaut) = appel immédiat sans dialer. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine, avancer sur le jalon 0 (30 commerçants). Aucune notification envoyée (rien d'actionnable).

Sources : [Telecom framework](https://developer.android.com/develop/connectivity/telecom) · [TelecomManager](https://developer.android.com/reference/kotlin/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage111-netbuis.md -->

# Appel direct sans dialer — 111e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 110).

Contrôle : une recherche standard (TelecomManager.placeCall / PhoneAccountHandle / SIM par défaut / politique Google Play). Seules les docs officielles Android et des commits de dialers AOSP ressortent, rien de nouveau.

- **Android** : permission CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (+ `EXTRA_PHONE_ACCOUNT_HANDLE` pour choisir la SIM) = appel immédiat sans passer par le dialer. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine, avancer sur le jalon 0 (30 commerçants). Aucune notification envoyée (rien d'actionnable).

Sources : [Telecom framework](https://developer.android.com/develop/connectivity/telecom) · [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage112-netbuis.md -->

# Appel direct sans dialer — 112e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 111).

Contrôle : une recherche standard (TelecomManager.placeCall, SIM par défaut, ACTION_CALL, plugins Flutter/RN). Seules les docs officielles Android et des commits de dialers AOSP/OmniROM ressortent.

- **Android** : permission CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (+ `EXTRA_PHONE_ACCOUNT_HANDLE` pour choisir la SIM) = appel immédiat sans passer par le dialer.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine, avancer sur le jalon 0 (30 commerçants). Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager.html) · [Handle preferred SIM for ACTION_CALL](https://gerrit.omnirom.org/plugins/gitiles/android_packages_apps_Dialer/+/01d9f64d245965d30a76bc6889c878f143fc86d7%5E)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage113-netbuis.md -->

# Appel direct sans dialer — 113e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 112).

Contrôle : une recherche standard (TelecomManager.placeCall, SIM par défaut, Flutter/RN). Seules les docs officielles Android et des tutoriels génériques ressortent.

- **Android** : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (+ `EXTRA_PHONE_ACCOUNT_HANDLE` pour la SIM) = appel immédiat sans dialer.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine, avancer sur le jalon 0 (30 commerçants). Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Telecom framework](https://developer.android.com/develop/connectivity/telecom)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage114-netbuis.md -->

# Appel direct sans dialer — 114e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `decision-finale-appels.md` et passages 1 à 113).

Contrôle : une recherche standard (TelecomManager.placeCall, SIM par défaut). Seule la doc officielle Android (TelecomManager) ressort, sans élément nouveau.

- **Android** : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (+ `EXTRA_PHONE_ACCOUNT_HANDLE` pour choisir la SIM) = appel lancé immédiatement, sans ouvrir le composeur.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative Twilio Voice + CallKit.

Recommandation inchangée : suspendre cette routine, avancer sur le jalon 0 (30 commerçants). Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage115-netbuis.md -->

# Appel direct sans dialer — 115e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. `recherche-appel-direct-sans-dialer-netbuis.md`, `decision-finale-appels.md` et passages précédents).

- **Android** : `CALL_PHONE` (+ `READ_PHONE_STATE`) ; `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut via `getDefaultOutgoingPhoneAccount("tel")`) = appel immédiat, sans dialer ni numéro affiché. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : la confirmation système sur `tel://` est incontournable ; alternative légitime : VoIP in-app (Twilio Voice + CallKit) ou WhatsApp.

Recommandation inchangée : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage116-netbuis.md -->

# Appel direct sans dialer — 116e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 115, `recherche-appel-direct-sans-dialer-netbuis.md`, `decision-finale-appels.md`).

- **Android** : `CALL_PHONE` + `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut) = appel immédiat sans dialer ni numéro affiché. Paquets RN/Flutter existants : react-native-immediate-phone-call, direct_call_plus. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : VoIP in-app (Twilio Voice + CallKit) ou WhatsApp.

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager/Telecom](https://developer.android.com/develop/connectivity/telecom) · [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call) · [Apple forum](https://developer.apple.com/forums/thread/679119)


---

<!-- source : recherche-appel-direct-verification-2026-10-11-passage117-netbuis.md -->

# Appel direct sans dialer — 117e passage (2026-10-11, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 116, `decision-finale-appels.md`).

- **Android** : `CALL_PHONE` + `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut) = appel immédiat sans dialer ni numéro affiché. Repli `ACTION_DIAL` si permission refusée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternative : VoIP in-app (Twilio Voice + CallKit) ou WhatsApp.

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Medium RN native calling](https://prayaslashkari98.medium.com/implementing-native-calling-functionality-in-react-native-71630846e455)


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage118-netbuis.md -->

# Appel direct sans dialer — 118e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 117, `decision-finale-appels.md`).

- **Android** : `CALL_PHONE` + `ACTION_CALL` ou `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut) = appel immédiat, sans dialer ni numéro affiché. Repli `ACTION_DIAL` si permission refusée. Aucune restriction nouvelle trouvée.
- **iOS** : confirmation système sur `tel://` incontournable ; alternatives : VoIP in-app (Twilio Voice + CallKit) ou WhatsApp.

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Android Dial Phone Programmatically](https://itnext.io/android-dial-phone-programmatically-5ea3714d801d)


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage119-netbuis.md -->

# Appel direct sans dialer — 119e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 118, `decision-finale-appels.md`).

- **Android** : `CALL_PHONE` + `ACTION_CALL` / `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut) = appel immédiat sans dialer ni numéro affiché. Aucune restriction nouvelle trouvée.
- **iOS** : confirmation système sur `tel://` incontournable ; CallKit ne sert qu'aux appels VoIP in-app (Twilio Voice) ; alternative : WhatsApp.

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Apple CallKit VoIP](https://developer.apple.com/documentation/callkit/making-and-receiving-voip-calls.md)


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage120-netbuis.md -->

# Appel direct sans dialer — 120e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 119, `decision-finale-appels.md`).

- **Android** : `CALL_PHONE` + `ACTION_CALL` / `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut) = appel immédiat, sans dialer ni numéro affiché. Aucune restriction nouvelle trouvée dans la documentation.
- **iOS** : confirmation système sur `tel://` incontournable ; CallKit réservé au VoIP in-app (Twilio Voice) ; alternative : WhatsApp.

Recommandation : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage121-netbuis.md -->

# Appel direct sans dialer — 121e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 120, `decision-finale-appels.md`).

- **Android** : `CALL_PHONE` + `ACTION_CALL` / `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut) = appel immédiat, sans dialer ni numéro affiché. Aucune restriction nouvelle trouvée.
- **iOS** : confirmation système sur `tel://` incontournable ; CallKit réservé au VoIP in-app (Twilio Voice) ; alternative : WhatsApp.

Recommandation : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage122-netbuis.md -->

# Appel direct sans dialer — 122e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 121, `decision-finale-appels.md`).

- **Android** : `CALL_PHONE` + `ACTION_CALL` / `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut) = appel immédiat sans dialer ni numéro affiché. Recherche du jour : seules les restrictions Play sur SMS / Call Log (et enregistrement d'appels) remontent ; aucune restriction nouvelle sur CALL_PHONE.
- **iOS** : confirmation système sur `tel://` incontournable ; CallKit = VoIP in-app (Twilio Voice) ; alternative WhatsApp.

Recommandation : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage123-netbuis.md -->

# Appel direct sans dialer — 123e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 122, `decision-finale-appels.md`).

- **Android** : `CALL_PHONE` + `ACTION_CALL` / `TelecomManager.placeCall` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut) = appel immédiat sans dialer ni numéro affiché. Aucune nouvelle restriction Play sur CALL_PHONE trouvée (seules SMS/Call Log restent restreintes).
- **iOS** : confirmation système sur `tel://` toujours incontournable ; CallKit = VoIP in-app uniquement. Nouveauté mineure sans impact : thread Apple signalant que, côté iOS 27 (bêta), les liens `tel:` contenant des codes de renvoi d'appel sont bloqués ("Malicious Link Blocked") — non pertinent pour des numéros normaux. Alternative : WhatsApp / Twilio Voice in-app.

Recommandation : suspendre cette routine et avancer sur le jalon 0 (30 commerçants).


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage124-netbuis.md -->

# Appel direct sans dialer — 124e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 123, `decision-finale-appels.md`).

- Android : CALL_PHONE + ACTION_CALL / TelecomManager.placeCall avec EXTRA_PHONE_ACCOUNT_HANDLE (SIM par défaut) = appel immédiat, sans dialer ni numéro affiché. Aucune nouvelle restriction trouvée.
- iOS : confirmation système sur tel:// toujours incontournable (seul fil récent : blocage des codes de renvoi d'appel en iOS 27 bêta, non pertinent). Alternative : WhatsApp / Twilio Voice in-app.

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants).


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage125-netbuis.md -->

# Appel direct sans dialer — 125e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 124, `decision-finale-appels.md`).

- Android : CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (EXTRA_PHONE_ACCOUNT_HANDLE pour la SIM par défaut) = appel immédiat sans dialer. Recherche du jour : aucune nouvelle restriction trouvée (documentation TelecomManager inchangée).
- iOS : confirmation système sur tel:// toujours incontournable. Alternative : WhatsApp / Twilio Voice in-app.

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants).


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage126-netbuis.md -->

# Appel direct sans dialer — 126e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 125, `decision-finale-appels.md`).

- Android : CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (EXTRA_PHONE_ACCOUNT_HANDLE pour choisir la SIM par défaut) = appel immédiat sans ouvrir le dialer ni afficher le numéro. Recherche du jour : aucune nouvelle restriction (doc TelecomManager inchangée).
- iOS : confirmation système sur tel:// incontournable. Alternatives : WhatsApp / Twilio Voice in-app.

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants).


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage127-netbuis.md -->

# Appel direct sans dialer — 127e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 126, `decision-finale-appels.md`).

- Android : CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (EXTRA_PHONE_ACCOUNT_HANDLE pour la SIM par défaut) = appel immédiat, sans dialer ni numéro affiché. Recherche du jour : aucune nouvelle restriction trouvée (doc TelecomManager).
- iOS : confirmation système sur tel:// toujours incontournable. Seul fait notable : un fil développeur Apple signale que iOS 27 bloque les liens tel: contenant des codes de renvoi d'appel (sans impact pour des numéros normaux). Alternatives : WhatsApp / Twilio Voice in-app.

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants).


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage128-netbuis.md -->

# Appel direct sans dialer — 128e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 127, `decision-finale-appels.md`).

- Android : CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (EXTRA_PHONE_ACCOUNT_HANDLE pour choisir la SIM par défaut) lance l'appel immédiatement, sans dialer ni numéro affiché. Recherche du jour : aucune nouvelle restriction trouvée. Rappel : la politique Google Play limite les permissions Appels/SMS pour les apps qui ne sont pas gestionnaire par défaut ; à vérifier au moment de la publication (déclaration de permission).
- iOS : confirmation système sur tel:// incontournable. Alternatives : WhatsApp / Twilio Voice in-app.

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants).


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage129-netbuis.md -->

# Appel direct sans dialer — 129e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 128, `decision-finale-appels.md`).

- Android : CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (EXTRA_PHONE_ACCOUNT_HANDLE pour la SIM par défaut) = appel immédiat, sans dialer ni numéro affiché. Repli ACTION_DIAL. Plugin RN : react-native-immediate-phone-call. Recherche du jour : aucune nouvelle restriction.
- iOS : confirmation système sur tel:// incontournable ; alternatives : WhatsApp wa.me / Twilio Voice in-app.

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call)


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage130-netbuis.md -->

# Appel direct sans dialer — 130e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 129, `decision-finale-appels.md`).

- Android : CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (EXTRA_PHONE_ACCOUNT_HANDLE pour la SIM par défaut) = appel immédiat sans ouvrir le dialer ni afficher le numéro. Recherche du jour : seule la doc officielle TelecomManager ressort, aucune nouvelle restriction.
- iOS : confirmation système sur tel:// incontournable ; alternatives : WhatsApp / Twilio Voice + CallKit.

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants). Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage131-netbuis.md -->

# Appel direct sans dialer — 131e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 130, `decision-finale-appels.md`).

- Android : CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (EXTRA_PHONE_ACCOUNT_HANDLE pour la SIM par défaut) = appel immédiat sans ouvrir le dialer ni afficher le numéro. Recherche du jour : seule la doc officielle TelecomManager ressort, aucune nouvelle restriction.
- iOS : confirmation système sur tel:// incontournable ; alternatives : WhatsApp / Twilio Voice + CallKit.

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants). Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage132-netbuis.md -->

# Appel direct sans dialer — 132e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 131, `decision-finale-appels.md`).

- Android : CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (EXTRA_PHONE_ACCOUNT_HANDLE pour choisir la SIM par défaut) lance l'appel immédiatement, sans dialer ni affichage du numéro. Recherche du jour : toujours uniquement la doc officielle, aucune nouvelle restriction.
- iOS : confirmation système sur tel:// incontournable ; alternatives : WhatsApp / Twilio Voice + CallKit.

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants). Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage133-netbuis.md -->

# Appel direct sans dialer — 133e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passages 131-132, `decision-finale-appels.md`).

- Android : permission CALL_PHONE + `Intent.ACTION_CALL` ou `TelecomManager.placeCall()` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (choix de la SIM par défaut) lance l'appel immédiatement, sans ouvrir le dialer ni afficher le numéro. Aucune nouvelle restriction trouvée dans la doc officielle.
- iOS : confirmation système obligatoire sur tel:// ; alternatives : WhatsApp / Twilio Voice + CallKit.

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants). Aucune notification envoyée (rien de nouveau).

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager), [Telecom framework](https://developer.android.com/develop/connectivity/telecom)


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage134-netbuis.md -->

# Appel direct sans dialer — 134e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passages 131-133, `decision-finale-appels.md`).

- Android : CALL_PHONE + `Intent.ACTION_CALL` ou `TelecomManager.placeCall()` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut) lance l'appel sans ouvrir le dialer. Recherche web refaite : aucune nouvelle restriction trouvée.
- iOS : confirmation système obligatoire sur tel:// ; alternatives : WhatsApp / Twilio Voice + CallKit.

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants). Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage135-netbuis.md -->

# Appel direct sans dialer — 135e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 134, `decision-finale-appels.md`).

- Android : CALL_PHONE + `Intent.ACTION_CALL` ou `TelecomManager.placeCall()` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut) lance l'appel directement, sans ouvrir le dialer. Nouvelle recherche web : aucune nouvelle restriction trouvée.
- iOS : confirmation système obligatoire sur tel:// ; alternatives : WhatsApp / Twilio Voice + CallKit.

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants). Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage136-netbuis.md -->

# Appel direct sans dialer — 136e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 135, `decision-finale-appels.md`).

- Android : CALL_PHONE + `Intent.ACTION_CALL` ou `TelecomManager.placeCall()` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut) lance l'appel directement, sans dialer ni numéro affiché. Nouvelle recherche web : aucune nouvelle restriction trouvée. Rappel : la politique Google Play limite les permissions Appels/SMS ; à vérifier à la publication.
- iOS : confirmation système obligatoire sur tel:// ; alternatives : WhatsApp / Twilio Voice + CallKit.

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants). Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage137-netbuis.md -->

# Appel direct sans dialer — 137e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 136, `decision-finale-appels.md`).

- Android : CALL_PHONE + `Intent.ACTION_CALL` ou `TelecomManager.placeCall()` avec `EXTRA_PHONE_ACCOUNT_HANDLE` (SIM par défaut) lance l'appel directement, sans dialer. Nouvelle recherche web : seule la documentation TelecomManager remonte, aucune nouvelle restriction. Rappel : la politique Google Play limite les permissions Appels/SMS ; à vérifier à la publication.
- iOS : confirmation système obligatoire sur tel:// ; alternatives : WhatsApp / Twilio Voice + CallKit.

Recommandation : suspendre cette routine, avancer sur le jalon 0 (30 commerçants). Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-12-passage138-netbuis.md -->

# Appel direct sans dialer — 138e passage (2026-10-12, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 137, `decision-finale-appels.md`).

- Android : permission CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (avec `EXTRA_PHONE_ACCOUNT_HANDLE` pour la SIM par défaut) = appel immédiat, sans dialer ni numéro affiché. Repli `ACTION_DIAL` si permission refusée. Packages utiles : react-native-immediate-phone-call (RN), direct_caller_sim_choice (Flutter, choix de SIM).
- iOS : confirmation système sur `tel://` incontournable ; alternatives : WhatsApp / Twilio Voice + CallKit in-app.

Recommandation : suspendre cette routine ; avancer sur le jalon 0 (30 commerçants). Aucune notification envoyée (rien de nouveau).

Sources : [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call) · [direct_caller_sim_choice](https://pub-web-s2.flutter-io.cn/packages/direct_caller_sim_choice/versions/1.0.3) · [ACTION_CALL par intent](https://codemia.io/knowledge-hub/path/how_to_make_a_phone_call_using_intent_in_android)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage139-netbuis.md -->

# Appel direct sans dialer — 139e passage (2026-10-13, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 138, `decision-finale-appels.md`).

- Android : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` avec `PhoneAccountHandle` (SIM par défaut) = appel immédiat sans dialer. Repli `ACTION_DIAL`.
- iOS : confirmation système sur `tel://` incontournable ; alternatives WhatsApp / Twilio Voice + CallKit.

Recommandation : suspendre cette routine, avancer sur le jalon 0. Aucune notification envoyée.

Sources : [Android Telecom framework](https://developer.android.com/develop/connectivity/telecom) · [PhoneAccount](https://developer.android.com/reference/android/telecom/PhoneAccount)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage140-netbuis.md -->

# Appel direct sans dialer — 140e passage (2026-10-13, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 139, `decision-finale-appels.md`).

- Android : permission CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` avec `PhoneAccountHandle` (choix de SIM) = appel immédiat sans ouvrir le dialer. Repli `ACTION_DIAL`.
- iOS : confirmation système sur `tel://` incontournable ; alternatives WhatsApp / Twilio Voice + CallKit.

Recommandation : suspendre cette routine et avancer sur le jalon 0. Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [PhoneAccount](https://developer.android.com/reference/android/telecom/PhoneAccount)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage141-netbuis.md -->

# Appel direct sans dialer — 141e passage (2026-10-13, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 140, `decision-finale-appels.md`).

- Android : permission CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` avec `PhoneAccountHandle` (choix de SIM par défaut) = appel immédiat, sans dialer ni numéro affiché. Repli `ACTION_DIAL`.
- iOS : confirmation système sur `tel://` incontournable ; alternatives WhatsApp / Twilio Voice + CallKit.

Recommandation : suspendre cette routine et avancer sur le jalon 0. Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [Telecom framework](https://developer.android.com/develop/connectivity/telecom)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage142-netbuis.md -->

# Appel direct sans dialer — 142e passage (2026-10-13, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 141, `decision-finale-appels.md`).

- Android : permission CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` avec `PhoneAccountHandle` (SIM par défaut) = appel immédiat sans dialer ni numéro affiché. Plugins existants : `flutter_phone_direct_caller` (2.2.1), `react-native-immediate-phone-call`. Repli `ACTION_DIAL`.
- iOS : confirmation système sur `tel://` incontournable ; alternatives WhatsApp / Twilio Voice + CallKit.

Recommandation : suspendre cette routine et avancer sur le jalon 0. Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller) · [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage143-netbuis.md -->

# Appel direct sans dialer — 143e passage (2026-10-13, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 142, `decision-finale-appels.md`).

- Android : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` avec `PhoneAccountHandle` (SIM par défaut) = appel immédiat sans dialer ni numéro affiché. Plugins : `flutter_phone_direct_caller`, `react-native-immediate-phone-call`. Repli `ACTION_DIAL`.
- iOS : confirmation système sur `tel://` incontournable ; alternatives WhatsApp / Twilio Voice + CallKit.

Recommandation : suspendre cette routine et avancer sur le jalon 0. Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage144-netbuis.md -->

# Appel direct sans dialer — 144e passage (2026-10-13, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 143, `decision-finale-appels.md`).

- Android : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` avec `PhoneAccountHandle` (SIM par défaut) = appel immédiat, sans dialer ni numéro affiché. Plugins : `flutter_phone_direct_caller` (2.2.1), `react-native-immediate-phone-call`. Repli `ACTION_DIAL`.
- iOS : confirmation système sur `tel://` incontournable ; alternatives WhatsApp / Twilio Voice + CallKit.

Recommandation : suspendre cette routine et avancer sur le jalon 0. Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager) · [flutter_phone_direct_caller](https://pub.dev/packages/flutter_phone_direct_caller)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage145-netbuis.md -->

# Appel direct sans dialer — 145e passage (2026-10-13, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 144, `decision-finale-appels.md`).

- Android : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` avec `PhoneAccountHandle` (SIM par défaut) = appel immédiat, sans dialer ni numéro affiché. Plugins : `flutter_phone_direct_caller`, `react-native-immediate-phone-call`. Repli `ACTION_DIAL`.
- iOS : confirmation système sur `tel://` incontournable ; alternatives WhatsApp / Twilio Voice + CallKit.

Recommandation : suspendre cette routine et avancer sur le jalon 0. Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage146-netbuis.md -->

# Appel direct sans dialer — 146e passage (2026-10-13, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 145, `decision-finale-appels.md`).

- Android : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (PhoneAccountHandle = SIM par défaut) = appel immédiat sans dialer. Repli `ACTION_DIAL`.
- iOS : confirmation système sur `tel://` incontournable ; alternatives WhatsApp / Twilio Voice + CallKit.

Recommandation : suspendre cette routine, avancer sur le jalon 0. Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage147-netbuis.md -->

# Appel direct sans dialer — 147e passage (2026-10-13, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 146, `decision-finale-appels.md`).

- Android : permission CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (PhoneAccountHandle = SIM par défaut) lance l'appel immédiatement, sans ouvrir le dialer ni afficher le numéro. Repli : `ACTION_DIAL`.
- iOS : la confirmation système sur `tel://` est incontournable ; alternatives : WhatsApp / Twilio Voice + CallKit.

Recommandation : suspendre cette routine et avancer sur le jalon 0. Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage148-netbuis.md -->

# Appel direct sans dialer — 148e passage (2026-10-13, tâche planifiée)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 147, `decision-finale-appels.md`).

- Android : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (PhoneAccountHandle = SIM par défaut) lance l'appel sans dialer ni affichage du numéro. Repli : `ACTION_DIAL`.
- iOS : confirmation système sur `tel://` incontournable ; alternatives : WhatsApp / Twilio Voice + CallKit.
- Recherche web du jour : seule la doc officielle TelecomManager remonte, aucun changement de politique trouvé.

Recommandation : suspendre cette routine et avancer sur le jalon 0. Aucune notification envoyée.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage149-netbuis.md -->

# Appel direct sans dialer — 149e passage (2026-10-13 11:33 UTC, routine « recherche solutions »)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 148, `recherche-appel-direct-sans-dialer-netbuis.md`).

- Android : permission CALL_PHONE + `ACTION_CALL`, ou `TelecomManager.placeCall` avec `getDefaultOutgoingPhoneAccount("tel")` pour la SIM par défaut, lance l'appel en un clic sans ouvrir le dialer ni afficher le numéro. Repli : `ACTION_DIAL` si permission refusée.
- iOS : confirmation système sur `tel://` incontournable ; alternatives : WhatsApp (`wa.me`) ou Twilio Voice + CallKit (VoIP).
- Recherche web du jour (« CALL_PHONE ACTION_CALL Google Play policy 2026 ») : les résultats portent sur les permissions SMS / Journal d'appels et la vérification des développeurs, pas sur CALL_PHONE. Aucun changement trouvé.

Sources : [Android Developers Blog, avril 2026](https://android-developers.googleblog.com/2026/04/giving-users-clearer-choice-and-everyone-a-safer-more-trusted-app-ecosystem.html), [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage150-netbuis.md -->

# Appel direct sans dialer — 150e passage (2026-10-13, couvre les exécutions de 12:34, 13:34 et 14:33 UTC traitées ensemble)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 149).

- Android : CALL_PHONE + `ACTION_CALL` ou `TelecomManager.placeCall` (SIM par défaut via `getDefaultOutgoingPhoneAccount("tel")`). Repli `ACTION_DIAL`.
- iOS : confirmation système sur `tel://` obligatoire ; alternatives WhatsApp / Twilio Voice + CallKit.
- Recherche web (« Android 17 TelecomManager placeCall CALL_PHONE changes ») : seule la doc de référence TelecomManager remonte, aucun changement signalé.

Sources : [TelecomManager](https://developer.android.com/reference/android/telecom/TelecomManager)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage151-netbuis.md -->

# Appel direct sans dialer — 151e passage (2026-10-13 15:34 UTC)

Conclusion : **inchangée, aucune nouveauté** (cf. passages 149-150).

- Recherche web (« flutter direct phone call without dialer default SIM plugin 2026 ») : flutter_phone_direct_caller 2.1.1, direct_call_plus, flutter_direct_caller_plugin 0.0.4, tous déjà recensés depuis le 2026-10-06. Rien de nouveau.
- Solution inchangée : Android CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (SIM par défaut), repli ACTION_DIAL ; iOS confirmation obligatoire.

Sources : [flutter_phone_direct_caller](https://pub-web.flutter-io.cn/packages/flutter_phone_direct_caller), [direct_call_plus](https://pub.dev/documentation/direct_call_plus/latest/)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage152-netbuis.md -->

# Appel direct sans dialer — 152e passage (2026-10-13 16:33 UTC)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 151).

- Recherche web (« iOS 26 tel URL call confirmation bypass CallKit 2026 ») : fil Apple « iOS 27 : liens tel: avec codes de renvoi d'appel bloqués » déjà recensé (passages 123-127) ; il ne concerne pas les numéros simples de NetBuis. Confirmation `tel://` toujours obligatoire sur iOS.
- Android inchangé : CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (SIM par défaut), repli ACTION_DIAL.

Sources : [Apple Forums 847164](https://developer.apple.com/forums/thread/847164), [Apple Forums 73406](https://developer.apple.com/forums/thread/73406)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage153-netbuis.md -->

# Appel direct sans dialer — 153e passage (2026-10-13 17:33 UTC)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 152).

- Recherche web (« react native expo direct call ACTION_CALL dual SIM PhoneAccountHandle ») : react-native-immediate-phone-call et l'extrait B4X « Dual SIM call » (EXTRA_PHONE_ACCOUNT_HANDLE), déjà connus. Rien de nouveau.
- Solution inchangée : Android CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (SIM par défaut ou SIM choisie via PhoneAccountHandle), repli ACTION_DIAL ; iOS confirmation obligatoire.

Sources : [react-native-immediate-phone-call](https://github.com/wumke/react-native-immediate-phone-call), [B4X Dual SIM call](https://www.b4x.com/android/forum/threads/dual-sim-call.101443/)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage154-netbuis.md -->

# Appel direct sans dialer — 154e passage (2026-10-13 18:33 UTC)

Conclusion : **inchangée, aucune nouveauté sur CALL_PHONE** (cf. passage 153).

- Recherche web (« Google Play permissions policy update CALL_PHONE declaration 2026 ») : article sur la mise à jour Play de juillet 2026 lu. Il ne mentionne pas CALL_PHONE. Changements : IA tierce soumise à la politique Données utilisateur ; READ_CALL_LOG n'autorise plus la vérification de compte par appel ; enregistrement des apps dans Play Console ; ciblage API 36 pour nouvelles apps et mises à jour avant le 31/08/2026 (déjà connu, cf. audit v14) ; apps non classées interdites.
- Impact NetBuis : aucun sur l'appel en un clic (NetBuis n'utilise pas READ_CALL_LOG). Solution inchangée : Android CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (SIM par défaut), repli ACTION_DIAL ; iOS confirmation obligatoire.

Sources : [ecorpit — Google Play July 2026 policy update](https://ecorpit.com/google-play-july-2026-policy-update-ai-user-data-compliance/)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage155-netbuis.md -->

# Appel direct sans dialer — 155e passage (2026-10-13 19:33 UTC)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 154).

- Recherche web (« Android 17 ACTION_CALL background activity launch restriction ») : la page « secure BAL » (restrictions sur le lancement d'activités en arrière-plan) concerne les lancements depuis un service ou une app en arrière-plan. NetBuis lance l'appel depuis un clic au premier plan, donc non concerné. À garder en tête : ne jamais déclencher ACTION_CALL depuis une notification ou un service sans interaction.
- Solution inchangée : Android CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (SIM par défaut), repli ACTION_DIAL ; iOS confirmation obligatoire.

Sources : [Secure background activity launches](https://developer.android.com/guide/components/activities/secure-bal)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage156-netbuis.md -->

# Appel direct sans dialer — 156e passage (2026-10-13 20:33 UTC)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 155).

- Recherche web (« ACTION_CALL dual SIM default "ask every time" ») : seulement des guides opérateurs pour régler la SIM par défaut. Rappel déjà acquis : si le téléphone est réglé sur « Toujours demander », `getDefaultOutgoingPhoneAccount("tel")` renvoie null et le système affiche son choix de SIM ; NetBuis peut l'éviter en proposant son propre choix une fois (mémorisé) puis en passant `EXTRA_PHONE_ACCOUNT_HANDLE` à `placeCall`.
- Solution inchangée : Android CALL_PHONE + ACTION_CALL / TelecomManager.placeCall, repli ACTION_DIAL ; iOS confirmation obligatoire.

Sources : [AT&T — SIM par défaut (Samsung)](https://www.att.com/device-support/article/145326/samsung/galaxy-a56-5g/)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage157-netbuis.md -->

# Appel direct sans dialer — 157e passage (2026-10-13 21:33 UTC)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 156).

- Recherche web (« Kotlin TelecomManager placeCall example CALL_PHONE 2026 ») : doc de référence TelecomManager, tutoriels Vonage/Telekom « app-to-phone » (VoIP payant, équivalent Twilio, déjà écarté pour le flux opérateur), page Android « redirect a call » (réservée aux apps de redirection d'appel). Rien de nouveau.
- Solution inchangée : Android CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (SIM par défaut), repli ACTION_DIAL ; iOS confirmation obligatoire.

Sources : [TelecomManager (Kotlin)](https://developer.android.com/reference/kotlin/android/telecom/TelecomManager), [Vonage app-to-phone](https://developer.vonage.com/en/tutorials/vg-app-to-phone/place-call/kotlin)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage158-netbuis.md -->

# Appel direct sans dialer — 158e passage (2026-10-13 22:33 UTC)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 157).

- Recherche web (« CALL_PHONE Play Console permission declaration form ») : page Play 9047303 (SMS / Journal d'appels), déjà connue ; CALL_PHONE ne figure pas parmi les permissions soumises au formulaire de déclaration. Fils Kodular/Thunkable anciens (2018-2020), sans nouveauté.
- Solution inchangée : Android CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (SIM par défaut), repli ACTION_DIAL ; iOS confirmation obligatoire.

Sources : [Play — permissions SMS / Journal d'appels](https://support.google.com/googleplay/android-developer/answer/9047303)


---

<!-- source : recherche-appel-direct-verification-2026-10-13-passage159-netbuis.md -->

# Appel direct sans dialer — 159e passage (2026-10-13 23:33 UTC)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 158).

- Recherche web (« one tap call app Africa Android direct dial merchant marketplace ») : résultats hors sujet (Odoo CTI, AfriCallShop VoIP, boutons d'appel Shopify `tel:`). Aucune nouvelle technique.
- Solution inchangée : Android CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (SIM par défaut), repli ACTION_DIAL ; iOS confirmation obligatoire.

Sources : aucune pertinente.


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage160-netbuis.md -->

# Appel direct sans dialer — 160e passage (2026-10-14 00:33 UTC)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 159).

- Recherche web (« Capacitor Ionic plugin direct call without dialer CALL_PHONE ») : plugin Ionic « Call Number » (bypassAppChooser, Android = ACTION_CALL), package npm phone-call, direct_call_plus 1.0.4 (Flutter). Même mécanisme ACTION_CALL que celui déjà retenu ; rien de nouveau.
- Solution inchangée : Android CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (SIM par défaut), repli ACTION_DIAL ; iOS confirmation obligatoire.

Sources : [Ionic Call Number](https://ionicframework.com/docs/native/call-number), [direct_call_plus](https://pub.dev/documentation/direct_call_plus/latest/)


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage161-netbuis.md -->

# Appel direct sans dialer — 161e passage (2026-10-14 01:33 UTC)

Conclusion : **inchangée, aucune nouveauté** (cf. passage 160).

- Recherche web (« KaiOS feature phone app direct call telephony API ») : doc KaiOS Smart Feature Phone 3.0 et articles sur les lancements KaiOS en Afrique (déjà couverts par l'audit v11 « téléphones simples »). Rien de nouveau pour l'appel en un clic.
- Solution inchangée : Android CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (SIM par défaut), repli ACTION_DIAL ; iOS confirmation obligatoire.

Sources : [KaiOS SFP 3.0 API samples](https://developer.kaiostech.com/docs/sfp-3.0/api/new-api-samples)


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage162-netbuis.md -->

# Appel direct sans dialer — 162e passage (2026-10-14 02:33 UTC)

Conclusion : **inchangée, aucune nouveauté sur l'appel en un clic** (cf. passage 161).

- Lu : notes de version AOSP Android 17. Côté téléphonie, seulement le routage automatique des appels OTT (WhatsApp, etc.) sur un réseau premium et la refonte SCO Bluetooth. Rien sur CALL_PHONE, ACTION_CALL, le dialer ou le choix de SIM.
- Lu : checklist sécurité Android 17 (hivesecurity). Rien sur les appels. À noter pour d'autres chantiers NetBuis : délai sur les OTP SMS, permission ACCESS_LOCAL_NETWORK, nouveau sélecteur de contacts.
- Solution inchangée : Android CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (SIM par défaut), repli ACTION_DIAL ; iOS confirmation obligatoire.

Sources : [Android 17 release (AOSP)](https://source.android.com/docs/whatsnew/android-17-release), [Android 17 security checklist](https://hivesecurity.gitlab.io/blog/android-17-update-security-privacy-checklist)


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage163-netbuis.md -->

# Appel direct sans dialer — 163e passage (2026-10-14 03:33 UTC)

## Nouveauté iOS (première depuis le début de la routine)

Apple a ajouté dans **iOS 26** une API publique, **LiveCommunicationKit** (`TelephonyConversationManager` + `StartCellularConversationAction`), qui permet à une app tierce de lancer un **appel opérateur (cellulaire)**, avec choix de la ligne (`CellularService`, donc de la SIM).

Conditions (doc Apple « Preparing your app to be the default dialer app ») :
- L'app doit avoir l'entitlement `com.apple.developer.dialing-app`.
- **Sans confirmation** uniquement si l'utilisateur a choisi l'app comme **app de numérotation par défaut** (« default dialer app ») dans les réglages iOS. Sinon, la boîte de confirmation système reste affichée.
- Fonction **réservée à l'Union européenne** : compte développeur enregistré dans l'UE et appareil situé dans l'UE (cadre DMA).

## Impact pour NetBuis
- **Cameroun : non applicable.** Hors UE, la confirmation `tel://` reste obligatoire sur iPhone. La conclusion iOS ne change pas pour le marché cible.
- Si un jour NetBuis vise la diaspora en Europe : possible, mais il faudrait que l'utilisateur fasse de NetBuis son app d'appel par défaut, ce qui est peu réaliste pour une app de commerce.
- Android inchangé : CALL_PHONE + ACTION_CALL / TelecomManager.placeCall (SIM par défaut), repli ACTION_DIAL.

Sources : [StartCellularConversationAction](https://developer.apple.com/documentation/livecommunicationkit/startcellularconversationaction), [Preparing your app to be the default dialer app](https://developer.apple.com/documentation/livecommunicationkit/preparing-your-app-to-be-the-default-dialer-app)


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage164-netbuis.md -->

# Appel direct sans dialer — 164e passage (2026-10-14 04:33 UTC)

Conclusion inchangée par rapport au passage 163.

- Android : CALL_PHONE + ACTION_CALL ou TelecomManager.placeCall, SIM via getDefaultOutgoingPhoneAccount("tel") / EXTRA_PHONE_ACCOUNT_HANDLE, repli ACTION_DIAL. Aucune nouveauté trouvée.
- iOS : tel:// garde la confirmation ; exception iOS 26 « app d'appel par défaut » limitée à l'UE (voir passage 163), non applicable au Cameroun.

Sources : https://developer.android.com/reference/android/telecom/TelecomManager.html , https://itnext.io/android-dial-phone-programmatically-5ea3714d801d


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage165-netbuis.md -->

# Appel direct sans dialer — 165e passage (2026-10-14 05:33 UTC)

Conclusion inchangée (voir passages 163 et 164).

- Recherche : changements Android 17 sur ACTION_CALL / SIM par défaut / PhoneAccountHandle. Aucun résultat nouveau ; seule la référence TelecomManager ressort.
- Android : CALL_PHONE + ACTION_CALL ou TelecomManager.placeCall, SIM via getDefaultOutgoingPhoneAccount("tel"), repli ACTION_DIAL.
- iOS : confirmation obligatoire hors UE.

Sources : https://developer.android.com/reference/android/telecom/TelecomManager.html


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage166-netbuis.md -->

# Appel direct sans dialer — 166e passage (2026-10-14 06:34 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : « React Native Expo direct phone call without dialer CALL_PHONE 2026 ».
- Déjà connu : react-native-immediate-phone-call (ACTION_CALL Android).
- Petite note : le changelog Twilio du 25/09/2026 annonce le support d'Expo dans le SDK Voice React Native. Cela concerne uniquement la piste VoIP, abandonnée le 30/09 (voir decision-finale-appels.md). C'est à garder seulement si une v2 VoIP revient. Rien ne change pour l'appel opérateur direct.
- Article Software Mansion « alternatives à react-native-callkeep en 2026 » : sujet CallKit/VoIP, pas l'appel opérateur.

Sources : https://github.com/wumke/react-native-immediate-phone-call , https://www.twilio.com/en-us/changelog/twilio-voice-react-native-sdk-adds-expo-support , https://swmansion.com/blog/react-native-callkeep-alternative-2026/


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage167-netbuis.md -->

# Appel direct sans dialer — 167e passage (2026-10-14 07:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : plugins Flutter pour l'appel direct avec SIM par défaut.
- Résultats déjà connus : flutter_phone_direct_caller, direct_caller_sim_choice et flutter_direct_caller_plugin. Tous reposent sur ACTION_CALL + CALL_PHONE côté Android et sur tel:// côté iOS.
- Rien de nouveau.

Sources : https://fluttergems.dev/packages/flutter_phone_direct_caller/ , https://pub-web-s2.flutter-io.cn/packages/direct_caller_sim_choice/versions/1.0.3


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage168-netbuis.md -->

# Appel direct sans dialer — 168e passage (2026-10-14 08:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : comportement double SIM / « toujours demander » avec ACTION_CALL (Samsung One UI, Google Phone).
- Android Authority (1er juin 2026) : la bêta de Google Phone (v224) teste un sélecteur de SIM préférée au-dessus du clavier. Il ne concerne que l'app Téléphone elle-même ; rien n'est dit sur ACTION_CALL ni sur les apps tierces. Aucun impact sur NetBuis.
- Le patch OmniROM « Handle preferred SIM for ACTION_CALL » et les fils Samsung Community sont anciens (One UI 3) et déjà couverts : si l'utilisateur a réglé « toujours demander », le système affiche le choix de SIM. NetBuis peut contourner cela en passant EXTRA_PHONE_ACCOUNT_HANDLE (choix mémorisé dans l'app).

Sources : https://androidauthority.com/google-phone-dual-sim-selection-fix-3672991/ , https://gerrit.omnirom.org/plugins/gitiles/android_packages_apps_Dialer/+/01d9f64d245965d30a76bc6889c878f143fc86d7%5E


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage169-netbuis.md -->

# Appel direct sans dialer — 169e passage (2026-10-14 09:34 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : PWA / web app qui appelle directement, sans passer par le dialer.
- Résultats déjà connus :
  - Une PWA reste limitée à tel:, qui ouvre toujours le dialer.
  - Pipedrive « web-to-mobile » fonctionne via une app native.
  - Le plugin Flutter direct_call_plus repose sur ACTION_CALL.
- L'app native Android avec CALL_PHONE reste la seule voie sans second clic.

Sources : https://progressier.com/pwa-capabilities/phone-call-pwa-demo , https://support.pipedrive.com/en/article/web-to-mobile-calling , https://pub.dev/documentation/direct_call_plus/latest/


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage170-netbuis.md -->

# Appel direct sans dialer — 170e passage (2026-10-14 10:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : Jetpack Core-Telecom 2026 pour passer un appel opérateur.
- Core-Telecom ne sert qu'aux appels VoIP (self-managed). Il ne permet pas de passer un appel opérateur à la place d'ACTION_CALL / TelecomManager.placeCall.
- Rien de nouveau.

Sources : https://d.android.com/develop/connectivity/telecom/voip-app/telecom , https://developer.android.com/develop/connectivity/telecom/selfManaged?authuser=1


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage171-netbuis.md -->

# Appel direct sans dialer — 171e passage (2026-10-14 11:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : la fonction iOS « app d'appel par défaut » (LiveCommunicationKit) a-t-elle été étendue hors de l'UE ?
- Résultats : les forums Apple Developer et MacRumors confirment que l'éligibilité reste limitée à l'UE.
- Aucune annonce d'extension à d'autres pays, donc rien pour le Cameroun.

Sources : https://developer.apple.com/forums/thread/798174 , https://developer.apple.com/forums/thread/797975 , https://forums.macrumors.com/threads/ios-26-allows-cellular-calls-and-sms-rcs-in-third-party-apps-in-eu.2461213/


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage172-netbuis.md -->

# Appel direct sans dialer — 172e passage (2026-10-14 12:34 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : masquer le numéro dans l'écran d'appel en cours sur Android (ACTION_CALL).
- Les résultats parlent uniquement de masquer l'identifiant de l'appelant (CLIR) chez le destinataire, pas de cacher le numéro à l'utilisateur sur son propre écran d'appel. Rien d'utile.
- Rappel : avec ACTION_CALL, le dialer n'est pas ouvert pour composer, mais l'écran d'appel en cours du système affiche le numéro. Un numéro masqué de bout en bout reste possible seulement via une app d'appel par défaut (ROLE_DIALER + InCallService) ou un pont VoIP/PSTN côté serveur.

Sources : https://www.sony.ie/electronics/support/articles/SX691801


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage173-netbuis.md -->

# Appel direct sans dialer — 173e passage (2026-10-14 13:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : API opérateur MTN / Orange Cameroun de type « click-to-call » (2026).
- Résultats : uniquement des tarifs, du mobile money et des actualités opérateurs. Aucune API publique d'appel côté opérateur n'apparaît.
- Rien de nouveau.

Sources : https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026 , https://fr.journalducameroun.com/2026-commence-bien-pour-les-clients-dorange-cameroun/


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage174-netbuis.md -->

# Appel direct sans dialer — 174e passage (2026-10-14 14:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : plugins Capacitor/Ionic pour l'appel direct.
- Résultats déjà connus :
  - Capawesome phone-dialer ouvre le dialer.
  - Ionic call-number (option bypassAppChooser) et capacitor-plugin-phone-call reposent sur ACTION_CALL + CALL_PHONE côté Android.
  - Côté iOS, ces plugins passent par tel:// avec confirmation.
- Rien de nouveau.

Sources : https://capawesome.io/docs/sdks/capacitor/phone-dialer/ , https://ionicframework.com/docs/native/call-number , https://www.jsdelivr.com/package/npm/capacitor-plugin-phone-call


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage175-netbuis.md -->

# Appel direct sans dialer — 175e passage (2026-10-14 15:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : changements Android 17 QPR2 liés à CALL_PHONE.
- Nouveau point mineur relevé dans les release notes Android 17 QPR2 :
  - `sendUssdRequest()` ne peut plus envoyer de codes de renvoi d'appel avec la seule permission CALL_PHONE (erreur USSD_ERROR_NOT_ALLOWED en arrière-plan).
  - Google recommande ACTION_DIAL pour ces codes.
- Impact pour NetBuis : aucun sur l'appel direct vers un numéro normal (ACTION_CALL / placeCall non mentionnés).
- À garder en tête uniquement si NetBuis utilise un jour des codes USSD, par exemple pour le mobile money. La restriction ne vise que les codes de renvoi d'appel.

Sources : https://developer.android.com/about/versions/17/qpr2/release-notes?hl=en


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage176-netbuis.md -->

# Appel direct sans dialer — 176e passage (2026-10-14 16:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : solution de contournement quand le téléphone est réglé sur « toujours demander » (getDefaultOutgoingPhoneAccount renvoie null).
- Seuls ressortent la référence TelecomManager et un fil Tencent déjà couvert.
- La solution connue tient toujours :
  - NetBuis affiche son propre choix de SIM la première fois, via getCallCapablePhoneAccounts (permission READ_PHONE_STATE).
  - L'app mémorise ce choix.
  - Elle le passe ensuite dans EXTRA_PHONE_ACCOUNT_HANDLE.
- Rien de nouveau.

Sources : https://developer.android.com/reference/android/telecom/TelecomManager?authuser=4 , https://developer.cloud.tencent.com/ask/sof/102120027


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage177-netbuis.md -->

# Appel direct sans dialer — 177e passage (2026-10-14 17:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : bibliothèques Kotlin Multiplatform / Compose pour lancer un appel direct.
- Résultats : bibliothèques de contacts et utilitaires uniquement, aucune nouvelle API d'appel. Côté Android, tout passe toujours par ACTION_CALL ou TelecomManager.placeCall.
- Rien de nouveau.

Sources : https://klibs.io/package/io.github.the-best-is-best/compose-utils , https://klibs.io/package/io.github.lilytreasure/multiplatformContacts


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage178-netbuis.md -->

# Appel direct sans dialer — 178e passage (2026-10-14 18:34 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : « Android direct call default SIM without dialer ACTION_CALL ».
- Trouvé : un commit open source (sms-translate #563) qui remplace l'ouverture du clavier par un appel direct via ACTION_CALL, et l'ancien patch OmniROM « Handle preferred SIM for ACTION_CALL ». Les deux confirment l'approche déjà retenue (CALL_PHONE + ACTION_CALL + compte SIM par défaut).
- Rien de nouveau.

Sources : https://git.jeena.net/jeena/sms-translate/commit/f3408f1f9a1f17f30780fcd32b58fbf149dcce7a ; https://gerrit.omnirom.org/plugins/gitiles/android_packages_apps_Dialer/+/01d9f64d245965d30a76bc6889c878f143fc86d7%5E


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage179-netbuis.md -->

# Appel direct sans dialer — 179e passage (2026-10-14 19:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : « iOS 26 LiveCommunicationKit cellular call without confirmation Africa default dialer ».
- Trouvé : la documentation StartCellularConversationAction et des fils des forums Apple sur l'app de numérotation par défaut. Tous les résultats confirment que cette capacité reste limitée à l'UE. Rien pour le Cameroun.
- Rien de nouveau.

Sources : https://developer.apple.com/documentation/livecommunicationkit/startcellularconversationaction ; https://developer.apple.com/forums/thread/798174 ; https://developer.apple.com/forums/thread/823127


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage180-netbuis.md -->

# Appel direct sans dialer — 180e passage (2026-10-14 20:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : « TelecomManager placeCall PhoneAccountHandle dual SIM Android 16 behavior change ».
- Trouvé : uniquement la référence TelecomManager (placeCall, EXTRA_PHONE_ACCOUNT_HANDLE) et l'ancien patch OmniROM déjà noté. Aucun changement de comportement Android 16/17 sur le choix de SIM avec ACTION_CALL ou placeCall.
- Rien de nouveau.

Sources : https://developer.android.com/reference/android/telecom/TelecomManager ; https://gerrit.omnirom.org/plugins/gitiles/android_packages_apps_Dialer/+/01d9f64d245965d30a76bc6889c878f143fc86d7%5E


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage181-netbuis.md -->

# Appel direct sans dialer — 181e passage (2026-10-14 21:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : « Expo expo-linking direct phone call without dialer CALL_PHONE config plugin ».
- Trouvé : la doc Expo (Linking ouvre toujours le composeur via tel:), des fils du forum Expo et react-native-immediate-phone-call (une enveloppe autour d'ACTION_CALL). Côté Expo, il faut toujours un module natif ou un config plugin avec CALL_PHONE, comme déjà noté.
- Rien de nouveau.

Sources : https://docs.expo.dev/linking/into-other-apps/ ; https://github.com/wumke/react-native-immediate-phone-call ; https://forums.expo.dev/t/making-a-phone-call-without-any-third-party-library-in-expo/69507


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage182-netbuis.md -->

# Appel direct sans dialer — 182e passage (2026-10-14 22:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : « Android hide phone number in-call screen third-party app outgoing call privacy ».
- Trouvé : uniquement des pages génériques de faible qualité sur le masquage de l'identifiant d'appelant (cacher son propre numéro au destinataire). Ce sujet est différent du nôtre : aucune ne traite du masquage du numéro composé sur l'écran d'appel système. Le masquage de bout en bout exige toujours ROLE_DIALER + InCallService, ou un pont serveur.
- Rien de nouveau.

Sources : https://mem.uandes.cl/?p=1538 (non pertinent, cité pour traçabilité)


---

<!-- source : recherche-appel-direct-verification-2026-10-14-passage183-netbuis.md -->

# Appel direct sans dialer — 183e passage (2026-10-14 23:34 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : « Google Play policy CALL_PHONE permission declaration 2026 update ».
- Trouvé : les pages d'aide Play Console et l'article sur la mise à jour de politique de juillet 2026, déjà relevés dans des passages antérieurs (dont le 154). Le resserrement vise les permissions SMS et journal d'appels. CALL_PHONE reste une permission d'exécution ordinaire, sans formulaire de déclaration.
- Rien de nouveau.

Sources : https://dev.to/mr_manushukla/google-plays-july-2026-policy-update-5-changes-to-ship-before-the-31-august-deadline-3bie ; https://support.google.com/googleplay/android-developer/answer/16909972


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage184-netbuis.md -->

# Appel direct sans dialer — 184e passage (2026-10-15 00:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : « Android SubscriptionManager getDefaultVoiceSubscriptionId ACTION_CALL dual SIM direct call example ».
- Trouvé : la référence SubscriptionManager. getDefaultVoiceSubscriptionId renvoie INVALID_SUBSCRIPTION_ID quand le téléphone est réglé sur « demander à chaque fois ». C'est le même cas que getDefaultOutgoingPhoneAccount("tel") == null, déjà couvert par le sélecteur de SIM maison. L'article mojoauth porte sur la vérification de numéro et ne s'applique pas ici.
- Rien de nouveau.

Sources : https://developer.android.com/reference/android/telephony/SubscriptionManager ; https://mojoauth.com/blog/dual-sim-esim-number-verification-which-number-gets-verified


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage185-netbuis.md -->

# Appel direct sans dialer — 185e passage (2026-10-15 01:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : « Samsung One UI 8 third-party app ACTION_CALL dual SIM prompt behavior ».
- Trouvé : des fils de la communauté Samsung, surtout anciens (One UI 3), sur la disparition des boutons SIM1/SIM2 dans l'app Téléphone, ainsi qu'un article Android Authority sur les options de données multi-SIM. Aucun ne signale de changement pour les appels ACTION_CALL des apps tierces sous One UI 8. Sur Samsung, si le réglage est « Toujours demander », le sélecteur système s'affiche. Le sélecteur de SIM maison + EXTRA_PHONE_ACCOUNT_HANDLE reste la parade.
- Rien de nouveau.

Sources : https://eu.community.samsung.com/t5/galaxy-note-series/one-ui-3-0-problem-choosing-sim-when-making-call/m-p/2850047 ; https://www.androidauthority.com/samsung-multi-sim-data-options-3642898


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage186-netbuis.md -->

# Appel direct sans dialer — 186e passage (2026-10-15 02:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : « Xiaomi HyperOS third-party app direct call permission autostart ACTION_CALL blocked ».
- Trouvé :
  - La page de réglages Xiaomi de Binotel WIRE (Autostart, pop-up en arrière-plan, « Run in background », batterie sans restriction). Ces réglages servent aux apps qui lancent des appels depuis l'arrière-plan (CRM, ordinateur) ou qui enregistrent les appels.
  - Des articles généralistes sur les permissions Xiaomi.
  - Une rumeur de 2025 sur l'app Téléphone propriétaire de HyperOS 3.
- Pour NetBuis, le clic « Appeler » a lieu au premier plan, donc ces restrictions ne s'appliquent pas, conformément à la règle déjà posée de ne jamais appeler depuis un service.
- Rien de nouveau.

Sources : https://wire.binotel.com/settings/xiaomi ; https://www.tuttoandroid.net/news/2025/07/25/xiaomi-redmi-poco-hyperos-3-rumor-app-telefono-proprietaria-1108073/


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage187-netbuis.md -->

# Appel direct sans dialer — 187e passage (2026-10-15 03:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : « Tecno Infinix HiOS XOS third-party app direct call CALL_PHONE dual SIM issue ». Ces marques sont très répandues au Cameroun.
- Trouvé :
  - Un comparatif des surcouches Tecno et Infinix (mobile-review).
  - Des tests GSMArena.
  - Des articles Hovatek sur les problèmes de réseau (« numéro occupé ou injoignable »).
  - Aucun ne signale de blocage particulier d'ACTION_CALL ou de CALL_PHONE sur HiOS/XOS.
- Recommandation inchangée : tester sur un Tecno et un Infinix réels, réglés en « demander à chaque fois », pendant la recette.
- Rien de nouveau.

Sources : https://mobile-review.com/all/reviews/other/obzor-obolochek-tecno-i-infinix ; https://www.hovatek.com/blog/fixing-number-busy-or-unreachable-on-android/


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage188-netbuis.md -->

# Appel direct sans dialer — 188e passage (2026-10-15 04:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : « Android 17 telecom changes third-party outgoing calls ACTION_CALL October 2026 ».
- Trouvé : la page AOSP « Support third-party calling apps », qui concerne les apps VoIP (ConnectionService), ainsi que la référence TelecomManager. Aucun changement Android 17 ne touche ACTION_CALL pour les appels GSM lancés par une app tierce, en dehors de la restriction USSD déjà notée pour Android 17 QPR2.
- Rien de nouveau.

Sources : https://source.android.com/docs/core/connect/third-party-call-apps ; https://developer.android.com/reference/android/telecom/TelecomManager


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage189-netbuis.md -->

# Appel direct sans dialer — 189e passage (2026-10-15 05:34 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : « click to call Cameroon API MTN Orange callback masked number 2026 ».
- Trouvé :
  - Des guides sur le format des numéros camerounais (sent.dm).
  - Des codes USSD Orange (techjunction).
  - L'API « Messaging Pro Cameroon » d'Orange (SMS uniquement, sur RapidAPI).
- Toujours aucune API publique MTN ou Orange Cameroun de click-to-call ou de numéro masqué. Le masquage côté opérateur reste indisponible.
- Rien de nouveau.

Sources : https://orange-evaluation.hub.rapidapi.com/orange-orange-default/api/messaging-pro-cameroon ; https://www.sent.dm/en/resources/phone-number-standards/cm


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage190-netbuis.md -->

# Appel direct sans dialer — 190e passage (2026-10-15 06:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : « Capacitor plugin direct call CALL_PHONE 2026 npm call-number ».
- Trouvé :
  - Capawesome Phone Dialer (déjà relevé au passage 174). Vérifié : il utilise ACTION_DIAL sur Android et tel: sur iOS. Il « ne passe jamais l'appel lui-même », donc ne convient pas.
  - capacitor-plugin-phone-call (jsDelivr) et un fil du forum Ionic, qui reprennent la même enveloppe autour d'ACTION_CALL.
  - Plugins Twilio et CallKit (Capgo), qui relèvent de l'option VoIP abandonnée.
- Rien de nouveau.

Sources : https://capawesome.io/docs/sdks/capacitor/phone-dialer/ ; https://www.jsdelivr.com/package/npm/capacitor-plugin-phone-call


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage191-netbuis.md -->

# Appel direct sans dialer — 191e passage (2026-10-15 07:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : « Android TelecomManager placeCall vs ACTION_CALL difference default SIM 2026 ».
- Trouvé :
  - La référence TelecomManager.
  - L'ancien patch OmniROM déjà noté.
  - Un commit /e/OS (android_frameworks_base) côté framework.
- Rappel : placeCall et ACTION_CALL exigent tous les deux CALL_PHONE et acceptent EXTRA_PHONE_ACCOUNT_HANDLE. Aucune différence nouvelle concernant le choix de SIM.
- Rien de nouveau.

Sources : https://developer.android.com/reference/android/telecom/TelecomManager ; https://gitlab.e.foundation/e/os/android_frameworks_base/-/commit/043c9dee2d5e9f0c63bcf2a012b5f93bc32cd307


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage192-netbuis.md -->

# Appel direct sans dialer — 192e passage (2026-10-15 08:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : plugins Flutter d'appel direct avec choix de SIM (2026).
- Trouvé : direct_caller_sim_choice, flutter_direct_caller_plugin, direct_call, direct_call_plus, flutter_tele. Tous enveloppent Intent.ACTION_CALL (+ CALL_PHONE), certains avec un index de SIM ; rien d'autre que l'approche déjà retenue.
- Rien de nouveau.

Sources : https://pub.dev/packages/direct_call ; https://pub-web-s2.flutter-io.cn/packages/direct_caller_sim_choice/versions/1.0.3 ; https://pub.dev/documentation/direct_call_plus/latest/ ; https://pub.dev/packages/flutter_tele


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage193-netbuis.md -->

# Appel direct sans dialer — 193e passage (2026-10-15 09:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : Android Enterprise / MDM / mode kiosque et appels directs.
- Trouvé : en mode kiosque, les MDM (Relution, Hexnode, SOTI, Ivanti) doivent autoriser l'app Téléphone pour que l'écran d'appel s'affiche ; ils peuvent aussi bloquer les appels sortants. Ça ne concerne que les parcs gérés, pas les téléphones personnels des utilisateurs de NetBuis.
- Rien de nouveau.

Sources : https://hub.relution.io/en/docs/android-enterprise/knowledge-base/call-ui/ ; https://pulse.soti.net/community/thread/82c5ffbe-f81c-4b14-8042-e19855f445e7 ; https://www.hexnode.com/mobile-device-management/help/android-kiosk-mode/


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage194-netbuis.md -->

# Appel direct sans dialer — 194e passage (2026-10-15 10:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : bibliothèques Kotlin Multiplatform / Compose Multiplatform pour lancer un appel (2026).
- Trouvé : uniquement des bibliothèques de contacts et d'utilitaires (kontacts-compose, compose-utils). Aucune ne propose d'appel direct ; il faudrait de toute façon du code Android natif (ACTION_CALL + CALL_PHONE), et iOS garde la confirmation.
- Rien de nouveau.

Sources : https://klibs.io/package/io.github.dev-bilal-azzam/kontacts-compose ; https://klibs.io/package/io.github.the-best-is-best/compose-utils


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage195-netbuis.md -->

# Appel direct sans dialer — 195e passage (2026-10-15 11:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : notes de version Android 17 QPR3 Beta 1 (2 octobre 2026) pour la téléphonie.
- Trouvé : « pas de changement d'API impactant les apps ». Seulement des correctifs (plantage d'apps d'appel juste après redémarrage, crash com.android.phone sur index de slot SIM inattendu, eSIM qui se désactive). Rien sur ACTION_CALL, CALL_PHONE, placeCall ni le choix de SIM.
- Rien de nouveau.

Sources : https://developer.android.com/about/versions/17/qpr3/release-notes


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage196-netbuis.md -->

# Appel direct sans dialer — 196e passage (2026-10-15 12:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : iOS 26/27, est-il possible de supprimer la confirmation tel:// ou de passer un appel cellulaire sortant via CallKit ?
- Trouvé : la confirmation tel:// reste obligatoire depuis iOS 10.3. CallKit ne passe pas d'appel GSM. Le blocage par iOS 27 des liens tel: contenant des codes de renvoi d'appel était déjà noté aux passages 123 et 152.
- Rien de nouveau.

Sources : https://developer.apple.com/forums/thread/73406 ; https://developer.apple.com/forums/thread/847164


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage197-netbuis.md -->

# Appel direct sans dialer — 197e passage (2026-10-15 13:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : utiliser un AccessibilityService pour cliquer automatiquement sur « Appeler » dans le dialer (Play, 2026).
- Trouvé : Google Play restreint AccessibilityService aux vrais usages d'accessibilité (déjà interdit pour l'enregistrement d'appels). Un auto-clic dans le dialer serait refusé, et c'est inutile puisque ACTION_CALL appelle déjà directement.
- Rien de nouveau.

Sources : https://www.xda-developers.com/google-trying-limit-apps-accessibility-service/ ; https://9to5google.com/2022/04/21/google-will-block-all-third-party-call-recording-apps-on-play-store-from-may-11/


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage198-netbuis.md -->

# Appel direct sans dialer — 198e passage (2026-10-15 14:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : version web/PWA de NetBuis, appel direct sans dialer (Android Chrome 2026).
- Trouvé : une PWA ne peut qu'ouvrir un lien tel:, qui affiche le numéro dans le dialer et demande un second appui. Il n'existe pas d'API web pour passer un appel GSM directement. Seule l'app native (ACTION_CALL) répond au besoin.
- Rien de nouveau.

Sources : https://progressier.com/pwa-capabilities/phone-call-pwa-demo ; https://forum.ionicframework.com/t/pwa-tel-link-is-not-working-only-when-added-to-homescreen-on-android/109732


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage199-netbuis.md -->

# Appel direct sans dialer — 199e passage (2026-10-15 15:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : bonnes pratiques UX pour demander la permission CALL_PHONE (2026).
- Trouvé : demander la permission au premier appui sur « Appeler » (en contexte), avec une courte explication, et basculer sur ACTION_DIAL en cas de refus. C'est déjà le schéma recommandé.
- Rien de nouveau.

Sources : https://babich.biz/blog/mobile-ux-design-the-right-ways-to-ask-users-for-permissions ; https://archive.reactnative.dev/docs/next/permissionsandroid ; https://itnext.io/android-dial-phone-programmatically-5ea3714d801d


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage200-netbuis.md -->

# Appel direct sans dialer — 200e passage (2026-10-15 16:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : masquer le numéro composé sur l'écran d'appel Android depuis une app tierce (2026).
- Trouvé : les résultats parlent uniquement de masquer SON identifiant auprès du destinataire (#31#, réglages opérateur), pas de cacher le numéro sur l'écran de l'appelant. Pour ça, il faut toujours ROLE_DIALER + InCallService ou un pont serveur, comme déjà noté.
- Rien de nouveau.

Sources : https://www.devx.com/how-tos/how-to-hide-my-number-when-calling-on-android/


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage201-netbuis.md -->

# Appel direct sans dialer — 201e passage (2026-10-15 17:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : Android Auto / Wear OS, passer un appel cellulaire depuis une app compagnon (2026).
- Trouvé : les appels passent par le framework Telecom (InCallService, call streaming vers Android Auto). Rien qui permette d'appeler sans ACTION_CALL/placeCall ni de cacher le numéro. Hors sujet pour NetBuis (téléphone seul).
- Rien de nouveau.

Sources : https://developer.android.com/reference/android/telecom/InCallService.html ; https://general-era-5b7.notion.site/Telecom-w-android-auto-13d683d7d0ff8040972df482b5eddfaf


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage202-netbuis.md -->

# Appel direct sans dialer — 202e passage (2026-10-15 18:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : Africa's Talking Voice API, click-to-call au Cameroun (2026).
- Trouvé : c'est une API VoIP/centre d'appels (déjà comparée dans comparatif-solutions-telecom-appels.md). Ce serait l'option « pont serveur » pour masquer le numéro, une piste payante déjà écartée. Aucune nouveauté 2026 pour le Cameroun.
- Rien de nouveau.

Sources : https://blog.africastalking.com/building-a-virtual-call-center-with-africas-talking-voice-api-a-guide-for-smes-and-startups-3f2cc4e2184b ; https://learn.microsoft.com/en-us/connectors/africastalkingvoice


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage203-netbuis.md -->

# Appel direct sans dialer — 203e passage (2026-10-15 19:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : Jetpack core-telecom 1.1.0 (blog Android de mai 2026, « VoIP native visibility »).
- Trouvé : uniquement pour la VoIP : historique d'appels unifié dans le dialer système, rappel via ACTION_CALL_BACK, isLogExcluded. Exige Android 16.1 et un déploiement par liste blanche (Google Meet en premier). Rien pour les appels SIM, le choix de SIM ou masquer le numéro composé.
- Rien de nouveau.

Sources : https://android-developers.googleblog.com/2026/05/voip-native-visibility-telecom-alpha.html


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage204-netbuis.md -->

# Appel direct sans dialer — 204e passage (2026-10-15 20:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : lister les SIM (getCallCapablePhoneAccounts) sans READ_PHONE_STATE, Android 16.
- Trouvé : READ_PHONE_STATE reste nécessaire pour lister les comptes d'appel ; le plugin capacitor-sim (cap-go) l'exige aussi. Ça confirme le schéma retenu : ne demander READ_PHONE_STATE que si le téléphone est réglé sur « toujours demander ».
- Rien de nouveau.

Sources : https://awesome.ecosyste.ms/projects/github.com%2Fcap-go%2Fcapacitor-sim ; https://www.b4x.com/android/forum/threads/help-regarding-android-permission-read_phone_state.76177/


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage205-netbuis.md -->

# Appel direct sans dialer — 205e passage (2026-10-15 21:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : restrictions d'ACTION_CALL sur les numéros d'urgence (Android 17, 2026).
- Trouvé : la règle reste la même qu'avant (isPotentialLocalEmergencyNumber). Un ACTION_CALL d'app tierce vers un numéro d'urgence est redirigé vers le dialer. Ça ne concerne pas les numéros de prestataires NetBuis. Pas de nouvelle restriction en 2026.
- Rien de nouveau.

Sources : https://android.googlesource.com/platform/packages/apps/Phone/+/a42348f%5E%21 ; https://android.googlesource.com/platform/frameworks/base/+/1a81169%5E!


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage206-netbuis.md -->

# Appel direct sans dialer — 206e passage (2026-10-15 22:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : HarmonyOS NEXT (Huawei) et ACTION_CALL / appel direct.
- Trouvé : HarmonyOS NEXT n'exécute plus les apps Android, donc ACTION_CALL ne s'y applique pas ; il faudrait une app ArkTS native séparée, marginale au Cameroun. uniapp makePhoneCall ouvre simplement le dialer.
- Rien de nouveau.

Sources : https://uniapp.dcloud.net.cn/api/system/phone ; https://www.huaweicentral.com/huawei-takes-on-android-in-china-with-wechat-harmonyos-next-app/amp/


---

<!-- source : recherche-appel-direct-verification-2026-10-15-passage207-netbuis.md -->

# Appel direct sans dialer — 207e passage (2026-10-15 23:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : Xiaomi HyperOS / MIUI, permission « afficher les fenêtres pop-up en arrière-plan » et ACTION_CALL.
- Trouvé : cette permission Xiaomi ne concerne que les lancements depuis l'arrière-plan (antivirus, apps d'appel VoIP). NetBuis lance l'appel au premier plan sur tap utilisateur, donc non concerné ; règle « jamais depuis l'arrière-plan » déjà actée.
- Rien de nouveau.

Sources : https://support.kaspersky.com/help/Kaspersky/Android_knownissues/en-US/195536.htm ; https://trtc.io/document/51022


---

<!-- source : recherche-appel-direct-verification-2026-10-16-passage208-netbuis.md -->

# Appel direct sans dialer — 208e passage (2026-10-16 00:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : Samsung One UI, double SIM en « toujours demander » et ACTION_CALL avec PhoneAccountHandle.
- Trouvé : forum B4X confirme l'usage de l'extra android.telecom.extra.PHONE_ACCOUNT_HANDLE pour forcer la SIM ; patch OmniROM « Handle preferred SIM for ACTION_CALL » montre que le dialer système respecte l'extra. Forums Samsung = réglages utilisateur uniquement. Déjà couvert (sélecteur SIM NetBuis + mémorisation).
- Rien de nouveau.

Sources : https://www.b4x.com/android/forum/threads/dual-sim-call.101443/ ; https://gerrit.omnirom.org/plugins/gitiles/android_packages_apps_Dialer/+/01d9f64d245965d30a76bc6889c878f143fc86d7%5E


---

<!-- source : recherche-appel-direct-verification-2026-10-16-passage209-netbuis.md -->

# Appel direct sans dialer — 209e passage (2026-10-16 01:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : React Native / Expo, bibliothèques d'appel direct (2026).
- Trouvé : react-native-immediate-phone-call (wrapper ACTION_CALL, déjà couvert dès le passage 9) ; expo-callkit-telecom et Twilio Voice RN (VoIP, hors sujet GSM). Rien qui masque le numéro sur l'écran d'appel système.
- Rien de nouveau.

Sources : https://github.com/wumke/react-native-immediate-phone-call ; https://www.twilio.com/en-us/changelog/twilio-voice-react-native-sdk-adds-expo-support


---

<!-- source : recherche-appel-direct-verification-2026-10-16-passage210-netbuis.md -->

# Appel direct sans dialer — 210e passage (2026-10-16 02:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : politique Google Play 2026, formulaire de déclaration pour CALL_PHONE.
- Trouvé : la déclaration obligatoire « SMS et journal d'appels » vise READ_CALL_LOG, PROCESS_OUTGOING_CALLS et les SMS, pas CALL_PHONE. CALL_PHONE reste une permission dangereuse ordinaire (demande runtime), déjà couverte. Aucun changement de politique trouvé.
- Rien de nouveau.

Sources : https://support.google.com/googleplay/android-developer/answer/9047303 ; https://support.google.com/googleplay/android-developer/answer/16558241?hl=en


---

<!-- source : recherche-appel-direct-verification-2026-10-16-passage211-netbuis.md -->

# Appel direct sans dialer — 211e passage (2026-10-16 03:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : Capacitor / Ionic, plugins d'appel direct (CALL_PHONE) en 2026.
- Trouvé : Ionic « Call Number » (cordova-plugin-call-number, option bypassAppChooser) et le paquet npm phone-call : simples wrappers ACTION_CALL, même limite (écran d'appel système affiche le numéro). direct_call_plus (Flutter) idem, déjà couvert passage 192.
- Rien de nouveau.

Sources : https://ionicframework.com/docs/native/call-number ; https://forum.ionicframework.com/t/call-phone-number-from-capacitor/207186


---

<!-- source : recherche-appel-direct-verification-2026-10-16-passage212-netbuis.md -->

# Appel direct sans dialer — 212e passage (2026-10-16 04:33 UTC)

Conclusion inchangée (voir passage 163).

- Recherche : TelecomManager.placeCall sans CALL_PHONE / rôle dialer par défaut, changements 2026.
- Trouvé : la doc officielle reste identique (placeCall exige CALL_PHONE, ou le rôle dialer par défaut). Commits /e/OS et OmniROM ne portent que sur les codes MMI de renvoi d'appel. Aucun changement d'API.
- Rien de nouveau.

Sources : https://developer.android.com/reference/android/telecom/TelecomManager ; https://gerrit.omnirom.org/plugins/gitiles/android_frameworks_base/+/8ad07c82e3dd716261b61c0e96188e87d381f1a6%5E%21


---

<!-- source : recherche-appel-direct-verification-2026-10-17-passage213-netbuis.md -->

# Appel direct sans dialer — 213e passage (2026-10-17 12:02 UTC)

Conclusion inchangée (voir passage 163).

- Rattrapage : 31 déclenchements horaires (2026-10-16 05:33 → 2026-10-17 11:33 UTC) restés en file pendant les redémarrages, traités en une seule passe.
- Recherche : changements Android 17 / 2026 sur ACTION_CALL, CALL_PHONE, appels sortants.
- Trouvé : seulement la référence TelecomManager (placeCall, getDefaultOutgoingPhoneAccount), sans restriction nouvelle.
- Rien de nouveau.

Sources : https://developer.android.com/reference/android/telecom/TelecomManager.html

