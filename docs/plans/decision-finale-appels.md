# Décision finale — mécanisme d'appel NetBuis (v2.1, MVP)

Date : 2026-10-05 (v2.1 — ajout du choix de la ligne Orange / MTN avant l'appel). La v1 du 2026-09-30 est conservée plus bas comme historique.

## Décision actée (v2, confirmée par le porteur de projet le 2026-10-05)

**Android : un clic sur "Appeler" lance l'appel directement, sans passer par l'écran de l'app Téléphone avec le numéro pré-rempli.** NetBuis n'affiche jamais le numéro.

**Choix de la ligne avant l'appel (ajouté en v2.1, confirmé par le porteur de projet).** Avant de composer, l'utilisateur confirme d'abord avec quel opérateur il veut appeler : **Orange ou MTN, uniquement ces deux pour le moment** (Camtel et Nexttel ne sont pas proposés). Le parcours est donc : clic sur "Appeler" → écran "Avec quelle ligne voulez-vous appeler ?" avec deux gros boutons Orange et MTN → l'appel part immédiatement sur la ligne choisie. Un bouton "Annuler" est présent. Cet écran répond aussi au risque de clic accidentel signalé en v2 : il y a désormais deux gestes (appeler, puis choisir la ligne).

**iOS : l'utilisateur verra le numéro, pour le moment.** Apple impose une confirmation système ("Appeler ce numéro ?") avant tout appel lancé par une app, avec le numéro affiché. Aucun moyen officiel de la contourner (voir `recherche-appel-direct-sans-dialer-netbuis.md`). Le porteur de projet accepte cette différence jusqu'à ce qu'une solution soit trouvée. **Sur iPhone, le choix Orange / MTN de NetBuis ne peut pas être appliqué** : l'application n'a aucun moyen de désigner la SIM utilisée pour un appel `tel://`. Sur un iPhone à deux lignes, c'est le système qui demande la ligne.

Twilio et toute intégration CPaaS/VoIP restent abandonnés : c'est toujours un appel téléphonique classique, facturé par l'opérateur de l'utilisateur.

Cette v2 **corrige** la v1, qui écartait `ACTION_CALL` au profit d'`ACTION_DIAL`.

## Implémentation

### Android (cible principale au Cameroun)
- `TelecomManager.placeCall(uri, extras)` avec `EXTRA_PHONE_ACCOUNT_HANDLE` pour viser la SIM choisie ; `Intent.ACTION_CALL` suffit si le téléphone n'a qu'une ligne.
- Permissions : `CALL_PHONE` (demandée à l'exécution, une seule fois) et `READ_PHONE_STATE` (pour lister les SIM et leur nom d'opérateur). Les deux sont à déclarer et justifier dans la Play Console. D'après les pages d'aide Play consultées, `CALL_PHONE` n'est pas dans la liste des permissions "restreintes" (SMS / journal d'appels) ; à revérifier avant publication.
- **Faire correspondre "Orange" et "MTN" aux SIM réellement présentes** : lire le nom d'opérateur de chaque abonnement (SubscriptionManager / TelecomManager). Cas à prévoir :
  - téléphone à **une seule SIM** : l'écran de choix n'a plus de sens, il faut l'ignorer (ou afficher seulement la ligne disponible) ;
  - téléphone à deux SIM **Orange + MTN** : cas courant au Cameroun, le choix est utile ;
  - le **choix demandé n'est pas installé** (par exemple MTN choisi mais aucune SIM MTN) : message simple, sans jargon, proposant l'autre ligne ;
  - SIM dont le nom a été **renommé par l'utilisateur** ou eSIM : la détection par nom peut échouer ; prévoir un repli (afficher les noms des SIM tels que le système les donne).
- **Si une permission est refusée** : repli automatique sur `ACTION_DIAL` (le dialer s'ouvre avec le numéro pré-rempli, donc visible).
- Mémoriser le dernier choix dans les réglages est possible (à trancher, voir plus bas).
- Aucun plugin Flutter éprouvé pour viser une SIM : prévoir un petit module Kotlin via un MethodChannel.

### iOS
- `UIApplication.shared.open(URL(string: "tel://+237XXXXXXXXX")!)` : confirmation système avec le numéro. L'écran Orange / MTN ne s'affiche pas sur iOS (il serait trompeur, puisque NetBuis ne peut pas appliquer le choix).
- Pistes ultérieures, pas pour le MVP : appel par internet intégré via CallKit (vrai "un clic", mais plus un appel opérateur : data, coût par minute), ou WhatsApp.

## Ce que "le numéro n'est pas visible" veut vraiment dire (à savoir avant de le promettre)

C'est vrai de **l'interface NetBuis**, pas du téléphone dans son ensemble :

1. **Sur Android**, une fois l'appel lancé, l'écran d'appel du système affiche le numéro (ou le nom du contact s'il est enregistré), et le **journal d'appels du téléphone l'enregistre**.
2. **Le numéro arrive dans le téléphone** pour pouvoir être composé, donc techniquement récupérable par quelqu'un de motivé (inspection du trafic réseau, par exemple).
3. **Sur iOS**, le numéro est montré par le système, puis conservé dans les Récents.

