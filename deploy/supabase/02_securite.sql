-- NetBuis — fermer l'API de données de Supabase (PostgREST) sur les tables de l'application.
--
-- POURQUOI : Supabase expose par défaut le schéma `public` à Internet (API REST, clé « anon » publique).
-- Les tables créées par Django n'ont pas de RLS : sans ce script, quiconque connaît l'adresse du projet et
-- la clé anon pourrait LIRE les numéros de téléphone et les comptes. NetBuis n'utilise PAS cette API :
-- le serveur Django se connecte directement à PostgreSQL avec le rôle `postgres`.
--
-- QUAND : après `python manage.py migrate` (les tables doivent exister), à relancer après toute
-- nouvelle migration qui crée une table (le bloc 3 se rejoue sans risque).
-- OÙ : Supabase → SQL Editor, rôle `postgres`. Ne contient aucun secret.

-- 1. Plus aucun droit pour les rôles de l'API sur le schéma public.
REVOKE ALL ON SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon, authenticated;

-- 2. Les futures tables ne leur donnent rien non plus.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon, authenticated;

-- 3. Deuxième verrou : sécurité par ligne (RLS) activée sur toutes les tables, sans aucune règle
--    (= refus total pour les rôles soumis à la RLS). Le rôle `postgres` utilisé par Django la contourne.
DO $$
DECLARE t record;
BEGIN
  FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t.tablename);
  END LOOP;
END $$;
