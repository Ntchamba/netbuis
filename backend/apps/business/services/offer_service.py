"""Offres du commerçant (T037) : toujours limitées au profil ACTIF de l'utilisateur connecté.

Un compte sans profil reçoit 404 `no_business` ; un profil non actif (en attente, rejeté)
403 `business_not_active`. Les offres d'un autre commerçant n'existent pas pour lui (404).
"""
from rest_framework import status

from apps.business.models import BusinessProfile, BusinessStatus, Offer
from apps.business.services import profile_service
from apps.core.exceptions import ApiError


class BusinessNotActive(ApiError):
    status_code = status.HTTP_403_FORBIDDEN
    default_code = "business_not_active"
    default_detail = "Votre compte business est en attente de validation."


def active_profile(user) -> BusinessProfile:
    profile = profile_service.get_own_profile(user)
    if profile.status != BusinessStatus.ACTIVE:
        raise BusinessNotActive()
    return profile


def own_offers(user):
    return Offer.objects.filter(profile=active_profile(user)).select_related("catalog_product")


def create_offer(user, data) -> Offer:
    return Offer.objects.create(profile=active_profile(user), **data)


def update_offer(offer: Offer, data) -> Offer:
    for field, value in data.items():
        setattr(offer, field, value)
    offer.save()
    return offer
