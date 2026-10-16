"""UserManager : comptes identifiés par le téléphone (E.164)."""
from django.contrib.auth.base_user import BaseUserManager

from apps.core.utils.phone import normalize_phone


class UserManager(BaseUserManager):
    use_in_migrations = True

    def create_user(self, phone, password=None, **extra):
        user = self.model(phone=normalize_phone(phone), **extra)
        if password:
            user.set_password(password)
        else:  # client / commerçant : connexion par code SMS uniquement
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, phone, password=None, **extra):
        if not password:
            raise ValueError("Un administrateur doit avoir un mot de passe.")
        extra.setdefault("is_admin", True)
        extra.setdefault("is_staff", True)
        extra.setdefault("is_superuser", True)
        return self.create_user(phone, password, **extra)
