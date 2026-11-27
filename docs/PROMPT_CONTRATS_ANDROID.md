# Prompt — « NetBuis Contrats » application ANDROID (à lancer dans le dossier NetBuis)

À coller dans Claude Code lancé dans le dossier `netbuis` de ton ordinateur (le dépôt avec tes modifications locales). Remplis d'abord la ligne « MON TÉLÉPHONE ». Le projet est créé dans le sous-dossier `contrats_android/` et ne touche à rien d'autre.

```
Tu es Claude Code, lancé dans le dossier de mon projet NetBuis (un dépôt Git qui existe déjà, avec mes modifications locales non publiées). Tu vas construire dans le sous-dossier `contrats_android/` une APPLICATION ANDROID INSTALLABLE (un fichier .apk) nommée « NetBuis Contrats », en français, complète et testée, pour mon VIEUX téléphone Android. Réponds-moi en français, court, sans jargon.

PRIORITÉ ET LIMITES — LIS CECI D'ABORD
- Ce prompt est prioritaire pour cette tâche. Le fichier CLAUDE.md de ce dépôt décrit une boucle d'« orchestrateur » avec sous-agents, PROGRESS.md et BACKLOG.md : NE LA SUIS PAS pour cette tâche (pas de sous-agents, pas de mise à jour de PROGRESS.md/BACKLOG.md). Respecte seulement ses règles absolues : ne jamais lire, afficher ni copier un fichier `.env`, ne jamais écrire de mot de passe ni de clé dans un fichier, un log ou un message, ne rien inventer (versions, API, données), pas de `rm -rf`.
- Ne modifie AUCUN fichier en dehors de `contrats_android/` (ni backend/, mobile/, dashboard/, docs/, .github/, ni le .gitignore de la racine). Mets un `.gitignore` dans `contrats_android/`.
- GIT : ne lance aucune commande qui modifie l'historique ou les autres fichiers (pas de commit global, `git add -A`, reset, checkout, stash, clean, push, pull). NE COMMITE PAS : à la fin, donne-moi la commande exacte pour ne commiter que ce dossier (`git add contrats_android && git commit -m "NetBuis Contrats (Android)"`), je la lancerai moi-même.
- Si `scripts/verifier_tache.sh` existe, lance-le à la fin ; il refuse les vrais numéros de téléphone camerounais en dur : dans le code, les tests et le README, n'utilise que des numéros FICTIFS de la plage 6000000xx (ex. 600000001, +237600000001, 237600000001). Corrige ce qu'il signale dans `contrats_android/`.
- Tu travailles seul : fais tout (installation des outils manquants dans mon dossier personnel, code, tests, construction de l'APK, documentation) sans me demander de confirmation, sauf si tu es bloqué ou s'il faut une commande `sudo` (donne-moi alors la commande exacte).

MON TÉLÉPHONE : marque et modèle : [à compléter] ; version d'Android : [à compléter] (Paramètres > À propos du téléphone > Version d'Android). Si c'est écrit « [à compléter] », choisis le niveau d'API minimal le plus bas que permette la version de Flutter installée et indique-le dans le rapport.

# 1. Le besoin
Je m'appelle Jeff. Je vends à des commerçants du Grand Marché de Maroua (Cameroun) des abonnements pour qu'ils apparaissent dans l'application NetBuis (recherche de commerces locaux). Je dois leur faire signer un contrat d'adhésion sur mon téléphone, souvent sans Internet. Il n'y a PAS d'opérateur de SMS : aucune vérification par code. L'application doit :
- proposer un modèle de contrat par défaut (texte fourni plus bas) ;
- recueillir les informations du commerçant et SA SIGNATURE au doigt sur l'écran ;
- fabriquer un PDF numéroté ;
- l'envoyer sur MON WhatsApp via le menu « Partager » d'Android (je le transmets ensuite moi-même au commerçant) ;
- garder un registre sur le téléphone, avec export CSV.
Tout est AUTONOME : aucun serveur, aucun compte, aucune connexion Internet requise, aucun SMS, aucune publicité, aucune statistique. Les données restent sur le téléphone.

# 2. Technique (imposée)
- Crée le projet par `flutter create --org cm.netbuis --project-name netbuis_contrats --platforms=android contrats_android` (Flutter/Dart, Android seulement). Application native : elle ne doit PAS dépendre du navigateur ou de WebView du téléphone (vieux téléphones).
- Identifiant d'application `cm.netbuis.contrats`, nom affiché « NetBuis Contrats ». Mode portrait verrouillé.
- Compatibilité vieux téléphone : `minSdk` le plus bas possible (vérifie ce que la version de Flutter installée autorise, ne l'invente pas) ; peu de mémoire (la signature est réduite à ~600 px de large) ; `compute()`/isolate pour les calculs lourds (mot de passe, PDF) avec indicateur de progression ; APK universel (32 bits armeabi-v7a ET 64 bits) ; vise moins de 30 Mo, indique la taille.
- Dépendances (Dart) autorisées, à ajouter avec `flutter pub add` (ne choisis JAMAIS une version à la main ni de mémoire : prends celle que pub.dev donne et note-la dans le README) : `pdf`, `share_plus`, `path_provider`, `shared_preferences`, `crypto`, `url_launcher`, `intl`. Dev : `flutter_lints`, `flutter_launcher_icons`. Rien d'autre sans raison forte, chaque paquet est justifié dans le README. Aucun Firebase, aucun service Google obligatoire.
- Stockage : un fichier JSON par contrat dans le dossier privé de l'application (`path_provider`), plus index et compteurs dans `shared_preferences` ; PDF dans le même dossier privé. Dis honnêtement dans le README que ces données ne sont pas chiffrées (elles sont dans le dossier privé protégé par Android) et que le mot de passe verrouille l'accès à l'application.
- Mot de passe : PBKDF2-HMAC-SHA256 (implémenté avec `crypto`, en isolate), sel aléatoire de 16 octets, au moins 100 000 itérations (mesure ou simule le temps sur un téléphone lent ; ne dépasse pas ~2 s ; documente le nombre), jamais en clair ; seul le sel et le résultat sont stockés.
- Signature : CustomPainter + gestes, exportée en PNG (PictureRecorder → Image → PNG).
- Polices : le PDF a besoin d'une police TrueType pour les accents. Embarque Roboto (Regular et Bold, Apache 2.0) ou Noto Sans (OFL) dans les assets avec la licence : cherche-la dans le SDK Flutter (par exemple dans bin/cache/artifacts/material_fonts/) ou dans le dépôt officiel de la police ; note la source dans le README.
- Identité visuelle (thème Material 3 clair seulement) : orange d'accent #F2942E, texte sur orange #1A1200, fond #F7F7F8, cartes #FFFFFF, bordures #E3E3E7, texte #18181B, texte secondaire #6B6B70, texte orange lisible #A85A00, erreur #C93E28. Coins arrondis 12 px. Boutons ≥ 48 dp, texte courant ≥ 16 sp, respect de la taille de police du téléphone.
- Icône : `assets/icon/icon.svg` avec exactement ce SVG ; rends-le en PNG 1024x1024 (rsvg-convert, Inkscape, ImageMagick ou Chromium/Playwright selon ce qui est installé) puis génère les icônes Android avec `flutter_launcher_icons` (icône adaptative : premier plan = la loupe, fond orange #F2942E). SVG :
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <title>NetBuis</title>
  <rect width="512" height="512" rx="112" fill="#F2942E"/>
  <circle cx="232" cy="232" r="96" fill="none" stroke="#1A1200" stroke-width="40"/>
  <line x1="302" y1="302" x2="376" y2="376" stroke="#1A1200" stroke-width="44" stroke-linecap="round"/>
</svg>

# 3. Outils sur mon ordinateur (installe ce qui manque, sans rien casser)
Vérifie ce qui est installé : `flutter --version`, `java -version`, `adb version`, Android SDK (ANDROID_HOME ou ~/Android/Sdk). S'il manque : Flutter (archive officielle, dans ~/development/flutter), un JDK 17, les outils en ligne de commande du SDK Android, platform-tools, la plateforme et les build-tools exigés par le projet ; accepte les licences (`flutter doctor --android-licenses`). Lance `flutter doctor` et règle ce qui empêche de construire un APK (pas besoin d'Android Studio ni de Chrome). Si une commande exige `sudo`, donne-la-moi. Mon dépôt a peut-être déjà Flutter configuré (mobile/) : réutilise le même SDK si c'est le cas.

# 4. Les écrans (assistant, gros boutons, utilisable d'une main, français)
Navigation par une barre en bas : « Nouveau contrat », « Registre », « Réglages ».

## 4.1 Premier lancement et verrouillage
- Premier lancement : choisir un mot de passe de l'application (6 caractères minimum, confirmation).
- Ensuite le mot de passe est demandé à chaque ouverture et après 5 minutes d'inactivité ou si l'application reste plus de 5 minutes en arrière-plan. Après 5 essais ratés : attente croissante (30 s, 1 min, 2 min, 5 min…) mémorisée même si l'application est fermée.
- Bandeau discret (fermable) : « Les contrats sont enregistrés seulement sur ce téléphone. Si vous désinstallez l'application, effacez ses données ou perdez le téléphone, le registre est perdu. Exportez le CSV de temps en temps et gardez les PDF envoyés sur WhatsApp. »
- Mot de passe oublié : « Effacer toutes les données » (confirmation en deux étapes) : c'est la seule voie, dis-le clairement.
- Bloque les captures d'écran (FLAG_SECURE) car l'application contient des données personnelles ; un réglage permet de l'autoriser.

## 4.2 Réglages (à remplir une fois)
Champs, avec leur valeur par défaut :
- NetBuis : nom, forme juridique, n° d'immatriculation / RCCM, adresse, représentant (tous vides).
- Agent : nom (vide), numéro d'agent (vide), SIGNATURE de l'agent (zone de dessin au doigt, enregistrée, bouton « Refaire »), réutilisée sur chaque contrat.
- « Mon numéro WhatsApp » : chiffres avec indicatif sans + (ex. 237600000001) ; validation : 11 à 15 chiffres.
- Formules (liste modifiable : ajouter, modifier, supprimer, réordonner) : libellé, prix en FCFA (entier, vide autorisé), périodicité (mensuelle / à l'acte / autre texte), texte « ce que comprend la formule ». Par défaut : « Formule A — Abonnement mensuel » (prix vide, mensuelle) et « Formule B — Paiement à la clientèle acquise » (prix vide, à l'acte).
- Définition de « client acquis » (texte libre, vide par défaut).
- Autres variables du contrat (§5) : montant et devise, modes de paiement acceptés, échéance, retard de paiement, préavis de changement de prix (jours), durée et renouvellement, préavis de résiliation (jours), remboursement, délai de mise en ligne (jours), moyens et horaires d'assistance, durée de conservation de la pièce d'identité, contact pour les données personnelles, tribunal compétent (défaut : « Maroua », à confirmer), délai de contestation du relevé (jours).
- Version du modèle (défaut « v0.1 »). Case « Le modèle a été relu et validé par un juriste » (décochée).
Règles : toute variable vide apparaît « [à compléter] » dans le contrat. Tant qu'une variable obligatoire est vide, un bandeau orange « Modèle incomplet : … » s'affiche sur les écrans Nouveau contrat et Lecture, et le PDF porte la mention BROUILLON (§6). On peut quand même générer un contrat (brouillon) : ne bloque pas.

## 4.3 Nouveau contrat — assistant en 5 étapes (« Étape n/5 »)
1. Commerçant : nom et prénom OU raison sociale, activité, adresse et repère (quartier, marché, n° de boutique), téléphone du compte, n° de la pièce d'identité (tous obligatoires), qualité du signataire (titulaire / représentant, défaut titulaire). Téléphone camerounais : 9 chiffres commençant par 6, avec ou sans +237/237 ; normalisation en « +2376XXXXXXXX » ; erreurs claires en français sous le champ. Brouillon enregistré à chaque changement ; reprise proposée à l'ouverture.
2. Formule : choix d'UNE formule ; prix pré-rempli et modifiable pour ce contrat ; date de début (défaut aujourd'hui).
3. Lecture : le contrat complet (§5, valeurs substituées) défile à l'écran ; case obligatoire « J'ai lu et j'accepte ce contrat » (bloque Continuer sinon) ; les « [à compléter] » sont surlignés.
4. Signature : grande zone (fond blanc, bordure), au doigt ; bouton « Effacer » ; signature obligatoire (refuse une zone vide ou quasi vide) ; champ « Nom du signataire » (pré-rempli, modifiable) ; date et heure automatiques (Africa/Douala, UTC+1).
5. Générer et envoyer : crée le contrat, attribue NB-AAAA-NNNN (année + compteur annuel sur 4 chiffres, 0001 en début d'année, sans trou ni doublon même après un plantage), génère le PDF (§6) et affiche le résumé, l'empreinte SHA-256 du PDF (bouton Copier) et les boutons :
   - « Envoyer sur WhatsApp » (principal) : menu « Partager » d'Android avec le PDF (`share_plus`), message « Contrat NB-AAAA-NNNN — <nom du commerçant> — <formule> » ; je choisis WhatsApp puis ma propre conversation. Repli si le partage échoue : enregistrer le PDF dans Téléchargements et ouvrir `https://wa.me/<mon numéro WhatsApp>?text=<message encodé>` (`url_launcher`). Si mon numéro WhatsApp n'est pas renseigné, le demander avant. « Envoyé : oui » seulement si le partage a abouti ou si le lien a été ouvert (une annulation ne compte pas).
   - « Enregistrer le PDF dans Téléchargements », « Partager encore », « Nouveau contrat ».

