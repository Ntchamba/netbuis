# T122 (partie backend) — Performances : requêtes, index, temps, flux SSE

Tout est **mesuré**, rien n'est déclaré. Base locale jetable (`netbuis_perf`, supprimée à la fin), PostgreSQL 16, 4 cœurs, `work_mem` 4 Mo, `max_connections` 100. Jeu de données : `seed_demo --count 5000` (5 000 commerces dont 3 600 actifs et visibles, 7 200 publications, 7 200 commentaires) **plus** une charge synthétique jetable ajoutée pour les listes qui n'ont pas de données fictives : 10 800 offres, 20 catalogues de produits (un par mot courant), 20 000 sessions d'appel, 20 000 journaux d'appel/WhatsApp, 20 000 lignes d'audit, 3 000 signalements, 100 agents. `seed_demo --flush` a bien supprimé les 5 000 commerces fictifs (`logs/T122-flush.txt`) ; les comptes qui portaient la charge synthétique sont volontairement conservés par la commande (règle « jamais un compte qui a d'autres données »).
Les temps sont ceux d'un client Django **en mémoire** (pile Django + SQL + sérialisation, sans réseau ni TLS), 30 appels après 1 échauffement, cache vidé à chaque appel (les limites de débit ne faussent rien). Sorties brutes : `logs/T122-*.txt`.

## 1. Pas de N+1 — test de nombre de requêtes constant

Fichier : `backend/apps/search/tests/test_perf_queries.py` (23 tests, index et ordre du fil compris). Principe : 1 élément → échauffement → mesure ; ajout jusqu'à 30 éléments → mesure ; **même nombre de requêtes exigé** et réponse qui contient réellement plus de lignes. Contrôle de la sensibilité du test : en retirant volontairement le `select_related` de la liste des comptes, le test échoue (`11 requêtes avec 3 lignes, 37 avec 20`).

| Route | Requêtes (1 → 30 éléments) | Test |
|---|---|---|
| `GET /api/search/?q=` (texte) | 11 → 11 | `test_recherche_nombre_de_requetes_constant[q=riz]` |
| `GET /api/search/` (q vide) | 5 → 5 | idem `[/api/search/]` |
| `POST /api/search/voice/` | 11 → 11 | `test_recherche_vocale_…` |
| `GET /api/search/suggestions/` | 3 → 3 | `test_suggestions_…` |
| `GET /api/map/cities/` | 7 → 7 | `test_carte_villes_…` |
| `GET /api/map/cities/<id>/areas/` | 6 → 6 | `test_carte_quartiers_…` |
| `GET /api/map/areas/<id>/businesses/` | 7 → 7 | `test_carte_commerces_d_un_quartier_…` |
| `GET /api/forum/posts/` (fil) | 4 → 4 | `test_fil_du_forum_nombre_de_requetes_constant` |
| `GET /api/forum/posts/?zone=` | 6 → 6 | `test_fil_du_forum_par_zone_…` |
| `GET /api/forum/mine/`, `…/posts/<id>/comments/` | 5 → 5 ; 4 → 4 | `test_mes_publications_et_commentaires_…` |
| `GET /api/forum/posts/<id>/` (détail + commentaires) | constant | `test_detail_d_une_publication_…` |
| `GET /api/trends/?zone=` | constant (plafond 10 + 10 lignes dépassé) | `test_tendances_…` |
| `GET /api/calls/history/` | 3 → 3 | `test_historique_d_appels_…` |
| `GET /api/business/<id>/` (fiche, 1 → 30 offres) | constant | `test_fiche_commerce_…` |
| `GET /api/admin/accounts/` (+ filtre `type`, `q`) | 7 → 7 | `test_admin_comptes_…` |
| `GET /api/admin/requests/` | 6 → 6 | `test_admin_demandes_…` |
| `GET /api/admin/calls/` (+ `state`) | 6 → 6 | `test_admin_appels_…` |
| `GET /api/admin/audit/` | 6 → 6 | `test_admin_audit_…` |
| `GET /api/admin/reports/` (signalements) | 10 → 10 | `test_admin_signalements_…` |
| `GET /api/admin/subscriptions/` | 6 → 6 | `test_admin_abonnements_…` |

**Résultat : aucun N+1 trouvé** (le code était déjà écrit avec `select_related`, agrégats et sous-requêtes) ; les tests le verrouillent désormais pour la liste complète. Routes sans liste à mesurer : `notifications` et `printing` (rien d'implémenté, V01…V10 reportés).
**La « carte » n'a pas de boîte englobante** : la carte du projet est hiérarchique (villes → quartiers → commerces d'un quartier), le GPS étant reporté (V05). Il n'y a donc pas de requête « boîte englobante » à indexer ; les trois routes de carte sont mesurées telles qu'elles existent.

