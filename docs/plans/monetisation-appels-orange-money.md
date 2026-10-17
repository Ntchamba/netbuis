# Monétisation des appels — quota gratuit + paiement Orange Money/MTN MoMo

Date : 2026-09-30 (v5 — ajout de la démarche d'accès à l'API Orange Money)

## Besoin exprimé par le porteur de projet

Les 10 premiers appels (au clic sur "Appeler", mécanisme natif décrit dans `decision-finale-appels.md`) sont gratuits pour un nouvel utilisateur. Au-delà, chaque appel supplémentaire doit être facturé. Exigence explicite : **l'utilisateur ne doit saisir son code Mobile Money qu'une seule fois** (par "session"), pas à chaque appel payant.

> Note (v5) : le porteur de projet a évoqué un changement possible du modèle de quota ("1 appel gratuit par jour" + "pack de 50 FCFA" pour continuer), mais la taille exacte de ce pack (1 appel ou un lot de plusieurs appels ?) n'a pas encore été confirmée. Cette section garde donc pour l'instant la formulation "10 appels gratuits" en attendant cette confirmation ; la mécanique de pack de crédits décrite ci-dessous reste valable quel que soit le chiffre retenu.

## Décision actée : modèle de pack de crédits (résout directement l'exigence "un seul code")

**Recherche effectuée** : existe-t-il un mécanisme Orange Money/MTN MoMo permettant à un marchand de débiter plusieurs fois le portefeuille réel d'un client après une seule autorisation (mandat/prélèvement automatique, comme un abonnement) ? Aucun mécanisme de ce type n'a été trouvé confirmé et documenté officiellement pour le Cameroun (une vague trace d'un concept de "pré-approbation" existe dans la communauté développeurs MTN pour d'autres marchés, mais rien d'assez solide pour bâtir l'architecture dessus sans confirmation directe de leur équipe commerciale). **Ne pas compter sur un tel mécanisme.**

**La solution retenue ne nécessite pas ce mécanisme.** Le modèle de "pack de crédits" (déjà recommandé plus haut pour des raisons de montant minimum) résout aussi ce besoin :

1. Une fois le quota d'appels gratuits épuisé, l'app propose l'achat d'un **pack de crédits** (ex. 500 FCFA pour 100 appels). **Une seule transaction Orange Money/MTN MoMo** → un seul prompt USSD → un seul code saisi.
2. Cette transaction crédite un **solde interne** stocké côté Django, lié au compte utilisateur.
3. Chaque appel suivant décrémente ce solde interne (ex. -5 FCFA) **sans aucune nouvelle communication avec Orange Money/MTN MoMo** — donc aucun nouveau prompt, aucun nouveau code à saisir. L'appel se lance directement.
4. Seul le rechargement (quand le solde interne atteint zéro) redéclenche une transaction Mobile Money, donc une nouvelle saisie de code — mais uniquement à ce moment-là.

Ce n'est donc pas une notion de "session journalière" au sens strict, mais de solde de crédits restant : l'utilisateur peut passer des dizaines d'appels sur plusieurs jours sans resaisir son code tant qu'il a du crédit, ce qui est plus flexible qu'une limite temporelle fixe.

Ce modèle règle simultanément trois problèmes déjà identifiés : le montant minimum de transaction (le pack dépasse largement 50 FCFA), les frais/taxes qui rendraient une transaction de 5 FCFA non rentable, et cette exigence de ne pas ressaisir le code à chaque appel.

## Deux problèmes techniques importants (contexte du choix ci-dessus)

### 1. Ne jamais collecter le code PIN Orange Money/MTN MoMo dans l'app NetBuis

Ce n'est pas ainsi que fonctionne un paiement mobile money marchand, et c'est important de comprendre pourquoi avant de designer l'écran :

