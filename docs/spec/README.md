# Règles métier condensées

Ces fichiers sont des **résumés fidèles** des documents du Projet Claude de Jeff (`modele-donnees-netbuis.md` v18, `dashboard-admin-netbuis.md` v7, `accessibilite-analphabetisme-netbuis.md` v3, `decision-finale-appels.md` v2.1). Ils servent à donner aux agents l'essentiel sans bruit.

- En cas de doute ou de contradiction avec un autre fichier du dépôt : `docs/DECISIONS_JEFF.md` d'abord, puis ces fichiers, puis `docs/design/maquettes/`, puis `docs/TASKS_PAR_AGENT.md`.
- Si une règle manque ou paraît ambiguë, **l'agent ne l'invente pas** : il le signale à l'orchestrateur, qui applique la valeur par défaut de `DECISIONS_JEFF.md` ou consigne le point.

## Ce qui vient du Projet et ce qui est un ajout du dépôt
Sont des **ajouts ou valeurs d'essai** décidés pour le dépôt (voir `DECISIONS_JEFF.md`) et non des décisions de Jeff : les limites anti-aspiration (5/min, 50/jour), les 5 publications par jour contre le spam, le seuil technique de 10 appels, la langue du compte, le canal WhatsApp dans `CallLog`, les cibles de 48 dp, le contraste 4,5:1 et le test à 360 px, la synthèse vocale réelle (D-21). Restent **ouverts dans le Projet** : mémoriser ou non la ligne Orange/MTN (D-22 : redemander), badge « Abonné » public (D-23), plafond de 5 publications, valeur du seuil d'appels, plusieurs catégories de service pour un prestataire, statut d'abonnement `impayé` (omis tant que les paiements sont reportés), risque de fraude Mobile Money (garder le signalement visible).