## 2. Index — EXPLAIN (ANALYZE) avant / après

Requêtes lentes repérées par `EXPLAIN (ANALYZE, BUFFERS)` de **chaque** requête SQL des routes chaudes (`logs/T122-explain-avant.txt`, `logs/T122-explain-apres.txt`).

### Index ajoutés (2), par migration
| Index | Requête | Avant | Après | Preuve |
|---|---|---|---|---|
| `calls_session_recent_idx` sur `calls_callsession (created_at DESC, id DESC)` — migration `calls/0005_index_liste_recente` | liste admin des appels, 1re page (`ORDER BY created_at DESC, id DESC LIMIT 20`) | **84,3 ms** : `Seq Scan` des 20 000 sessions + tri | **0,3 ms** : `Index Scan using calls_session_recent_idx` | filtre `state=missed,declined` : 31,6 ms → 0,4 ms ; page 500 (décalage 10 000) : 80 → 47 ms |
| `accounts_user_recent_idx` sur `accounts_user (created_at DESC, id DESC)` — migration `accounts/0007_index_liste_recente` | liste admin des comptes, 1re page | **18,1 ms** : `Seq Scan` + tri | **0,1 ms** : `Index Scan using accounts_user_recent_idx` | les filtres `q`/`type` (ILIKE, jointures) gardent un balayage : 13–18 ms sur 5 000 comptes |

Chacun est testé : `test_index_des_listes_recentes_presents_et_utilisables` (définition lue dans `pg_indexes`, et le planificateur le choisit pour « les 20 plus récents »).

