# Quartiers de Maroua — liste PROVISOIRE (recherche du 2026-11-26)

**État : incomplet et non vérifié.** Les pages sources n'ont pas pu être ouvertes depuis la session de travail (les sites sont bloqués par le réseau) : cette liste vient **uniquement des extraits** donnés par les moteurs de recherche. Une source indique qu'en 1995 la ville comptait **une centaine de quartiers** ; il en manque donc beaucoup. Rien n'est encore chargé dans l'application (`backend/apps/geo/data/zones.csv` contient seulement Hardé, Dougoï, Domayo, Djarengol). Orthographes et rattachements aux communes **à confirmer** (mairies de Maroua 1er, 2e, 3e, ou plan officiel).

## Déjà dans l'application
Hardé, Dougoï, Domayo, Djarengol.

## Noms trouvés, par commune d'arrondissement
| Commune | Quartiers cités | Source |
|---|---|---|
| **Maroua 1er** | Ziling, Makabaye, Ouro-Tchédé, Pallar 1, Pallar II, Djarengol Kaigama, Pidéré, Baouliwol, Messinguiléo II, Tchoffa Bani, Hardé, Domayo (chef-lieu de la commune), Pont Vert (écrit aussi Ponré), Ouro-Dolé, Kalwao, Kongola Djiddéo | Osidimbea (extrait) ; Wikipédia « Maroua » (extrait) |
| **Maroua 2e** | Doualaré (chef-lieu), Kakataré, Diguirwo (quartiers commerçants cités). La commune compterait **15 quartiers** : les autres noms ne sont pas connus. | Wikipédia « Maroua II » (extrait) |
| **Maroua 3e** | Founangué (grands commerçants), Douggoi / Dougoï, Doursoungo, Louggeo, Sarare, Ouro Lopé, Ouro Bikordi (« 7 grands quartiers » de la zone urbaine) | OIDP Afrique (extrait) |
| **Commune non précisée** | Kodek, Kodek Djarengol, Pallar, Zokok, Djoulgouf, Lopéré, Djoudandou | Wikipédia « Quartiers de Maroua » (extrait) ; IRD (extrait) |

## Variantes d'orthographe et conflits à trancher
- Hardé / **Hardéo** ; Dougoï / **Douggoi** / Dougoy ; Pont Vert / **Ponré** ; Ouro Lopé / Lopéré (même lieu ?) ; Kongola / Kongola Djiddéo.
- **Djarengol** : un tableau Wikipédia le range dans Maroua II, alors que « Djarengol Kaigama » est cité dans Maroua 1er : peut-être des quartiers distincts.
- Pallar, Pallar 1, Pallar II : un quartier découpé en secteurs ?

## Sources (extraits de recherche, pages non lues en entier)
- https://fr.wikipedia.org/wiki/Quartiers_de_Maroua · https://fr.wikipedia.org/wiki/Maroua_II
- https://www.osidimbea.cm/collectivites/extreme-nord/maroua-1-commune/
- https://oidp-afrique.org/2022/07/06/commune-de-maroua-3eme/
- https://www.pndp.org/documents/PCD_Maroua_3eme_FINAL_2.pdf (Plan communal de Maroua 3e)
- https://camerounactuel.com/lorigine-des-noms-des-12-quartiers-de-maroua/ (« 12 quartiers »)
- https://horizon.documentation.ird.fr/exl-doc/pleins_textes/divers16-08/010022018.pdf (IRD)

## Pour compléter
1. Autoriser ces sites dans les réglages réseau de la session (voir ci-dessous), pour que je lise les pages en entier ; ou
2. Me donner la liste officielle (mairie, plan communal) ; ou
3. Repérer les quartiers sur OpenStreetMap (nécessite l'accès à ce site).
Ensuite : validation de Jeff, puis chargement dans `zones.csv` (niveau `quartier`, ville Maroua) avec `python manage.py load_zones`.
