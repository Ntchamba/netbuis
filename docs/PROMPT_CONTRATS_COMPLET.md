# Prompt complet — « NetBuis Contrats » (autonome, sans dépôt)

À coller tel quel dans Claude Code, dans un DOSSIER VIDE (par exemple `~/netbuis-contrats`) : le prompt contient tout ce qu'il faut (texte du contrat, couleurs, icône), il ne suppose pas le dépôt NetBuis. Fait pour une session qui tourne SUR TON ORDINATEUR.

```
Tu es Claude Code, dans un dossier vide de mon ordinateur. Tu vas construire une petite application web installable (PWA) nommée « NetBuis Contrats », en français, complète et testée. Réponds-moi en français, court, sans jargon. Tu travailles seul : fais tout (code, tests, documentation, commit Git local) sans me demander de confirmation, sauf si tu es bloqué.

# 1. Le besoin
Je m'appelle Jeff. Je vends à des commerçants du Grand Marché de Maroua (Cameroun) des abonnements pour qu'ils apparaissent dans l'application NetBuis (recherche de commerces locaux). Je dois leur faire signer un contrat d'adhésion sur mon téléphone Android, parfois avec une mauvaise connexion Internet. Il n'y a PAS d'opérateur de SMS : aucune vérification par code. L'application doit :
- proposer un modèle de contrat par défaut (texte fourni plus bas) ;
- recueillir les informations du commerçant et SA SIGNATURE au doigt sur l'écran ;
- fabriquer un PDF numéroté ;
- l'envoyer sur MON WhatsApp (je le transmets ensuite moi-même au commerçant) ;
- garder un registre sur le téléphone, avec export CSV.
Tout est AUTONOME : aucun serveur, aucune base de données distante, aucun compte, aucun SMS. Les données restent sur le téléphone.

# 2. Technique (imposée, pour rester simple et fiable)
- HTML + CSS + JavaScript en modules ES, SANS étape de construction (pas de React, pas de Vite, pas de TypeScript, pas de bundler). Un seul dossier statique que n'importe quel hébergeur de fichiers peut servir.
- Une seule bibliothèque tierce autorisée : jsPDF (génération du PDF). Copie-la dans `vendor/` (« vendorisée ») avec sa licence : trouve la dernière version par `npm view jspdf version`, récupère le paquet avec `npm pack jspdf` dans un dossier jetable, copie le fichier UMD minifié (jspdf.umd.min.js) et la licence dans `vendor/`, note la version EXACTE et l'empreinte SHA-256 du fichier dans `README.md`. N'invente aucune version. Aucune autre dépendance à l'exécution, aucun appel réseau externe (pas de CDN, pas de polices externes, pas de statistiques) : tout marche hors connexion après la première visite.
- Outils de développement autorisés seulement pour les tests : Node.js (`node --test`) et Playwright (s'il n'est pas installé : `npm i -D playwright` puis `npx playwright install chromium`, dans un dossier de test, jamais dans l'application).
- Stockage : IndexedDB (dans le navigateur du téléphone). Mot de passe : API WebCrypto (PBKDF2). Signature : <canvas> avec les événements pointer.
- Identité visuelle : orange d'accent #F2942E, texte sur orange #1A1200, fond clair #F7F7F8, cartes blanches #FFFFFF, bordures #E3E3E7, texte #18181B, texte secondaire #6B6B70, texte orange lisible #A85A00, erreur #C93E28. Polices système (system-ui). Coins arrondis 12 px. Mode clair seulement (c'est suffisant).
- Icône : fichier `icons/icon.svg` avec exactement ce SVG, puis génère `icons/icon-192.png`, `icons/icon-512.png`, `icons/icon-maskable-192.png`, `icons/icon-maskable-512.png` (version « maskable » : fond orange plein jusqu'au bord, loupe réduite à 60 % au centre) et `icons/apple-touch-icon.png` (180x180) en rendant le SVG avec Chromium (Playwright). SVG de base :
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <title>NetBuis</title>
  <rect width="512" height="512" rx="112" fill="#F2942E"/>
  <circle cx="232" cy="232" r="96" fill="none" stroke="#1A1200" stroke-width="40"/>
  <line x1="302" y1="302" x2="376" y2="376" stroke="#1A1200" stroke-width="44" stroke-linecap="round"/>
</svg>

# 3. Les écrans (assistant, gros boutons ≥ 44 px, utilisable d'une main, français)
Navigation par un menu en bas : « Nouveau contrat », « Registre », « Réglages ».

## 3.1 Premier lancement et verrouillage
- Premier lancement : choisir un mot de passe de l'application (6 caractères minimum, confirmation). Stocké sous forme de dérivation PBKDF2-SHA256 avec un sel aléatoire de 16 octets et au moins 210 000 itérations ; jamais en clair.
- Ensuite le mot de passe est demandé à chaque ouverture et après 5 minutes d'inactivité (verrouillage automatique). Après 5 essais ratés : attente croissante (30 s, 1 min, 2 min, 5 min…) mémorisée même après rechargement.
- Bandeau permanent discret (fermable) : « Les contrats sont enregistrés seulement sur ce téléphone. Si vous videz les données du navigateur ou perdez le téléphone, le registre est perdu. Exportez le CSV de temps en temps et gardez les PDF envoyés sur WhatsApp. »
- Mot de passe oublié : propose « Effacer toutes les données » (confirmation en deux étapes) : c'est la seule voie, dis-le clairement.

## 3.2 Réglages (à remplir une fois)
Champs, avec leur valeur par défaut :
- NetBuis : nom (vide), forme juridique (vide), n° d'immatriculation / RCCM (vide), adresse (vide), représentant (vide).
- Agent : nom (vide), numéro d'agent (vide), SIGNATURE de l'agent (zone de dessin au doigt, enregistrée, bouton « Refaire ») : elle est réutilisée sur chaque contrat.
- « Mon numéro WhatsApp » : chiffres avec indicatif sans + (ex. 237670000000) ; validation : 11 à 15 chiffres.
- Formules (liste modifiable : ajouter, modifier, supprimer, réordonner) : chaque formule a un libellé, un prix en FCFA (nombre entier, vide autorisé), une périodicité (mensuelle / à l'acte / autre texte), un texte « ce que comprend la formule ». Par défaut : « Formule A — Abonnement mensuel » (prix vide, périodicité mensuelle) et « Formule B — Paiement à la clientèle acquise » (prix vide, périodicité à l'acte).
- Définition de « client acquis » (texte libre, vide par défaut).
- Autres variables du contrat (voir §4) : montant et devise, modes de paiement acceptés, échéance, retard de paiement, préavis de changement de prix (jours), durée et renouvellement, préavis de résiliation (jours), remboursement, délai de mise en ligne (jours), moyens et horaires d'assistance, durée de conservation de la pièce d'identité, contact pour les données personnelles, tribunal compétent (défaut : « Maroua » marqué à confirmer), délai de contestation du relevé (jours).
- Version du modèle (défaut « v0.1 »).
- Case « Le modèle a été relu et validé par un juriste » (décochée par défaut).
Règles : tout champ vide d'une variable du contrat apparaît « [à compléter] » dans le texte du contrat. Tant qu'au moins une variable obligatoire est vide, un bandeau orange « Modèle incomplet : ... » s'affiche sur les écrans Nouveau contrat et Lecture, et le PDF porte la mention BROUILLON (voir §5). On peut quand même générer un contrat (brouillon) : ne bloque pas.

## 3.3 Nouveau contrat — assistant en 5 étapes (barre de progression « Étape n/5 »)
1. Commerçant : nom et prénom OU raison sociale (obligatoire), activité (obligatoire), adresse et repère : quartier, marché, n° de boutique (obligatoire), téléphone du compte (obligatoire), n° de la pièce d'identité (obligatoire), qualité du signataire (titulaire / représentant ; défaut titulaire). Validation du téléphone camerounais : 9 chiffres commençant par 6, avec ou sans +237 ou 237 ; normalisation en « +2376XXXXXXXX » ; messages d'erreur clairs en français sous le champ. Brouillon enregistré automatiquement à chaque changement ; reprise proposée à l'ouverture (« Reprendre le contrat en cours de … »).
2. Formule : choix d'UNE formule parmi celles des réglages ; le prix est pré-rempli et modifiable pour ce contrat ; date de début (défaut aujourd'hui).
3. Lecture : le contrat complet (texte du §4 avec toutes les valeurs substituées) défile à l'écran ; case obligatoire « J'ai lu et j'accepte ce contrat » (bloque le bouton Continuer tant qu'elle n'est pas cochée) ; les passages « [à compléter] » sont surlignés.
4. Signature : zone de signature plein écran large (fond blanc, bordure), au doigt ou au stylet ; bouton « Effacer » ; la signature est obligatoire (refuse un canvas vide ou quasi vide) ; champ « Nom du signataire » (pré-rempli avec le nom du commerçant, modifiable) ; date et heure automatiques affichées (fuseau Africa/Douala, UTC+1).
5. Générer et envoyer : crée le contrat, attribue le numéro NB-AAAA-NNNN (AAAA = année, NNNN = compteur annuel sur 4 chiffres, 0001 en début d'année, incrémenté sans trou ni doublon même en cas de plantage), génère le PDF (voir §5) et affiche : le résumé, l'empreinte SHA-256 du PDF (en hexadécimal, avec bouton Copier), et les boutons :
   - « Envoyer sur WhatsApp » (bouton principal) : si `navigator.canShare({files:[file]})` est vrai → `navigator.share({files:[file], title:"Contrat NB-…", text:"…"})` avec le PDF ; je choisis WhatsApp puis ma propre conversation. Sinon (repli) : télécharge le PDF, puis ouvre `https://wa.me/<mon numéro WhatsApp>?text=<message encodé>` avec le message « Contrat NB-AAAA-NNNN — <nom du commerçant> — <formule> ». Si mon numéro WhatsApp n'est pas renseigné : demande-le avant. Après un partage réussi ou un lien ouvert, marque le contrat « envoyé : oui » (une annulation du partage ne le marque pas).
   - « Télécharger le PDF », « Partager encore », « Nouveau contrat ».