## 4.4 Registre
Liste des contrats signés, du plus récent au plus ancien : n°, commerçant, téléphone, formule, prix, date, pastille « envoyé / non envoyé », « BROUILLON » le cas échéant. Recherche instantanée (nom, téléphone, n°, quartier). Détail d'un contrat + Enregistrer, Partager encore, (re)marquer comme envoyé. Export CSV (via le menu Partager) : colonnes n°, nom, activité, quartier_marche_boutique, telephone, piece_identite, formule, prix_fcfa, date_signature, version_modele, brouillon, envoye, empreinte_pdf ; séparateur point-virgule, UTF-8 avec BOM, échappement des guillemets/retours à la ligne/points-virgules, protection contre l'injection de formules (apostrophe devant = + - @). Suppression d'un contrat : confirmation ET ressaisie du mot de passe.

# 5. Le texte du contrat (À REPRENDRE TEL QUEL — ne réécris pas le juridique)
Voici le modèle, en Markdown. Les passages entre crochets [ … ] sont des VARIABLES : remplace-les par les valeurs des réglages et du formulaire (nom NetBuis, forme juridique, RCCM, adresse, représentant, nom du commerçant, activité, adresse/repère, téléphone, pièce d'identité, formule choisie + prix, définition de client acquis, montants, échéances, durées, préavis, assistance, durée de conservation, contact, tribunal…) et affiche « [à compléter] » si la valeur est vide. Les cases « ☐ » de la section 2 : n'affiche QUE la formule choisie, cochée. Les cases de fin deviennent des lignes avec « [ ] » à cocher à la main sur la version papier ; dans l'application, remplace « Téléphone du compte vérifié (code reçu) » par « Numéro de téléphone communiqué par le commerçant » (il n'y a pas de code). Le texte :

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

