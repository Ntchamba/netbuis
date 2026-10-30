"""Admin Django des référentiels et du catalogue (T021) : tout se corrige ici, rien n'est figé
dans le code. Le code stable n'est modifiable qu'à la création (le mobile s'y appuie)."""
from django.contrib import admin

from .models import CatalogProduct, Sector, ServiceCategory, StructureType, Subcategory, Synonym


class StableCodeAdmin(admin.ModelAdmin):
    def get_readonly_fields(self, request, obj=None):
        fields = list(super().get_readonly_fields(request, obj))
        if obj is not None:
            fields.append("code")
        return fields


class SubcategoryInline(admin.TabularInline):
    model = Subcategory
    extra = 0
    fields = ("code", "name", "icon", "order", "is_active")


@admin.register(Sector)
class SectorAdmin(StableCodeAdmin):
    list_display = ("name", "icon", "code", "order", "is_active")
    list_filter = ("is_active",)
    search_fields = ("name", "code")
    ordering = ("order", "name")
    inlines = [SubcategoryInline]


@admin.register(Subcategory)
class SubcategoryAdmin(StableCodeAdmin):
    list_display = ("name", "sector", "code", "order", "is_active")
    list_filter = ("sector", "is_active")
    search_fields = ("name", "code", "sector__name")
    ordering = ("sector__order", "order", "name")
    list_select_related = ("sector",)


@admin.register(ServiceCategory)
class ServiceCategoryAdmin(StableCodeAdmin):
    list_display = ("name", "icon", "code", "order", "is_active")
    list_filter = ("is_active",)
    search_fields = ("name", "code")
    ordering = ("order", "name")


@admin.register(StructureType)
class StructureTypeAdmin(StableCodeAdmin):
    list_display = ("name", "icon", "code", "order", "is_active")
    list_filter = ("is_active",)
    search_fields = ("name", "code")
    ordering = ("order", "name")


class SynonymInline(admin.TabularInline):
    model = Synonym
    extra = 0
    fields = ("term",)


@admin.register(CatalogProduct)
class CatalogProductAdmin(admin.ModelAdmin):
    list_display = ("name", "category", "is_active")
    list_filter = ("is_active", "category__sector")
    search_fields = ("name", "normalized_name", "synonyms__term")
    ordering = ("normalized_name",)
    list_select_related = ("category__sector",)
    readonly_fields = ("normalized_name", "created_at", "updated_at")
    inlines = [SynonymInline]


@admin.register(Synonym)
class SynonymAdmin(admin.ModelAdmin):
    list_display = ("term", "product")
    search_fields = ("term", "normalized_term", "product__name")
    ordering = ("normalized_term",)
    list_select_related = ("product",)
    autocomplete_fields = ("product",)
    readonly_fields = ("normalized_term", "created_at", "updated_at")
