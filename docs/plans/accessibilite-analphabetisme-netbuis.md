# Accessibilité pour les utilisateurs analphabètes ou non-lecteurs

Date : 2026-10-04 (v3 — recherche académique + étude concurrentielle, audio ajouté, défilement horizontal supprimé plutôt que simplement signalé)

## Le besoin, tel qu'exprimé par le porteur de projet

« L'application doit être adaptée au non-lecteur. Tout doit être fait de manière intuitive, pour influencer beaucoup plus sur une population analphabète. L'ensemble des vues et des pages — sauf le dashboard d'administration — doit être adapté pour des non-lecteurs. »

**Portée** : toutes les vues de l'application mobile (côté utilisateur final et côté compte business), **à l'exclusion explicite du dashboard d'administration web**, qui reste un outil interne pour l'équipe NetBuis et peut rester un outil "classique" basé sur du texte.

C'est une exigence transversale, pas un écran de plus : elle doit se refléter dans *toutes* les vues déjà conçues, et guider la conception de toutes les vues à venir. Ce document fixe les principes de conception à appliquer partout, et sert de référence à cocher au fur et à mesure que les écrans existants sont retouchés.

## Pourquoi c'est important pour NetBuis en particulier

Le marché visé (commerçants locaux, particuliers vendeurs, clients de quartier à Maroua et au-delà) inclut une proportion significative de personnes peu ou pas à l'aise avec la lecture, en français comme dans une autre langue. Une application qui suppose la lecture de phrases longues, de formulaires textuels ou de menus uniquement textuels exclurait une partie importante de ce public — à l'inverse du but du projet (faire grandir le réseau de comptes business et faciliter la mise en relation).

## Ce que dit la recherche (v3 — nouveau)

Une recherche a été faite sur les travaux académiques consacrés à la conception d'interfaces pour utilisateurs analphabètes ou peu lettrés, et sur l'app concurrente camerounaise la plus proche de NetBuis. Deux sources principales, bien documentées :

**Étude Microsoft Research (Medhi et al., *Designing Mobile Interfaces for Novice and Low-Literacy Users*)** — une étude empirique directement sur ce public, avec des résultats chiffrés marquants :
- **Les interfaces purement textuelles échouent totalement** : 0 utilisateur sur 20 n'a pu naviguer une interface textuelle dans leurs tests.
- **Les barres de défilement posent un vrai problème** : 48 utilisateurs sur 90 s'y sont perdus. C'est la confirmation directe de ce que le porteur de projet avait repéré sur la rangée de puces de filtre de `Main.dc.html` — pas seulement un problème de style, un problème d'usage documenté.
- **La navigation hiérarchique (menus à plusieurs niveaux) a mis en échec 100% des utilisateurs non familiers du téléphone.**
- **Les graphiques simples et les annotations audio/vocales fonctionnent bien**, davantage que les photos ou icônes seules dans certains cas — le son n'est pas un "plus", c'est souvent ce qui fait la différence.
- **La saisie numérique (chiffres) est beaucoup plus fiable que la saisie de texte libre.**
- **Un relais humain (opérateur en direct) atteint 99,5% de réussite, contre 4-5% d'erreur avec un système purement textuel** — un écart énorme, qui remet en perspective tout ce que la conception d'écran peut faire seule.

**Framework SARAL** (*Smartphone Applications embRAcing Low-literate users*, 13 directives actionnables en 5 thèmes — interaction multimodale, littératie numérique, design visuel minimaliste, architecture de contenu simplifiée, aide accessible et relais humain) — vient renforcer et structurer les mêmes constats.

**Étude concurrentielle** : E-Shelle (« la super-app et marketplace de référence au Cameroun », 30+ services, mise en relation géolocalisée, boutons WhatsApp/appel/devis sur chaque fiche commerçant) **ne mentionne aucune adaptation pour les utilisateurs peu lettrés** — c'est une app numérique classique. C'est une occasion réelle de différenciation pour NetBuis sur ce marché, pas seulement une contrainte à subir.

Ces résultats ont conduit à **réviser à la hausse** deux décisions prises dans les versions précédentes de ce document (voir "Ce qui a changé en v3" plus bas).

## Principes de conception retenus (à appliquer à toute nouvelle vue, et à rétro-appliquer aux vues existantes)

1. **Icône + mot court, jamais de texte seul pour une action ou une catégorie.** Chaque secteur, catégorie, filtre, type de compte ou action doit porter un pictogramme/emoji reconnaissable en plus (ou à la place) du texte. Déjà en place pour les grilles de secteurs/catégories, la barre de navigation du bas, les puces de filtre de l'accueil, et le sélecteur de type de compte (`CreationBusiness-Infos.dc.html`).

