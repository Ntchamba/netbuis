-- NetBuis — contrôles à lancer dans Supabase → SQL Editor après la mise en place.

-- Extensions présentes (attendu : pg_trgm et unaccent).
SELECT extname FROM pg_extension WHERE extname IN ('pg_trgm', 'unaccent') ORDER BY 1;

-- Tables SANS sécurité par ligne (attendu : aucune ligne).
SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND NOT rowsecurity ORDER BY 1;

-- Droits restants pour les rôles de l'API (attendu : aucune ligne).
SELECT grantee, table_name, privilege_type FROM information_schema.role_table_grants
WHERE table_schema = 'public' AND grantee IN ('anon', 'authenticated') LIMIT 20;

-- La recherche tolérante aux fautes fonctionne (attendu : 0.8 ou plus ; la fonction vit dans public ou extensions).
SELECT word_similarity('riz', 'riz local');
