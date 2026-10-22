from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

urlpatterns = [
    path("api/", include("apps.core.health.urls")),
    path("api/", include("apps.accounts.urls")),
    path("api/", include("apps.geo.urls")),
    path("api/", include("apps.catalog.urls")),
    path("api/", include("apps.business.urls")),
    path("api/", include("apps.search.urls")),
    path("api/", include("apps.calls.urls")),
    path("api/", include("apps.forum.urls")),
    path("api/", include("apps.trends.urls")),
    path("api/", include("apps.notifications.urls")),
    path("api/", include("apps.printing.urls")),
    path("api/payments/", include("apps.payments.urls")),
    path("api/admin/", include("apps.admin_panel.urls")),
]

# Admin Django : désactivé en production tant qu'aucun chemin non trivial n'est donné (T121).
if settings.DJANGO_ADMIN_PATH:
    urlpatterns.insert(0, path(settings.DJANGO_ADMIN_PATH, admin.site.urls))

# Schéma et documentation de l'API : développement seulement par défaut (T121).
if settings.API_DOCS_ENABLED:
    urlpatterns += [
        path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
        path("api/docs/", SpectacularSwaggerView.as_view(url_name="schema")),
    ]

# Photos PUBLIQUES envoyées (MEDIA_ROOT) : servies par Django seulement si DEBUG (renvoie [] sinon).
# L'espace privé (PRIVATE_MEDIA_ROOT : CNI, diplôme) n'a aucune route ici. En production, ce sera
# le futur stockage compatible S3.
urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