Seul un vrai masquage (appel via un numéro intermédiaire géré par la plateforme) rendrait le numéro introuvable : c'est exactement ce que la v1 a écarté en abandonnant Twilio. **Conséquence assumée** : "personne ne voit le numéro" n'est plus garanti, et rien n'empêche un client de rappeler directement le commerçant plus tard, hors plateforme.

### Mesure de réduction de l'exposition (recommandée, peu coûteuse)
Ne **jamais** inclure le numéro dans les réponses de recherche, de carte ou de liste. L'application le demande au serveur **au moment où l'utilisateur confirme la ligne** (un endpoint du type `POST /calls/initiate`), qui :
- vérifie que l'appelant est connecté, que le `BusinessProfile` est `actif` et non bloqué ;
- vérifie le quota d'appels gratuits ou le solde de crédits (voir `monetisation-appels-orange-money.md`) et limite le nombre d'appels par minute pour empêcher le moissonnage de numéros ;
- crée la ligne `CallLog` (avec l'opérateur choisi) ;
- renvoie le numéro pour cet appel uniquement.

## Ce que ça change par rapport à la v1

- **Suivi d'appel (compromis n°2 de la v1) : partiellement récupéré.** NetBuis sait **qu'un appel a été lancé**, par qui, vers qui, quand, et avec quelle ligne. Cela alimente l'écran Historique, le quota gratuit et le seuil d'abonnement. NetBuis ne sait toujours **pas** si le commerçant a décroché ni la durée : lire le journal d'appels demanderait `READ_CALL_LOG`, permission restreinte par Google Play, à ne pas demander.
- **Masquage (compromis n°1 de la v1) : non résolu**, voir plus haut.
- **Monétisation par appel (compromis n°3)** : inchangée — le crédit décompté est un crédit NetBuis, pas la facturation de l'opérateur.
- **Risque de fraude** : un bouton qui appelle un inconnu en un geste est aussi le canal des arnaques Mobile Money décrites dans l'audit v18 (faux agent, faux transfert à rembourser). Raison de plus de garder visible le bouton "Signaler un problème ou un compte suspect" et la vérification des comptes business.

## Conséquences pour les maquettes et les autres documents

- **Fait en v2.1 :** `Main.dc.html` et `Quartier.dc.html` (les deux écrans où figure le bouton "Appeler") affichent maintenant l'écran "Avec quelle ligne voulez-vous appeler ?" (Orange / MTN, deux gros boutons avec icône et mot, Annuler), puis un état "Appel en cours... [nom] · ligne [opérateur]" avant de se fermer. C'est une démonstration : aucun appel réel.
- `modele-donnees-netbuis.md` (v18) : `CallLog` enregistre l'opérateur choisi ; point AA résolu.
- **Pas encore fait :** la FAQ de `Aide.dc.html` ("pourquoi le numéro du commerçant n'est pas visible") doit être nuancée ; l'écran de présentation (`Onboarding.dc.html`) promet que le numéro ne s'affiche "jamais à l'écran", ce qui est faux sur iPhone et incomplet sur Android (écran d'appel du système) ; la version iOS du bouton n'est pas maquettée.

## Points à trancher

1. Accepter définitivement que le numéro reste récupérable (journal d'appels, trafic réseau), ou prévoir plus tard un masquage par numéro intermédiaire ?
2. ~~Confirmation avant l'appel ?~~ **Résolu en v2.1** : confirmation sous la forme du choix de la ligne Orange / MTN.
3. Mémoriser le dernier choix de ligne (un seul geste ensuite) ou redemander à chaque appel ? Redemander est plus sûr contre les erreurs, mais plus lent pour un utilisateur qui appelle souvent.
4. Quel plafond d'appels par minute et par jour pour la protection contre l'aspiration de numéros ?
5. Camtel et Nexttel : à ajouter plus tard, ou jamais ?

## Sources
Voir `recherche-appel-direct-sans-dialer-netbuis.md` (TelecomManager, politique Play Console sur les permissions, forums Apple sur la confirmation `tel://`).

---

# Historique — v1 (2026-09-30)

**Décision v1 :** abandon de Twilio et de toute intégration CPaaS/VoIP. Au clic sur "Appeler", l'app ouvrait le dialer natif avec le numéro pré-rempli (`ACTION_DIAL` sur Android, `tel://` sur iOS) ; l'utilisateur lançait lui-même l'appel, facturé par son opérateur.

**Pourquoi c'était solide pour démarrer :** simplicité technique, coût nul pour la plateforme, aucune dépendance à un fournisseur, fonctionne avec tous les téléphones, aucune dégradation de qualité audio en réseau faible (appel opérateur normal).

**Ce que ça supprimait du projet :** compte Twilio, SDK Voice, webhooks, TwiML, la distinction "compte avec app (VoIP)" / "compte sans app (PSTN ponté)", le modèle de coût par minute, CallKit/ConnectionService.

**Compromis connus en v1 :** aucun masquage de numéro ; aucun suivi d'appel côté NetBuis ; aucune monétisation par appel ; coût international non maîtrisé en cas d'extension à d'autres pays.

**Évolution possible :** si le besoin de suivi, de masquage ou d'une expérience VoIP se fait sentir, la recherche Twilio/Telnyx/Agora reste dans `analyse-flux-appels.md` et `comparatif-solutions-telecom-appels.md`.
