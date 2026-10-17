> ⚠️ **Document historique, dépassé** — cette comparaison de fournisseurs (Twilio/Telnyx/Plivo/Agora/etc.) a été **abandonnée** le 2026-09-30. Voir `decision-finale-appels.md` pour l'approche retenue (appel natif direct via le dialer du téléphone, sans fournisseur tiers). Ce document reste comme trace de recherche, à réutiliser seulement si une v2 avec suivi d'appel/VoIP est envisagée plus tard.

# Comparatif des solutions télécom pour les appels NetBuis (VoIP intra-app + pont PSTN)

Date : 2026-09-30 (v4 — ajout des techniques de fluidité d'appel inspirées de WhatsApp)

## Décision actée par le porteur de projet (abandonnée depuis, voir bandeau ci-dessus)

**Twilio est retenu comme fournisseur de départ pour les deux tiers** :
- Tier A (VoIP intra-app, deux comptes NetBuis actifs) → Twilio Voice SDK
- Tier B (pont PSTN vers un compte NetBuis sans app) → Twilio Programmable Voice

Raison principale : unification (un seul compte, une seule intégration côté Django) pour une phase de démarrage. Réévaluation possible plus tard si la qualité audio en conditions réseau réelles au Cameroun pose problème (voir alternatives Agora/ZEGOCLOUD en section C).

## Comment WhatsApp obtient des appels fluides — et comment s'en rapprocher avec Twilio

D'après l'analyse technique de l'implémentation WhatsApp (WebRTChacks) et la documentation Twilio :

**Techniques utilisées par WhatsApp :**
- **Connexion hybride relais + P2P** : WhatsApp établit d'abord une connexion via un serveur relais (TURN) pour garantir un appel immédiatement fonctionnel, puis tente en parallèle une connexion directe (P2P) entre les deux téléphones ; si elle réussit, le flux audio bascule dessus **sans interruption audible**. Ça donne la fiabilité d'un relais avec la latence d'une connexion directe quand c'est possible.
- **Codec Opus/SILK à faible bitrate (~20 kbps)** avec occultation de perte de paquets (le son reste compréhensible même si des paquets se perdent) et annulation d'écho/de bruit intégrées — pensé spécifiquement pour les réseaux mobiles imparfaits.
- **UDP plutôt que TCP** pour le flux audio, pour éviter les blocages liés aux retransmissions en cas de perte de paquet (mieux vaut un petit artefact audio qu'un blocage).
- **Infrastructure de relais mondiale Meta** — un réseau de datacenters/points de présence très dense, qui réduit la distance physique (donc la latence) entre les deux appelants. C'est un investissement d'infrastructure à l'échelle de Meta, difficile à égaler pour un plus petit acteur.

**Ce que Twilio Voice SDK offre déjà (bâti sur les mêmes bases WebRTC/standards) :**
- Codec Opus, gestion ICE/STUN/TURN pour la traversée NAT, annulation d'écho/bruit — équivalent fonctionnel.
- Son propre réseau mondial de points de présence ("Edge Locations"), avec une option **"Roaming"** qui choisit automatiquement le datacenter le plus rapide pour l'utilisateur plutôt qu'un edge fixe — **recommandé pour NetBuis plutôt que de figer un edge manuellement**.
- Limite connue : **pas de point de présence Twilio en Afrique** — les plus proches du Cameroun sont Frankfurt ou Dublin (Europe). L'écart de latence Cameroun→Europe reste généralement acceptable pour la voix (sous le seuil de gêne perceptible, ~150-200 ms), mais structurellement moins optimal que l'infrastructure mondiale de Meta.

**Recommandations concrètes pour se rapprocher de la fluidité WhatsApp avec Twilio :**
1. Utiliser l'option **Roaming/low-latency routing** de Twilio (pas un edge fixe).
2. Utiliser les **notifications push VoIP natives** (CallKit/PushKit sur iOS, équivalent Android) pour réveiller l'app du destinataire immédiatement à l'arrivée d'un appel — Twilio le supporte nativement, c'est essentiel pour ne pas perdre de temps avant que la connexion démarre.
3. **Monitorer la qualité réseau côté client** (Twilio Voice SDK expose des statistiques de qualité d'appel en temps réel) pour, par exemple, proposer automatiquement une bascule vers le pont PSTN si la VoIP est vraiment dégradée pendant l'appel.
4. **Tester en conditions réelles de réseau camerounais** (2G/3G/4G, coupures) avant de valider définitivement ce choix — déjà noté comme étape de validation terrain.

## Prochaines étapes concrètes pour démarrer avec Twilio (abandonnées)

1. **Créer un compte Twilio** (essai gratuit avec crédit offert, puis passage en compte payant).
2. **Poser explicitement 2 questions au support/sales Twilio avant tout engagement à volume** :
   - Confirmation de la prise en charge des appels **entrants** vers/depuis le Cameroun (le sortant est confirmé, l'entrant ne l'était pas dans la doc publique).
   - Comment Twilio termine ses appels vers les réseaux mobiles camerounais (MTN CM / Orange CM) — s'assurer que c'est une route d'interconnexion internationale légitime, vu la vigilance de l'ART et des opérateurs locaux contre le trafic frauduleux (voir section E).
3. **Acheter/louer un numéro Twilio** (numéro local camerounais si possible, sinon un numéro virtuel international) pour servir d'identifiant de la plateforme dans les ponts d'appel.
4. **Intégration côté Django** :
   - Installer le SDK Python officiel Twilio (`twilio` sur PyPI).
   - Créer une TwiML Application pour gérer les deux flux (VoIP intra-app via Twilio Client/Voice SDK, et pont PSTN via l'API Calls avec un `<Dial>` composant les deux numéros).
   - Exposer des endpoints webhook Django pour recevoir les statuts d'appel (initié, en cours, terminé, durée, échec) et les stocker en base pour le tracking et la notation des commerçants.
   - Générer des tokens d'accès Twilio côté serveur pour authentifier le SDK Voice dans l'app mobile (ne jamais exposer les clés Twilio côté client).
5. **Intégrer le SDK Voice côté mobile**, avec push VoIP natif (voir recommandation ci-dessus) — natif iOS/Android ou React Native selon la stack retenue (à confirmer).
6. **Décider du modèle de coût** : qui absorbe le tarif à la minute des appels pontés (client, commerçant, ou marge plateforme) avant d'ouvrir la fonctionnalité à grande échelle.
7. **Tester en conditions réelles** avec quelques commerçants pilotes avant généralisation, pour valider qualité audio, taux de décroché, et coût réel observé.

## A. CPaaS globaux — couverture Cameroun vérifiée (pour le pont PSTN, cas B)

| Fournisseur | Couverture Cameroun | Détails vérifiés |
|---|---|---|
| **Twilio** (retenu) | Sortant confirmé (numéros CM en vente) | Sortant mobile ~0,79 $/min ; entrant non confirmé dans la doc publique, à valider avec leur support (voir étapes ci-dessus) |
| Telnyx | Entrant + sortant confirmés | Numéro local CM disponible (~27,50 $/mois) ; réseau "carrier-grade" — option de repli si Twilio déçoit ; tarif à la minute non publié pour le Cameroun, à demander directement |
| Plivo | Sortant confirmé, entrant non supporté | Sortant mobile ~0,5148 $/min |
| Vonage/Nexmo, Sinch, Infobip, Bandwidth | Non confirmé spécifiquement pour le Cameroun | Non retenus pour le démarrage |

## B. Agrégateurs "Afrique" — à ne PAS supposer qu'ils couvrent le Cameroun

| Fournisseur | Couverture Cameroun (Voice) | Constat |
|---|---|---|
| Africa's Talking | Non — Kenya, Ouganda, Nigeria uniquement | Écarté |
| Orange Voice API | Non — France et Sénégal uniquement | Écarté (le service local Orange Cameroun nécessiterait un accord B2B séparé) |
| Nexah (Cameroun) | Pas d'offre voix | Utile pour SMS/USSD/mobile money, pas pour les appels |
| LAfricaMobile | Non confirmé publiquement | Non retenu au démarrage, à recontacter si Twilio déçoit |
| MTN Cameroun | Pas d'API publique | Non retenu au démarrage |

## C. SDK VoIP intra-application (cas A)

**Retenu au démarrage : Twilio Voice SDK** (natif iOS/Android + SDK React Native en disponibilité générale), pour l'unification avec le tier B. Coût app-à-app très bas (~0,004 $/min). Voir la section dédiée ci-dessus sur la configuration recommandée (Roaming, push VoIP natif, monitoring qualité).

Alternative de repli si la qualité audio déçoit en conditions réseau camerounaises réelles : **Agora** ou **ZEGOCLOUD** (spécialisés temps réel en marchés à connectivité difficile).

Option future à plus grande échelle : **LiveKit** (open-source, auto-hébergeable).

### Intégration native (CallKit / Telecom-ConnectionService) — pour référence future
Si une v2 VoIP est reprise un jour : intégrer CallKit + PushKit (iOS) et Telecom/ConnectionService (Android) directement dans l'app existante plutôt que de développer une app séparée — c'est le mécanisme standard utilisé par WhatsApp/Messenger/Viber, et Twilio Voice SDK s'y branche nativement. Depuis iOS 18.2 (fin 2024), Apple autorise même une app tierce comme gestionnaire d'appels par défaut sur tout l'iPhone (monde entier). Côté Android, une nouvelle API Telecom (2026, Jetpack Telecom v1.1.0) permet de faire apparaître l'historique VoIP dans le dialer natif, mais cette fonctionnalité précise est en rollout progressif avec liste blanche (démarre avec Google Meet) — la fonction de base (écran d'appel entrant plein écran) est elle disponible sans restriction depuis des années.

## D. Solutions alternatives qui évitent complètement le pont PSTN payant

- **Appel natif direct (retenu, voir `decision-finale-appels.md`)** : au clic sur "Appeler", ouvrir le dialer natif du téléphone avec le numéro du commerçant — appel classique facturé sur le crédit de l'utilisateur par son opérateur. Coût nul pour la plateforme, aucune dépendance tierce, mais perte du tracking d'appel et du masquage de numéro.
- Notification + rappel manuel (SMS/push au commerçant avec le numéro du client, il rappelle lui-même) — coût nul mais perte du one-tap et du tracking.
- "Please call me" / flash-call — fonctionnalité opérateur historique en Afrique du Sud, non disponible au Cameroun, écartée.

## E. Point de vigilance réglementaire important — spécifique au Cameroun (ne s'applique plus à la décision finale)

L'ART (régulateur télécom camerounais) et les 4 opérateurs (Orange, MTN, Camtel, Nexttel) mènent une lutte active contre le trafic international frauduleux des communications ("SIM boxing", contournement des tarifs d'interconnexion). Ce point ne concerne plus l'approche retenue (appel natif direct = appel domestique classique, pas de terminaison internationale tierce).

## Sources consultées
- [Africa's Talking — pays couverts](https://help.africastalking.com/en/articles/2727792-which-countries-are-africa-s-talking-products-in)
- [Twilio Voice Pricing — Cameroun](https://www.twilio.com/en-us/voice/pricing/cm)
- [Twilio Programmable Voice API](https://www.twilio.com/docs/voice/api)
- [Twilio Voice React Native SDK — GA](https://www.twilio.com/en-us/changelog/twilio-voice-react-native-sdk-and-reference-app-are-now-ga)
- [Twilio — Edge Locations (infrastructure globale)](https://www.twilio.com/docs/global-infrastructure/edge-locations)
- [WebRTChacks — analyse technique de l'implémentation d'appel WhatsApp](https://webrtchacks.com/whats-up-with-whatsapp-and-webrtc/)
- [Plivo Voice Pricing — Cameroun](https://www.plivo.com/voice/pricing/cm/)
- [Telnyx — numéros Cameroun](https://telnyx.com/phone-numbers/cameroon)
- [Orange Developer — Voice API](https://developer.orange.com/apis/voice-api)
- [Nexah (agrégateur Cameroun)](https://nexah.net)
- [LAfricaMobile — Voice API](https://developers.lafricamobile.com/docs/voice/introduction)
- [Digital Business Africa — tarifs d'interconnexion ART Cameroun](https://www.digitalbusiness.africa/cameroun-lart-fixe-les-tarifs-plafonds-dinterconnexion-et-dacces-pour-la-terminaison-dappels-et-des-sms-des-quatre-operateurs/)
- [Camer.be — lutte contre le trafic international frauduleux au Cameroun](https://www.camer.be/60946/11:1/cameroun-orange-mtn-camtel-et-nexttel-en-guerre-contre-le-trafic-international-frauduleux-des-communications-electroniques-cameroon.html)
- [Android Developers Blog — Telecom API native visibility (2026)](https://android-developers.googleblog.com/2026/05/voip-native-visibility-telecom-alpha.html)
- [TransNexus — Apple default calling app policy](https://transnexus.com/blog/2024/iphone-to-allow-changing-default-calling-app/)