**Flux réel (confirmé sur plusieurs intégrations Orange Money/MTN MoMo Cameroun)** :
1. L'app NetBuis envoie au serveur Django le numéro de téléphone saisi par l'utilisateur pour ce paiement (l'achat d'un pack) et le montant.
2. Django appelle l'API marchande Orange Money (ou MTN MoMo) avec ces informations et les identifiants du compte Pro/Business.
3. **L'opérateur envoie directement sur le téléphone portant ce numéro** une notification/prompt USSD officiel : *"Confirmer le paiement de X FCFA à NetBuis ? Entrez votre code Mobile Money :"*.
4. L'utilisateur saisit son code **dans cette interface opérateur**, jamais dans l'app NetBuis.
5. L'opérateur notifie le serveur Django du résultat (webhook de confirmation), qui crédite alors le solde interne côté app.

**Pourquoi c'est non négociable** : un formulaire dans l'app qui demande le code PIN et le transmet à une API serait un risque de sécurité majeur (vol de PIN en cas de faille ou d'employé malveillant, possibilité de vider le compte mobile money d'un utilisateur), probablement une violation des conditions d'utilisation marchand d'Orange/MTN, et de toute façon les API marchandes ne sont pas conçues pour recevoir un PIN "en clair" transmis par un tiers.

**Ce que l'app NetBuis doit faire concrètement** : afficher une modale d'attente ("Confirmez le paiement de X FCFA sur votre téléphone"), pas un champ de saisie de code.

### 2. 5 FCFA est très probablement en dessous du montant minimum autorisé (par transaction individuelle)

Le montant minimum de transaction Orange Money Cameroun est de **50 FCFA** — en dessous, la transaction est refusée par le système. Pire : même au minimum de 50 FCFA, les frais/taxes appliqués (au retrait) peuvent atteindre 54 FCFA, soit plus que le montant lui-même. Une note d'espoir : les **paiements à un marchand enregistré sont exclus de la taxe électronique de 0,2%** applicable aux transferts/retraits classiques (source : rapport FMI cité par Investir au Cameroun) — mais un frais fixe de 4 FCFA par transaction a été ajouté début 2025 pour d'autres catégories de transactions, à vérifier directement avec Orange si applicable aux paiements marchands. **Le pack de crédits (dépassant largement 50 FCFA) contourne ce problème.**

## Point à trancher : couverture MTN Mobile Money

Le projet vise aussi les utilisateurs MTN (mentionné dans la description du projet). Si seul Orange Money est intégré pour le paiement, tous les utilisateurs MTN sans compte Orange Money seraient bloqués. Il faut prévoir le même mécanisme de push USSD côté API MTN MoMo Cameroun (structure similaire, identifiants différents), pas seulement Orange Money. Ce besoin est renforcé par le point sur le multi-SIM ci-dessous.

## Vérification du compte utilisateur (une seule fois, à l'inscription — différent du paiement)

Ce document distingue deux vérifications différentes, à ne pas confondre :
- **Vérification de compte** (inscription, une seule fois) : SMS OTP classique, sert à empêcher la création de faux comptes multiples pour cumuler des lots d'appels gratuits à l'infini.
- **Vérification de paiement** (à chaque achat de pack) : aucune étape séparée nécessaire — la réussite du paiement Mobile Money lui-même (prompt USSD + PIN côté opérateur) fait foi que le numéro est valide.

