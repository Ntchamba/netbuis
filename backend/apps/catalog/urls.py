"""Routes publiques des référentiels et du catalogue (T021)."""
from django.urls import path

from .views.category import SectorListView, ServiceCategoryListView, StructureTypeListView
from .views.product import CatalogProductSearchView

app_name = "catalog"

urlpatterns = [
    path("referentials/sectors/", SectorListView.as_view(), name="sector-list"),
    path(
        "referentials/service-categories/", ServiceCategoryListView.as_view(),
        name="service-category-list",
    ),
    path(
        "referentials/structure-types/", StructureTypeListView.as_view(),
        name="structure-type-list",
    ),
    path("catalog/products/", CatalogProductSearchView.as_view(), name="product-search"),
]
