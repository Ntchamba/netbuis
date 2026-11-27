"""Signaux du noyau : le cache d'un réglage de plateforme est vidé à chaque écriture
(sauvegarde ou suppression, y compris la suppression groupée de l'admin Django)."""
from django.db import transaction
from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver

from apps.core.models import PlatformSetting
from apps.core.services.settings_service import invalidate_setting


@receiver(post_save, sender=PlatformSetting, dispatch_uid="platform_setting_saved")
@receiver(post_delete, sender=PlatformSetting, dispatch_uid="platform_setting_deleted")
def _invalidate_platform_setting(sender, instance, **kwargs):
    invalidate_setting(instance.key)
    # Encore une fois après la validation de la transaction : une lecture faite entre-temps
    # aurait remis l'ancienne valeur en cache.
    transaction.on_commit(lambda: invalidate_setting(instance.key))