2. **Recherche vocale en plus de la recherche écrite.** Implémenté sur `Main.dc.html` (bouton micro séparé, démo d'écoute).

3. **Appel en un seul geste, jamais de numéro à lire ou composer.** Déjà acquis (voir `decision-finale-appels.md`).

4. **Préférer les choix visuels (grilles d'icônes, boutons) aux champs de texte libre**, partout où une liste prédéfinie est possible. Déjà largement le cas dans le parcours de création de compte business. Les champs de texte libre restants sont à traiter au cas par cas — voir "Reste à traiter".

5. **Confirmation et statut par couleur/icône plutôt que par texte seul.** Déjà en place à plusieurs endroits.

6. **Phrases courtes, vocabulaire simple, pas de jargon.** Confirmé par la recherche (G5 du framework SARAL) — à revérifier écran par écran.

7. **Navigation par icône + mot court.** Déjà le cas pour la barre de navigation du bas.

8. **Photos plutôt que texte quand c'est possible.**

9. **Étapes visibles et progression claire**, mais **structure volontairement linéaire, pas hiérarchique.** *(Précisé en v3)* La recherche montre que les menus à plusieurs niveaux font échouer ce public à 100%. Le parcours NetBuis actuel (une suite d'écrans "Étape X sur Y", le choix de type de compte menant à un sous-parcours dédié mais toujours linéaire, jamais de menu imbriqué) est donc la bonne approche — à ne pas complexifier en ajoutant des sous-menus.

10. **Une option d'écoute à voix haute pour les textes plus longs n'est pas un "plus" optionnel — la recherche montre que l'audio est souvent ce qui fait réellement la différence pour ce public.** *(Révisé en v3, voir ci-dessous — implémenté en v3, et non plus reporté comme en v1/v2.)*

11. **Éviter le défilement horizontal plutôt que simplement le signaler.** *(Révisé en v3)* La v2 avait ajouté un dégradé de fondu pour signaler qu'une rangée de puces défilait. La recherche montre que le défilement lui-même est une source d'échec documentée (48/90 utilisateurs perdus avec des barres de défilement dans l'étude Microsoft) — pas seulement un problème de lisibilité du signal. **Décision retenue : préférer un retour à la ligne (grille qui s'enroule) à un défilement horizontal, chaque fois que le nombre d'éléments le permet.** Le défilement vertical normal d'un écran reste évidemment nécessaire et n'est pas concerné.

12. **(nouveau, v3) Exploiter la littératie numérique plutôt que la littératie textuelle.** Les chiffres (prix, compteurs, numéros d'étape) sont compris par une large majorité de ce public, même sans savoir lire — contrairement au texte. Déjà bien exploité (barres "Étape X sur Y", compteur "X/3 inclus sans abonnement", prix affichés en chiffres) — à maintenir comme réflexe par défaut plutôt que des formulations textuelles quand un nombre suffit.

13. **(nouveau, v3) Un relais humain visible et facilement accessible, pas seulement un filet de sécurité en coulisses.** L'écart de réussite mesuré dans la recherche entre un relais humain (99,5%) et une interface texte seule (4-5%) est trop important pour que l'assistance humaine reste un recours discret. Le bloc "Nous contacter" de `Aide.dc.html` (WhatsApp, appel au support, e-mail) et le parcours de création de compte "sans smartphone" par un agent (déjà documenté dans `modele-donnees-netbuis.md`) vont dans le bon sens — à garder bien visibles, voire à renforcer (ex. un raccourci plus visible vers l'aide humaine depuis l'écran d'accueil, pas seulement depuis le Profil). **Point ouvert**, voir "Reste à traiter".

## Ce qui a changé en v3 (révision de décisions précédentes à la lumière de la recherche)

- **L'écoute à voix haute (principe 10)**, reportée en v1/v2 comme "piste pour une prochaine itération", a été **implémentée directement en v3** sur deux écrans : un bouton "🔊 Écouter" sur l'encart explicatif du type de compte (`CreationBusiness-Infos.dc.html`), et un bouton "🔊" sur chaque question de la FAQ (`Aide.dc.html`) — démonstration visuelle de l'écoute (pas une vraie synthèse vocale, voir "Reste à traiter"), mais le mécanisme d'interaction est posé.
- **Le défilement horizontal des puces de filtre (`Main.dc.html`, principe 11)**, qui avait un dégradé de fondu depuis la v2, **ne défile plus du tout** : les 4 puces s'enroulent maintenant sur deux lignes dans l'écran, sans aucun geste de défilement nécessaire.

## Ce qui est déjà conforme (sans retouche nécessaire)

- La barre de navigation du bas (icône + mot) sur tous les écrans qui la possèdent.
- Les grilles de secteurs, catégories de service et types de structure (icône + mot court par choix).
- Le bouton d'appel (icône téléphone + mot, jamais de numéro affiché).
- Les barres de progression par étape, et la structure linéaire (pas de menus imbriqués) du parcours de création de compte.
- Les badges de statut (✓ vérifié, 🔒 plafond atteint) et l'usage des chiffres pour les compteurs/prix.
- Le sélecteur de type de compte business (icône + mot pour chacun des 5 types).
- Le bloc "Nous contacter" de `Aide.dc.html` (relais humain visible).

## Ce qui a été retouché

**v1** : `Main.dc.html` — bouton de recherche vocale + icônes sur les puces de filtre.

**v2** : `CreationBusiness-Infos.dc.html` — icônes sur les 5 boutons de type de compte ; `Main.dc.html` — correction du débordement visuel (dégradé de fondu).

**v3** : `Main.dc.html` — suppression complète du défilement horizontal des puces de filtre (grille qui s'enroule) ; `CreationBusiness-Infos.dc.html` — bouton d'écoute audio sur l'encart explicatif du type de compte ; `Aide.dc.html` — bouton d'écoute audio sur chaque question de la FAQ.

## Ce qui reste à traiter (à prioriser avec le porteur de projet)

- **Une vraie synthèse vocale.** Les boutons "🔊 Écouter" ajoutés en v3 ne sont qu'une démonstration visuelle (ils affichent "Lecture audio en cours..." sans lire réellement le texte) — la recherche montre que c'est important à construire pour de vrai, pas seulement comme mockup. **Point ouvert** : à planifier pour une v2 technique (choix d'un moteur TTS adapté au français et, si possible, aux langues locales).
- **Renforcer la visibilité du relais humain (principe 13)** : faut-il un raccourci "parler à quelqu'un" plus visible depuis l'écran d'accueil, pas seulement depuis Profil → Aide ? **Point ouvert.**
- **Les champs de texte libre restants** (description, horaires, numéro d'agrément, RCCM, "Autre" en texte libre) : à traiter via dictée vocale généralisée ou délégation à un agent — **point ouvert**, voir aussi le principe 4 et les constats de la recherche sur la fiabilité de la saisie numérique vs texte.
- **Le Forum** (publications/commentaires textuels) — **point ouvert**, non traité.
- **Les écrans d'authentification** (code OTP) : à vérifier que la saisie reste strictement numérique.
- **Toute autre rangée défilante horizontalement déjà existante dans la maquette** — à auditer et convertir en grille qui s'enroule (principe 11, révisé en v3) chaque fois que c'est possible.
- **Les écrans non encore audités** : `Carte.dc.html`, `Quartier.dc.html`, `Historique.dc.html`, `MesPublications.dc.html`, `Profil.dc.html`, `CreationBusiness-Secteur.dc.html`, `CreationBusiness-Entreprise-Forme.dc.html`, `CreationBusiness-Prestataire-Categorie.dc.html`, `CreationBusiness-Structure-Type.dc.html`, `CreationBusiness-Structure-Details.dc.html`, `CreationBusiness-Details.dc.html`, `CreationBusiness-Recap.dc.html`, `Onboarding.dc.html`, `Splash.dc.html`.

## Non concerné

Le dashboard d'administration reste hors périmètre, à la demande explicite du porteur de projet.

## Prochaines étapes proposées

1. Confirmer le rythme de retouche des écrans restants (un par session, ou une passe dédiée complète).
2. Décider du sort des champs de texte libre et de la visibilité du relais humain (points ouverts ci-dessus).
3. Décider si une vraie synthèse vocale est à planifier pour une version technique ultérieure.
4. Continuer l'audit écran par écran en appliquant les treize principes ci-dessus, en particulier la conversion de tout défilement horizontal restant en grille qui s'enroule.

## Sources consultées

- [Medhi, Patra, Toyama — Designing Mobile Interfaces for Novice and Low-Literacy Users (Microsoft Research, ToCHI)](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/ToCHI2711_Medhi.pdf)
- [Actionable UI Design Guidelines for Smartphone Applications Embracing Low-literate Users — framework SARAL (CSCW 2021)](https://anupriyatuli.github.io/publications/2021_CSCW.pdf)
- [Designing User Interfaces for Illiterate and Semi-Literate Users: A Systematic Review and Future Research Agenda](https://journals.sagepub.com/doi/10.1177/21582440231172741)
- [E-Shelle — Super-App & Marketplace de référence au Cameroun](https://e-shelle.com/)
- [WivRoo — Marketplace & recherche de produits au Cameroun](https://client.wivroo.com/)