## 3.4 Registre
Liste des contrats signés, du plus récent au plus ancien : n°, commerçant, téléphone, formule, prix, date, pastille « envoyé / non envoyé » et « BROUILLON » si c'était un brouillon. Recherche instantanée (nom, téléphone, n°, quartier). Ouvrir un contrat : détail + boutons Télécharger, Partager encore, (re)marquer comme envoyé. Export CSV du registre (bouton) : colonnes n°, nom, activité, quartier_marche_boutique, telephone, piece_identite, formule, prix_fcfa, date_signature, version_modele, brouillon, envoye, empreinte_pdf ; séparateur point-virgule, UTF-8 avec BOM pour Excel, échappement correct des guillemets, retours à la ligne et points-virgules, et protection contre l'injection de formules (préfixer d'une apostrophe les cellules commençant par = + - @). Suppression d'un contrat : seulement avec confirmation ET ressaisie du mot de passe.

# 4. Le texte du contrat (À REPRENDRE TEL QUEL — ne réécris pas le juridique)
Voici le modèle, en Markdown. Les passages entre crochets [ ... ] sont des VARIABLES : remplace-les par les valeurs des réglages et du formulaire (liste : nom NetBuis, forme juridique, RCCM, adresse, représentant, nom du commerçant, activité, adresse/repère, téléphone, pièce d'identité, formule choisie + prix, définition de client acquis, montants, échéances, durées, préavis, assistance, durée de conservation, contact, tribunal…) et affiche « [à compléter] » si la valeur est vide. Les cases « ☐ » de la section 2 : n'affiche QUE la formule choisie, cochée. Les cases de fin (copie reçue, pièce vérifiée, téléphone vérifié) deviennent des lignes avec « [ ] » à cocher à la main sur le papier ; dans l'application, remplace « Téléphone du compte vérifié (code reçu) » par « Numéro de téléphone communiqué par le commerçant » car il n'y a pas de code. Le texte :

<<<CONTRAT
# Contrat d'adhésion commerçant NetBuis — MODÈLE À FAIRE RELIRE PAR UN JURISTE

> **Brouillon de travail, pas un avis juridique.** Les passages entre crochets [ … ] sont à remplir ou à décider. Faites relire le texte par un avocat ou un juriste camerounais avant de le faire signer (validité des signatures électroniques, clauses de commission, protection des données personnelles, mentions obligatoires, tribunal compétent).

**Entre** :
- **NetBuis**, [forme juridique, numéro d'immatriculation / RCCM, adresse, représentant], ci-après « NetBuis » ;
- **Le commerçant** : nom et prénom / raison sociale : ____________ ; activité : ____________ ; adresse et repère (quartier, marché, n° de boutique) : ____________ ; numéro de téléphone du compte : ____________ ; n° de la pièce d'identité (CNI) : ____________ ; ci-après « le commerçant ».

## 1. Objet
NetBuis met à disposition du commerçant une fiche dans l'application NetBuis et le fait apparaître dans les recherches des utilisateurs de sa ville. Les utilisateurs peuvent joindre le commerçant [selon les modalités actuelles : appel de l'utilisateur vers l'équipe NetBuis, bouton WhatsApp, …].

## 2. Formule choisie (cocher UNE case)
- ☐ **Formule A — Abonnement mensuel : [100 000] FCFA par mois** ; elle comprend : [visibilité prioritaire dans les résultats, nombre de produits/photos, …].
- ☐ **Formule B — Paiement à la clientèle acquise** : NetBuis facture au commerçant [montant ou pourcentage] pour chaque « client acquis » au sens de l'article 4.
- ☐ **Formule C — [autre]** : ____________

## 3. Prix, facturation et paiement
- Montant, devise (FCFA), taxes éventuelles : [ ].
- Échéance et mode de paiement (espèces, Mobile Money : MTN / Orange, virement) : [ ]. Un **reçu numéroté** est remis pour chaque paiement.
- Retard de paiement : [suspension de la fiche après … jours, pénalités éventuelles].
- Changement de prix : préavis écrit de [30] jours.

## 4. « Client acquis » (formule B) — à définir précisément
Est considéré comme **client acquis** : [définition mesurable : par exemple une mise en relation enregistrée par l'application (contact WhatsApp ouvert depuis la fiche, appel transmis au commerçant, commande confirmée par le commerçant)]. Ne sont pas comptés : [doublons du même utilisateur dans un délai de … jours, contacts annulés, …]. **Preuve** : les enregistrements de l'application (date, heure, type de contact) ; le commerçant peut en demander le relevé chaque mois. Contestation possible sous [8] jours après réception du relevé.

## 5. Durée, renouvellement, résiliation
Durée : [1 mois renouvelable tacitement / durée fixe]. Résiliation par l'une ou l'autre partie avec préavis de [ ] jours, par écrit (message, e-mail ou remise en main propre). Remboursement éventuel : [ ].

## 6. Obligations du commerçant
Informations exactes et à jour (nom, activité, quartier, téléphone, produits et prix) ; ne pas publier de contenu illégal, trompeur ou contrefait ; répondre aux clients ; utiliser son propre compte ; ne pas céder son compte.

## 7. Obligations de NetBuis
Mettre la fiche en ligne après validation [sous … jours] ; assurer le service avec soin, sans garantir une disponibilité continue ni un nombre de clients ; assistance : [moyens, horaires].

## 8. Données personnelles
Données collectées : identité, téléphone, pièce d'identité, photos, localisation du commerce. Finalités : création et vérification du compte, affichage de la fiche, mise en relation, facturation. Le **numéro de téléphone du commerçant** [est vu par l'équipe NetBuis pendant un appel et peut apparaître dans le lien WhatsApp de la fiche]. La pièce d'identité est conservée de façon **non publique**, consultable seulement par l'équipe habilitée, pendant [durée]. Droits d'accès, de rectification et de suppression : écrire à [contact]. Base légale et formalités auprès de l'autorité camerounaise de protection des données : [à faire vérifier].

## 9. Responsabilité
NetBuis n'est pas partie aux ventes entre le commerçant et ses clients. Limites de responsabilité : [à rédiger avec le juriste].

## 10. Droit applicable et litiges
Droit camerounais. Tentative de règlement amiable, puis tribunal compétent de [Maroua] : [à confirmer].

## 11. Signature
Fait à ____________, le ____ / ____ / ________, en [deux] exemplaires originaux (un pour chaque partie).

Le commerçant (nom, « lu et approuvé », signature) : ____________ 
NetBuis, par son agent [nom, n° d'agent] : ____________

☐ Le commerçant déclare avoir reçu une copie du contrat. ☐ Pièce d'identité vérifiée par l'agent. ☐ Téléphone du compte vérifié (code reçu).

---
**Version du modèle : v0.1 (brouillon) — à numéroter à chaque changement : on doit toujours savoir quelle version chaque commerçant a signée.**

CONTRAT>>>

Structure : un objet JavaScript `defaultTemplate` (module `js/template.js`) découpé en articles (titre + paragraphes) avec des jetons `{{nom_variable}}` ; une fonction pure `renderContract(template, valeurs)` qui renvoie la liste des blocs et les noms des variables restées vides. Le texte du modèle n'est modifiable que par les réglages (variables), pas par l'écran du contrat.

# 5. Le PDF
- Format A4 portrait, marges 18 mm, police Helvetica de jsPDF (accents français OK : é è à ç ê î ô ù ï ü œ ; remplace les caractères non pris en charge, par exemple « ☐ » → « [ ] », « ’ » → « ' », tirets longs → « - »).
- En-tête : « NetBuis — Contrat d'adhésion commerçant », numéro NB-AAAA-NNNN, date et heure de signature (Africa/Douala), version du modèle.
- Corps : le contrat complet (articles titrés en gras), saut de page propre (pas de titre seul en bas de page), formule et prix en évidence dans un encadré.
- Signatures : deux encadrés côte à côte : « Le commerçant » (nom, qualité, image de la signature, date/heure) et « NetBuis, par son agent » (nom, n° d'agent, image de la signature de l'agent). Images PNG réduites à une taille raisonnable (max 600 px de large) pour un PDF léger (< 300 Ko si possible).
- Pied de page de CHAQUE page : « NB-AAAA-NNNN — page n/N — modèle v0.1 — empreinte du contenu : <16 premiers caractères du SHA-256 du JSON du contrat> » et, selon le cas : « BROUILLON — modèle incomplet » (si des variables sont vides) et/ou « BROUILLON — non relu par un juriste » (case non cochée). En plus, ces mentions BROUILLON apparaissent en filigrane diagonal gris clair sur chaque page.
- Empreinte du PDF : SHA-256 des octets du PDF final (affichée à l'écran et dans le registre/CSV, pas dans le PDF lui-même).
- Nom du fichier : NB-AAAA-NNNN_<nom-du-commerçant-sans-accents-ni-espaces>.pdf.

# 6. PWA et hors connexion
- `manifest.json` : name « NetBuis Contrats », short_name « Contrats », lang fr, start_url ".", display standalone, orientation portrait, theme_color #F2942E, background_color #F7F7F8, icônes 192/512 (any) et 192/512 (maskable). `<link rel="apple-touch-icon">` et meta apple-mobile-web-app-* ; `<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">`.
- Service worker `sw.js` (à la racine) : « réseau d'abord, copie de secours en cache » pour les fichiers de l'application (jamais de piège de cache : un nom de cache versionné, nettoyage des anciens), précache de tous les fichiers de l'application au premier chargement. Il ne gère que les requêtes GET du même site.
- Content-Security-Policy en balise `<meta http-equiv>` : default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data: blob:; connect-src 'self'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'. Donc pas de script ni de style en ligne (feuilles et scripts dans des fichiers).
- Aucun `console.log` d'information personnelle (nom, téléphone, pièce d'identité) nulle part.
- Accessibilité : libellés `<label>` liés aux champs, contraste suffisant, focus visible, messages d'erreur annoncés (aria-live), boutons ≥ 44 px, langue de la page `fr`.

# 7. Arborescence attendue
index.html, manifest.json, sw.js, css/app.css, js/ (app.js, ui.js, template.js, render.js, phone.js, numbering.js, csv.js, hash.js, pdf.js, share.js, store.js (IndexedDB), lock.js (mot de passe), signature.js), vendor/ (jspdf + licence), icons/, tests/unit/*.test.js, tests/e2e/parcours.mjs, Dockerfile, nginx.conf.template, .dockerignore, README.md, .gitignore.

# 8. Tests (obligatoires, tous doivent passer)
(a) Unitaires `node --test` des fonctions pures : numérotation (NB-AAAA-NNNN, passage d'année, pas de doublon), rendu du modèle (variables remplacées, « [à compléter] », liste des variables vides, une seule formule affichée), validation et normalisation du téléphone camerounais (valides : 670000000, 6 70 00 00 00, +237670000000, 237670000000 ; invalides : 570000000, 67000000, 6700000000, lettres), CSV (BOM, point-virgule, guillemets, retours à la ligne, injection de formule), empreinte SHA-256 (vecteur connu : « abc » → ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad), PBKDF2 (le même mot de passe vérifie, un autre non).
(b) Essai de bout en bout Playwright (Chromium) sur un petit serveur statique local, écran de téléphone 390x844 : premier lancement et création du mot de passe ; réglages (identité, signature de l'agent dessinée à la souris, numéro WhatsApp, deux formules avec prix) ; création d'un contrat complet avec signature à la souris ; génération du PDF ; contrôle que le PDF est valide (commence par %PDF, la taille est raisonnable ; si `pdftotext` est installé, le texte extrait contient le nom du commerçant, le numéro du contrat et la mention de la formule ; sinon vérifie les octets) ; registre (le contrat y est, la recherche le trouve) ; export CSV (contenu vérifié) ; verrouillage après inactivité (simule le temps) et mauvais mot de passe refusé ; rechargement HORS CONNEXION (`context.setOffline(true)`) : l'application se charge encore et redemande le mot de passe ; partage : simule `navigator.share`/`canShare` pour vérifier l'appel avec un fichier PDF, et le repli (`wa.me` avec le numéro et le message) quand le partage de fichier n'existe pas ; toute erreur de console ou de page = échec. Fais des captures d'écran de chaque étape et regarde-les toi-même pour corriger les défauts visuels (texte coupé, boutons trop petits, chevauchements).
(c) Conteneur : `Dockerfile` (nginx:1.27-alpine, copie du dossier statique, modèle de configuration dans /etc/nginx/templates/default.conf.template, écoute ${PORT}) ; `nginx.conf.template` : en-têtes X-Content-Type-Options nosniff, X-Frame-Options DENY, Referrer-Policy no-referrer, Permissions-Policy « camera=(), microphone=(), geolocation=() » ; ATTENTION : dans nginx un `add_header` placé dans un bloc `location` REMPLACE tous ceux du bloc parent, donc répète les en-têtes de sécurité dans CHAQUE location qui déclare un add_header ; `Cache-Control: no-store` pour index.html, sw.js et manifest.json ; cache long (1 an, immutable) pour vendor/ ; icons/ 1 jour ; type MIME correct pour .webmanifest/.json/.js. Si Docker est installé sur cet ordinateur : construis l'image, lance-la avec `-e PORT=8095`, et vérifie les en-têtes avec `curl -I` ; sinon dis-le dans le rapport.

# 9. Livrables et fin
- README.md (en français) : à quoi ça sert, comment lancer en local (`python3 -m http.server 8080` ou `npx serve`), comment l'installer sur le téléphone, première utilisation en 10 lignes, comment fonctionne la sauvegarde (CSV + PDF dans WhatsApp), limites (pas de synchronisation, pas de vérification par code), version exacte de jsPDF et son empreinte, comment lancer les tests, comment mettre en ligne (HTTPS obligatoire pour installer l'application et partager un fichier : hébergeur de fichiers statiques ou le conteneur).
- Un dépôt Git local (`git init`), commits clairs ; ne publie rien sur Internet.
- Termine par un rapport COURT en français : ce qui marche (avec la preuve : nom des tests et résultats), les captures regardées, la version de jsPDF, et ce que tu n'as PAS pu vérifier (le partage WhatsApp réel et l'installation sur un vrai téléphone).
- Ne demande jamais de mot de passe ni de clé ; n'en écris nulle part. Ne modifie rien hors du dossier du projet. Ne rien inventer : si une information manque, mets « [à compléter] » et signale-la.
```

## Après la construction
1. Mets le dossier sur un hébergement HTTPS (le téléphone n'installe l'application et ne partage un fichier qu'en HTTPS) : service de fichiers statiques ou conteneur nginx.
2. Ouvre l'adresse sur le téléphone, « Ajouter à l'écran d'accueil », remplis les Réglages une fois.
3. Fais relire le texte du contrat par un juriste avant de cocher « relu et validé ».