Structure : une constante Dart `defaultTemplate` découpée en articles (titre + paragraphes) avec des jetons `{{nom_variable}}` ; une fonction pure `renderContract(template, valeurs)` qui renvoie les blocs et les noms des variables restées vides. Le texte n'est modifiable que par les réglages (variables), pas depuis l'écran du contrat.

# 6. Le PDF
- A4 portrait, marges 18 mm, police TrueType embarquée (§2) ; accents français OK ; remplace les caractères non gérés (« ☐ » → « [ ] »).
- En-tête : « NetBuis — Contrat d'adhésion commerçant », numéro NB-AAAA-NNNN, date et heure de signature (Africa/Douala), version du modèle.
- Corps : le contrat complet (articles titrés en gras), pas de titre seul en bas de page, formule et prix dans un encadré.
- Signatures : deux encadrés côte à côte : « Le commerçant » (nom, qualité, image de la signature, date/heure) et « NetBuis, par son agent » (nom, n° d'agent, image de la signature de l'agent). PDF léger (< 300 Ko si possible).
- Pied de page de CHAQUE page : « NB-AAAA-NNNN — page n/N — modèle v0.1 — empreinte du contenu : <16 premiers caractères du SHA-256 du JSON du contrat> » et, selon le cas : « BROUILLON — modèle incomplet » et/ou « BROUILLON — non relu par un juriste » ; ces mentions apparaissent aussi en filigrane diagonal gris clair sur chaque page.
- Empreinte du PDF : SHA-256 des octets du PDF final (à l'écran, dans le registre et le CSV, pas dans le PDF).
- Nom du fichier : NB-AAAA-NNNN_<nom-du-commerçant-sans-accents-ni-espaces>.pdf.

# 7. Construire et installer l'APK
- `flutter build apk --release` (APK universel). Signature : la clé de débogage automatique de Flutter suffit pour mon usage personnel (dis dans le README que les mises à jour futures doivent être signées avec LA MÊME clé : sauvegarder ~/.android/debug.keystore). Aucun mot de passe de signature dans le projet.
- Copie l'APK dans `contrats_android/NetBuis-Contrats.apk` (non versionné) et donne-moi son chemin complet, sa taille et le niveau d'API minimal réel (`aapt2 dump badging` ou `apkanalyzer` du SDK).
- Si un émulateur ou un téléphone en USB (`adb devices`) est disponible, installe l'APK et fais le parcours complet ; pour un téléphone réel, demande-moi AVANT d'installer quoi que ce soit dessus. Sinon dis-le dans le rapport : ne prétends jamais avoir testé sur un téléphone si ce n'est pas le cas.
- README (français) dans `contrats_android/` : installer l'APK (câble USB, Google Drive ou WhatsApp ; autoriser « Installer des applications inconnues » pour l'application qui ouvre le fichier ; si Play Protect avertit : « Installer quand même »), première utilisation en 10 lignes, sauvegarde (CSV + PDF dans WhatsApp), limites, versions exactes des paquets, niveau d'Android minimal, comment reconstruire.

