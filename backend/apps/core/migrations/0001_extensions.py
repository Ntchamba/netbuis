"""Active les extensions PostgreSQL pg_trgm et unaccent (tâche A1.3).

Agent A · Étape É1
"""
from django.contrib.postgres.operations import TrigramExtension, UnaccentExtension
from django.db import migrations


class Migration(migrations.Migration):
    dependencies = []

    operations = [TrigramExtension(), UnaccentExtension()]
