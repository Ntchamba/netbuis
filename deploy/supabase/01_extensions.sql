-- NetBuis — extensions PostgreSQL nécessaires (recherche tolérante aux fautes et aux accents).
-- Facultatif : la migration Django `core.0001_extensions` les crée aussi (CREATE EXTENSION IF NOT EXISTS).
-- À lancer dans Supabase → SQL Editor, AVANT `python manage.py migrate`, si vous voulez les ranger
-- dans le schéma `extensions` plutôt que `public`.
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA extensions;