**Flux d'inscription** :
1. L'utilisateur saisit son numéro.
2. Le serveur Django envoie un code à usage unique par SMS (via un service comme Twilio Verify, ou idéalement une passerelle locale camerounaise comme Nexah, généralement plus rapide et moins chère vers des numéros camerounais qu'un routage international via Twilio).
3. L'utilisateur saisit le code (auto-remplissage possible sur Android via la SMS Retriever API de Google).
4. Le compte est créé avec ce numéro comme identifiant vérifié.

**Sur la latence SMS** : aucun fournisseur (Twilio, agrégateur local, Google) ne peut garantir un délai de livraison précis (ex. moins de 3 secondes) — limite technique du SMS ("best-effort", pas temps réel), documentée par Twilio eux-mêmes. En pratique, quelques secondes à 30s+ en cas de réseau chargé. Sans conséquence puisque cette vérification n'a lieu qu'une fois, à l'inscription — pas avant chaque appel ni chaque achat de pack.

Ce numéro vérifié sert d'identifiant de compte, indépendamment du numéro utilisé pour payer un pack (voir section multi-SIM).

## Point critique : usage multi-SIM au Cameroun

Beaucoup d'utilisateurs camerounais changent régulièrement de puce dans leur téléphone. Le prompt de paiement Orange Money/MTN MoMo suit le numéro (la carte SIM), pas l'appareil ni l'application — si la puce enregistrée n'est plus dans le téléphone au moment de l'achat d'un pack, le prompt n'atteindra jamais l'utilisateur à cet instant.

**Solution produit retenue** : ne pas figer l'achat de pack sur le numéro du compte. Au moment de l'achat, proposer à l'utilisateur de choisir/confirmer le numéro Mobile Money à utiliser pour CETTE transaction (opérateur + numéro), pré-rempli avec le numéro du compte par défaut mais modifiable. Le numéro de compte (identité/connexion) reste lui fixe.

**Gestion de l'échec/timeout** : si la confirmation n'arrive pas dans un délai raisonnable (~60-90 secondes), afficher un message clair invitant à vérifier la SIM ou changer de numéro.

## Comment obtenir l'accès à l'API Orange Money au Cameroun

Question posée par le porteur de projet : faut-il se déplacer physiquement dans une agence/boutique Orange pour obtenir l'accès à l'API ?

**Réponse courte : non, pas d'après les informations publiques trouvées — la démarche est initiée en ligne.** Deux portails distincts existent, et il est probable qu'il faille passer par les deux (l'un pour le côté commercial/marchand, l'autre pour l'accès technique à l'API) :

1. **Côté commercial (compte marchand Business)** : la souscription à l'offre marchand Orange Money Cameroun se fait en ligne via [om.orange.cm](https://om.orange.cm/) (page officielle : [Devenir marchand — Orange Money Cameroun](https://orangemoney.orange.cm/fr/om-partenaires/partenaire-commercial.html)). Aucune mention d'un passage obligatoire en boutique. Délai annoncé : **2 à 14 jours** entre la souscription et l'activation effective du compte marchand. Contact business indiqué pour les questions précises (documents requis, etc.) : **partenariat.OM@orange.com**. Le porteur de projet a indiqué avoir déjà ce compte Pro/Business — cette étape serait donc déjà franchie.
2. **Côté technique (accès à l'API)** : Orange opère un portail développeur global, [developer.orange.com](https://developer.orange.com/products/payment/apply-orange-money/), qui référence l'API "Orange Money Web Payment / M Payment" avec une couverture Cameroun ([fiche API](https://developer.orange.com/apis/om-webpay)). L'accès se demande via un **formulaire en ligne** sur cette page ; une fois complété, "l'équipe locale responsable de l'offre" (donc l'équipe Orange Cameroun) recontacte le demandeur pour la suite. Il existe aussi un portail business local, [orangemoneybusiness.orange.cm](https://orangemoneybusiness.orange.cm/services/om-api), qui référence spécifiquement le service API Orange Money côté Cameroun.

**Ce qui n'a pas pu être confirmé publiquement** (à demander directement à Orange lors du contact) :
- La liste exacte des documents/justificatifs à fournir pour l'accès API (au-delà du compte marchand déjà actif).
- Si une adresse IP fixe/serveur dédié est exigée pour le livrable technique (mentionné comme pratique courante pour ce type d'API marchande sur des portails Orange d'autres pays, mais non confirmé spécifiquement pour le Cameroun).
- Le délai réel entre la demande d'accès API et la réception des identifiants (clé/secret) et de la documentation technique complète (schéma des requêtes, environnement de test/sandbox).

**Recommandation concrète** : puisque le compte Business existe déjà, la prochaine étape est de remplir le formulaire sur [developer.orange.com/products/payment/apply-orange-money](https://developer.orange.com/products/payment/apply-orange-money/) **et**, en parallèle, écrire directement à **partenariat.OM@orange.com** en mentionnant le compte Pro/Business déjà actif, pour demander explicitement : (a) l'accès API marchand pour intégration mobile, (b) le guide d'intégration technique complet, (c) l'accès à un environnement de test (sandbox) avant la mise en production. Passer par les deux canaux à la fois évite de perdre du temps si l'un des deux est plus réactif que l'autre.

Pour MTN MoMo, la démarche équivalente n'a pas encore été recherchée en détail (voir "Pending Tasks" — point à traiter en parallèle).

## Point à trancher : portée du quota "10 appels gratuits"

- Le quota est-il lié au compte utilisateur vérifié ou à l'installation de l'app ? **Recommandé : lié au compte vérifié**, sinon désinstaller/réinstaller l'app permettrait de recommencer à zéro indéfiniment.
- Le quota se renouvelle-t-il (ex. par mois) ou est-il un capital unique à vie ? À trancher selon le modèle économique visé.
- **(v5, non résolu)** Le porteur de projet a évoqué un nouveau modèle : "1 appel gratuit par jour" + un "pack de 50 FCFA" pour continuer au-delà. Question ouverte posée mais pas encore répondue : ce pack de 50 FCFA donne-t-il droit à 1 seul appel supplémentaire, ou à un lot de plusieurs appels ? Cette distinction change complètement l'économie du modèle (50 FCFA pour 1 appel serait probablement non rentable une fois les frais opérateur déduits, alors qu'un lot de plusieurs appels pour 50 FCFA serait cohérent avec le modèle de pack de crédits déjà acté ci-dessus).

## Flux technique final (résumé)

1. **Inscription (une fois)** : vérification SMS OTP → création du compte utilisateur vérifié.
2. Compteur d'appels gratuits consommés + solde de crédits, stockés côté Django, liés à ce compte vérifié.
3. Au clic sur "Appeler" : si quota gratuit restant > 0 → décrémente et lance l'appel natif directement (voir `decision-finale-appels.md`).
4. Si quota gratuit épuisé → vérifier le solde de crédits interne :
   - Solde suffisant → décompte silencieux (aucune interaction Mobile Money) et lance l'appel directement.
   - Solde insuffisant → proposer l'achat d'un pack : demander le numéro/opérateur de paiement (pré-rempli, modifiable — voir multi-SIM), déclencher le flux USSD Orange Money/MTN MoMo (PIN côté opérateur, jamais dans l'app), puis au webhook de confirmation → créditer le solde interne → lancer l'appel.
5. En cas de timeout du paiement, message d'erreur explicite invitant à vérifier la SIM ou changer de numéro.

## Sources consultées
- [Njokalab — intégration MTN MoMo & Orange Money Cameroun (flux USSD confirmé)](https://www.njokalab.com/insights/how-to-integrate-mtn-momo-orange-money-cameroon-api/)
- [Orange Money Cameroun — grille tarifaire (montant minimum 50 FCFA)](https://orangemoney.orange.cm/fr/tarification-orange-money.html)
- [MomoCalc — frais Mobile Money Cameroun 2026](https://momocalc.com/fr/cameroon)
- [Investir au Cameroun — taxe mobile money 0,2%, exclusion des paiements marchands, frais fixe 4 FCFA depuis 2025](https://www.investiraucameroun.com/finance/1212-22875-mobile-money-la-taxe-de-0-2-fait-grimper-les-couts-de-transaction-jusqu-a-400-selon-le-fmi)
- [Orange Developer — Orange Money Web Payment / M Payment API](https://developer.orange.com/apis/om-webpay)
- [Business Orange CI — API Orange Money (types d'API marchand disponibles)](https://business.orange.ci/fr/orange-money/api-orange-money.html)
- [PyPI — package mtnmomo (endpoints Collections API : requestToPay, pas de mandat confirmé)](https://pypi.org/project/mtnmomo/)
- [Android Developers — SMS Retriever API](https://developer.android.com/identity/sms-retriever)
- [Twilio — latence de livraison SMS, absence de visibilité sur le délai réseau opérateur](https://www.twilio.com/docs/messaging/guides/scaling-queueing-latency)
- [Orange Money Cameroun — Devenir marchand (souscription en ligne, délai 2 à 14 jours)](https://orangemoney.orange.cm/fr/om-partenaires/partenaire-commercial.html)
- [Orange Developer — Apply for Orange Money (formulaire de demande d'accès API)](https://developer.orange.com/products/payment/apply-orange-money/)
- [Orange Money Business Cameroun — service API Orange Money](https://orangemoneybusiness.orange.cm/services/om-api)