# 8. Tests (obligatoires, tous doivent passer)
- `flutter analyze` sans aucun problème.
- Unitaires (`flutter test`) : numérotation (NB-AAAA-NNNN, passage d'année, pas de doublon) ; rendu du modèle (variables remplacées, « [à compléter] », variables vides listées, une seule formule affichée) ; téléphone camerounais (valides : 600000001, 6 00 00 00 01, +237600000001, 237600000001 ; invalides : 500000001, 60000000, 6000000012, lettres) ; CSV (BOM, point-virgule, guillemets, retours à la ligne, injection de formule) ; SHA-256 (« abc » → ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad) ; PBKDF2 (même mot de passe vérifie, un autre non) et temps de calcul mesuré.
- Widgets : parcours complet avec de faux services (stockage en mémoire, partage simulé) : validation des champs, case de lecture obligatoire, signature obligatoire, verrouillage et mauvais mot de passe, registre et recherche ; génération d'un PDF réel (commence par %PDF, texte contenant le nom du commerçant et le numéro du contrat via `pdftotext` s'il est installé, sinon contrôle des octets) ; aucun `print`/`debugPrint` de données personnelles (test de recherche dans le code).
- Si possible, un test d'intégration (`integration_test`) sur émulateur/téléphone.

# 9. Fin de travail
- Rapport FINAL court en français : ce qui marche (preuves : tests et résultats), chemin et taille de l'APK, niveau d'Android minimal, versions des paquets, ce que tu n'as PAS pu vérifier (partage WhatsApp réel, installation sur mon vrai téléphone), la commande git pour commiter uniquement `contrats_android/`, et ce que je dois faire (copier l'APK sur le téléphone, remplir les Réglages, faire relire le contrat par un juriste).
- Ne demande jamais de mot de passe ni de clé ; n'en écris nulle part. Ne rien inventer : si une information manque, mets « [à compléter] » et signale-la.
```
