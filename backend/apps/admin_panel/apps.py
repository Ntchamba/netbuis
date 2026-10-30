from django.apps import AppConfig


class AdminPanelConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.admin_panel"
    label = "admin_panel"
    verbose_name = "Administration"

    def ready(self):
        import logging

        from .log_filters import SignedLinkFilter

        for name in ("django.request", "django.server"):
            logger = logging.getLogger(name)
            if not any(isinstance(f, SignedLinkFilter) for f in logger.filters):
                logger.addFilter(SignedLinkFilter())