### Index examinés et **non** ajoutés
- `calls_calllog (profile_id, created_at)` pour la liste admin des abonnements (66 ms) : essayé, le plan **ne change pas** (`Seq Scan` du journal conservé, 57 → 47 ms = bruit). Cette liste est triée sur un agrégat (appels des 24 h) : son coût suit le nombre de commerces visibles, pas un index.
- Fil du forum : aucun index ne sert le tri « abonnés d'abord » (clé calculée) ; `forum_post_status_created (status, -created_at)` existant n'est **pas** utilisé par ce tri (il peut l'être ailleurs, non touché). Le gain est venu d'une réécriture (voir §3, correction F1).
- Recherche : les `Seq Scan` sur offres/commerces calculent `word_similarity()` sur chaque ligne ; l'index trigramme existant (T041b) n'intervient pas dans ce calcul. 14–38 ms par requête sur 5 000 commerces, pas de gain d'index disponible sans changer le classement.
- Audit (`created_at` déjà indexé), signalements (agrégat, 3,6 ms), historique d'appels (index `(caller, created_at)` déjà présents), carte (index `(zone, status)` déjà utilisé) : rien à ajouter.

## 3. Corrections

- **F1 — fil du forum** (`apps/forum/services/post_service.py`, objet `FeedWindow`). Le tri portait sur des lignes larges (auteur + zone + produit) et le nombre de commentaires était calculé pour toutes les lignes sautées par la pagination. Maintenant : tri sur les identifiants seuls, puis chargement complet de la page demandée. Contrat inchangé. EXPLAIN : page 1 **48,2 → 9,7 ms**, page 100 **223,4 → 8,8 ms**, filtre de zone 53,3 → 19,5 ms. Test de non-régression de l'ordre sur plusieurs pages : `test_fil_du_forum_pages_successives_sans_doublon_abonnes_d_abord` ; les tests existants du forum sont inchangés et verts.
- **F2 — flux SSE : deux connexions PostgreSQL par flux au lieu d'une** (voir §5) : `apps/calls/services/streams.py` (aide `_db`, `release_request_connection`) et deux vues de flux (`views/agent.py`, `views/sessions.py`, une ligne chacune). Tests : `apps/calls/tests/test_stream_connections.py` (5 tests ; chaque correction a un test qui échoue sans elle, par ex. `assert 7 == (1 + 3)` sans la fermeture après chaque appel).

## 4. Temps de réponse sur 5 000 commerces (médiane / p95 / max, ms, 30 requêtes)

`avant` = code initial ; `après` = code final (index + F1). Requêtes SQL = nombre par appel.

| Route | Req. | Avant méd. / p95 / max | **Après méd. / p95 / max** |
|---|---|---|---|
| Recherche « riz » (offres) | 15 | 119 / 141 / 209 | **110 / 143 / 165** |
| Recherche « [DÉMO] » (3 599 résultats, pire cas) | 13 | 165 / 261 / 292 | **144 / 210 / 222** |
| Recherche nom avec faute | 13 | 135 / 173 / 250 | **115 / 136 / 226** |
| Recherche vide (liste de la zone) | 7 | 38 / 46 / 167 | **37 / 51 / 121** |
| Recherche page 50 | 7 | 46 / 56 / 135 | **36 / 42 / 45** |
| Suggestions « ri » | 3 | 6 / 7 / 9 | **5 / 7 / 8** |
| Carte : villes | 7 | 35 / 43 / 44 | **30 / 35 / 37** |
| Carte : quartiers de Maroua | 6 | 49 / 54 / 56 | **39 / 47 / 52** |
| Carte : commerces d'un quartier | 7 | 26 / 30 / 173 | **23 / 27 / 129** |
| Forum : fil page 1 | 3 → 4 | 72 / 81 / 88 | **38 / 48 / 58** |
| Forum : fil page 100 | 3 → 4 | 184 / 271 / 286 | **43 / 50 / 52** |
| Forum : fil d'une zone | 5 → 6 | 66 / 81 / 93 | **55 / 62 / 68** |
| Forum : détail + commentaires | 4 | 28 / 34 / 51 | **27 / 33 / 33** |
| Tendances | 6 | 12 / 14 / 16 | **12 / 14 / 18** |
| Historique d'appels (200 + 200 lignes) | 3 | 49 / 67 / 151 | **54 / 65 / 115** |
| Fiche commerce | 6 | 11 / 12 / 13 | **11 / 12 / 14** |
| Admin : comptes page 1 | 7 | 30 / 34 / 35 | **15 / 16 / 17** |
| Admin : comptes (type + nom) | 7 | 35 / 39 / 45 | **42 / 50 / 53** |
| Admin : demandes (1 000 en attente) | 6 | 26 / 30 / 38 | **22 / 27 / 34** |
| Admin : appels page 1 | 6 | 74 / 95 / 97 | **17 / 21 / 25** |
| Admin : appels manqués | 6 | 47 / 54 / 63 | **16 / 20 / 21** |
| Admin : appels page 500 | 6 | 91 / 116 / 125 | **55 / 67 / 77** |
| Admin : audit page 1 / filtré | 6 | 14 / 18 / 22 ; 14 / 19 / 80 | **14 / 17 / 21 ; 13 / 16 / 17** |
| Admin : signalements | 8 | 23 / 28 / 33 | **22 / 28 / 33** |
| Admin : abonnements | 7 | 85 / 112 / 124 | **96 / 114 / 117** |

**Critère « recherche < 300 ms » : confirmé** — tous les cas ci-dessus sont sous 300 ms au maximum (pire : 226 ms), y compris le pire cas à 3 599 résultats ; cohérent avec `T041b.md` (139 / 198 / 275 ms mesurés alors).
**Réserve honnête** (`logs/T122-mesures-recherche-catalogue-pathologique.txt`) : si le catalogue contient **plusieurs produits dont le nom est presque identique au mot cherché** (essai : 5 produits « Riz test n » + « Riz »), la recherche élargit le terme à 6 variantes et chaque variante recalcule la similarité sur toutes les offres : **316 / 348 / 405 ms** pour « riz » (dépasse 300 ms). Avec un catalogue à noms distincts (cas du tableau), 110 ms. Non corrigé : cela toucherait le classement (voir « Ce qui reste »).
La mesure ne contient ni réseau mobile ni TLS : ajouter la latence du réseau de l'utilisateur.

## 5. Flux SSE — charge de 50 agents connectés (vrai serveur `uvicorn`, 1 processus, HTTP réel en boucle locale)

Script jetable : 50 agents ouvrent `GET /api/admin/calls/stream/` ; pendant 20 s on relève les connexions PostgreSQL (`pg_stat_activity`) et la mémoire (`/proc`) ; puis 5 appelants lancent un appel et on chronomètre la réception de la sonnerie par les 50 agents ; enfin les flux sont fermés (`logs/T122-sse-50.txt`).

| | Avant correction | **Après correction (F2)** |
|---|---|---|
| Connexions PostgreSQL pour **20** flux | **40** (2 par flux) | 20 |
| Connexions pour **50** flux | **≥ 100 : le serveur PostgreSQL est saturé** (`FATAL: sorry, too many clients already`, y compris pour `psql`) | **50** (1 par flux) |
| Connexions pour 100 flux | — | 92 acceptées sur 100 (limite 100 atteinte) |
| Mémoire du serveur (50 flux) | — | 61 → 99 Mo, soit **≈ 0,75 Mo par flux** |
| CPU du serveur (50 flux au repos) | — | ≈ 19 % d'un cœur (battement toutes les 5 s) ; 100 flux : ≈ 35 % |
| Sonnerie reçue par 50 agents sur 50 | — | 250 réceptions sur 250 ; **médiane 53 ms, p95 64 ms, max 65 ms** |
| Fermeture des flux | — | connexions revenues à 0 en 8 s, `open_streams` = 0 |

**Cause trouvée** : sous ASGI, Django n'envoie `request_finished` (qui ferme les connexions) qu'à la **fin** de la réponse, donc jamais pour un flux ; la connexion ouverte par l'authentification restait prise **en plus** de la connexion `LISTEN`. Corrigé en rendant cette connexion avant de renvoyer la réponse, et en ouvrant/fermant la connexion Django à chaque battement (toutes les 5 s) au lieu de la garder.

**Ce que cela implique pour `max_connections` (PostgreSQL, défaut 100)** :
- compter **1 connexion par agent connecté + 1 par appel en cours** (flux de l'appelant), **plus** au plus `min(32, cœurs + 4)` connexions éphémères pour les battements (≈ 8 sur 4 cœurs), **plus** les connexions normales de l'API (processus × fils), **plus** 3 réservées au super-utilisateur ;
- exemple : 50 agents + 5 appels + 8 éphémères + API (≈ 10) + 3 = **≈ 76** → le défaut de 100 suffit pour 50 agents mais n'a plus de marge au-delà de ≈ 80 flux. Au-delà : `max_connections` ≥ 200, ou une connexion `LISTEN` directe séparée (`CALLS_LISTEN_DATABASE_URL`) vers un PostgreSQL dédié, et ne pas faire passer ces connexions par un pool en mode transaction (déjà documenté) ;
- chaque processus `uvicorn` supplémentaire (`--workers N`) garde ses propres flux mais pas de connexion en plus ;
- le coût du battement par reconnexion (≈ 0,4 % d'un cœur par agent) est le prix de ne pas garder une seconde connexion par flux ; sur une base distante avec TLS, la reconnexion coûte plus cher (non mesurable ici).
Le document `docs/deployment/APPELS_ASGI.md` dit « quelques dizaines suffisent » et « une connexion LISTEN par flux » : à ajuster par l'orchestrateur avec les chiffres ci-dessus (je n'ai pas le droit d'écrire dans `docs/` hors ce fichier).

## 6. Commandes lancées (depuis `backend/`, sorties dans `logs/T122-*.txt`)
| Commande | Résultat |
|---|---|
| `ruff check .` | `All checks passed!` |
| `python manage.py makemigrations --check --dry-run` | `No changes detected` |
| `pytest -q` (suite complète) | 1 678 tests collectés, aucun échec (`logs/T122-pytest.txt` : que des points) |
| `python manage.py spectacular --validate --fail-on-warn` (fichier de sortie hors dépôt) | aucune alerte, `exit=0` |
| comparaison avec `docs/api/openapi.yaml` | **identique** (`diff -q` sans sortie) |
| `bash scripts/verifier_tache.sh` | `Contrôles automatiques : OK` |

Note : lancé dans l'ordre `pytest apps/forum tests`, `tests/test_security_private_files.py` échoue (dépendance d'ordre déjà présente avant mes changements : `MEDIA_URL` absent des routes si les URL sont chargées avant le réglage). Dans l'ordre normal du projet (`testpaths = apps tests`) il passe.

## 7. Ce qui reste
- Recherche : coût proportionnel au nombre de variantes du terme (catalogue à noms voisins : 316 ms). Piste : ne garder, parmi les variantes, que celles qui ne contiennent pas déjà le terme, ou lire un score préfiltré par l'opérateur `%>` + une colonne `normalized_name` sur `Offer` pour utiliser l'index trigramme. Touche le classement : à décider avant de le faire.
- Fil du forum : le tri « abonnés d'abord » reste un balayage de toutes les publications visibles (9,7 ms sur 7 200). À 10 fois plus de publications il faudra stocker l'état d'abonné sur la publication ou limiter le fil à une fenêtre de dates.
- Liste admin des abonnements (≈ 90 ms) et décalages profonds (page 500 des appels : 55 ms) : acceptables aujourd'hui.
- Non mesuré : mobile (b1), réseau/TLS, Jitsi réel, PostgreSQL distant.
- Les statistiques du tableau de bord (`/api/admin/stats/`, `analytics/*`) sont des agrégats et n'ont pas été passées au crible (hors liste demandée).
