> ⚠️ **Document historique, dépassé** — cette analyse (VoIP intra-app + pont PSTN via Twilio) a été **abandonnée** le 2026-09-30. Voir `decision-finale-appels.md` pour l'approche retenue (appel natif direct via le dialer du téléphone, sans fournisseur tiers). Ce document reste comme trace de recherche, à réutiliser seulement si une v2 avec suivi d'appel/VoIP est envisagée plus tard.

# Analyse critique — Flux d'appel client → commerçant (NetBuis)

Dernière mise à jour : 2026-09-26 (v2, après clarification du porteur de projet)

## Flux clarifié

WhatsApp n'est **pas** un canal utilisé dans le flux — c'était une analogie pour illustrer la Voix IP intra-application. Le flux réel a deux cas de figure :

1. **Les deux comptes sont "actifs app"** (client et commerçant ont NetBuis installé et sont joignables) → communication en Voix IP directement dans l'app, sur le même principe qu'un appel WhatsApp (protocole propre à NetBuis, pas WhatsApp lui-même).
2. **Le commerçant a un compte NetBuis mais n'a pas l'app / n'est pas joignable en VoIP** (pas de smartphone, ou app non installée) → l'appel doit être redirigé vers son vrai numéro de téléphone (ligne Orange/MTN), via un **agrégateur télécom tiers** (pas directement les API Orange/MTN), qui compose son numéro et le met en relation avec le client.

Le vrai critère de branchement n'est donc pas "Android vs smartphone" mais : **le compte est-il actuellement joignable en VoIP dans l'app (présence + jeton push valide) ou non ?** Si non → bascule vers un appel téléphonique réel (PSTN) vers le numéro enregistré sur le compte.

## Point à clarifier dans le cahier des charges
Comment un "compte NetBuis" est-il créé pour un commerçant qui n'a ni smartphone ni l'app installée ? Probablement via un onboarding par un agent/admin qui liste le commerçant avec son numéro (profil "vitrine"), sans que celui-ci n'ait jamais ouvert l'app. À confirmer — ça détermine comment authentifier/vérifier ces comptes et éviter les numéros frauduleux.

## Points de vigilance techniques

### 1. Couverture de l'agrégateur télécom pour le Cameroun
Africa's Talking (l'agrégateur "pan-africain" le plus connu sous ce type de nom) **ne couvre pas le Cameroun** en Voice API — couverture confirmée : Kenya, Ouganda, Nigeria. Si le nom retenu par le projet ("Africa Call") désigne cet acteur ou un équivalent, il faut vérifier explicitement sa couverture Cameroun avant de construire l'architecture dessus.
Alternatives vérifiées ou à vérifier :
- **Twilio** : couverture Cameroun confirmée (PSTN entrant/sortant), mais tarif élevé vers mobile (~0,79 $/min, soit ~470 FCFA/min).
- **LAfricaMobile** (agrégateur francophone, orienté Afrique de l'Ouest/Centrale) : propose une Voice API, couverture Cameroun non confirmée dans leur doc publique — à vérifier directement avec leur équipe commerciale, candidat plus probable qu'Africa's Talking vu leur positionnement francophone.
- Vérifier aussi si Orange Cameroun / MTN Cameroun proposent une offre "voix entreprise" ou API click-to-call en direct (hors Mobile Money), pour comparer les coûts.

### 2. Mécanique technique du pont d'appel (call bridging)
Ce n'est **pas** lié à l'OS du téléphone du commerçant — c'est une fonctionnalité télécom standard : le serveur Django demande à l'agrégateur "compose le numéro A (client), quand il décroche, compose et connecte le numéro B (commerçant)". Ça marche vers n'importe quel téléphone (même un vieux Nokia), Android ou pas. Le vrai sujet est le coût : un pont = 2 legs d'appel facturés (client + commerçant), contre 1 seul flux de données pour un appel VoIP intra-app.

### 3. Coût et modèle économique
Chaque appel PSTN ponté coûte 2x le tarif/minute de l'agrégateur (deux lignes composées). Il faut décider qui absorbe ce coût (client, commerçant, ou marge plateforme) avant de dimensionner le pricing du service.

### 4. Confidentialité des numéros
Recommandation forte : utiliser la fonctionnalité de masquage/pontage de l'agrégateur pour que client et commerçant ne voient jamais le numéro réel de l'autre. Ça évite aussi que les utilisateurs contournent la plateforme pour les appels suivants, et permet de tracer durée d'appel / taux de réponse pour la notation des commerçants.

### 5. Gestion de la non-réponse
Définir un comportement clair si le commerçant "passif" ne décroche pas (timeout, nombre de tentatives, marquage temporaire "indisponible" après N appels manqués).

### 6. Confusion Orange Money / MTN Mobile Money
Ce sont des API de paiement, pas de téléphonie — à garder strictement séparées du mécanisme d'appel dans la documentation technique. Elles interviennent en aval, pour la monétisation (commission, abonnement).

## Flux d'architecture recommandé (abandonné, voir décision finale)

1. Recherche → liste de commerçants → clic "Appeler".
2. Django vérifie si le compte du commerçant est actuellement joignable en VoIP (présence + jeton push valide dans l'app).
   - Oui → appel Voix IP intra-app (WebRTC via un SDK type Twilio Voice, ou équivalent).
   - Non → appel PSTN ponté via l'agrégateur télécom retenu (à choisir après vérification de couverture Cameroun), avec masquage des numéros des deux côtés.
3. Orange Money / MTN Mobile Money interviennent séparément, pour la monétisation après mise en relation.

## Sources consultées
- [WhatsApp Business Calling API — Meta for Developers](https://developers.facebook.com/documentation/business-messaging/whatsapp/calling)
- [Africa's Talking — pays couverts](https://help.africastalking.com/en/articles/2727792-which-countries-are-africa-s-talking-products-in)
- [Twilio Voice Pricing — Cameroun](https://www.twilio.com/en-us/voice/pricing/cm)
- [LAfricaMobile — Voice API](https://developers.lafricamobile.com/docs/voice/introduction)
