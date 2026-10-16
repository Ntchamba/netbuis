"""Fabriques factory_boy des comptes."""
import factory

from apps.accounts.models import User


class UserFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = User
        skip_postgeneration_save = True

    phone = factory.Sequence(lambda n: f"+2376{n:08d}")

    @factory.post_generation
    def password(obj, create, extracted, **kwargs):
        # Comptes par code SMS : pas de mot de passe utilisable par défaut.
        if extracted:
            obj.set_password(extracted)
        else:
            obj.set_unusable_password()
        if create:
            obj.save(update_fields=["password"])


class AdminFactory(UserFactory):
    is_admin = True  # is_staff reste réservé à l'admin Django
