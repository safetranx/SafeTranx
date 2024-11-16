from django.db import models
from django.utils.translation import gettext_lazy as _
from enum import Enum


class RoleEnum(Enum):
    BUYER = 'buyer'
    SELLER = 'seller'
    RIDER = 'rider'
    VALIDATOR = 'validator'

    @classmethod
    def choices(cls):
        return [(key.name, key.value) for key in cls]


class WaitlistUser(models.Model):
    ROLE_CHOICES = RoleEnum.choices()

    full_name = models.CharField(max_length=100, verbose_name=_('Full Name'))
    email = models.EmailField(unique=True, verbose_name=_('Email'))
    role = models.CharField(
        max_length=10, choices=ROLE_CHOICES, verbose_name=_('Role'))
    joined_at = models.DateTimeField(
        auto_now_add=True, verbose_name=_('Joined At'))

    def __str__(self):
        return f"{self.full_name} - {self.email} ({self.role})"
