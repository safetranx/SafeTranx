from rest_framework import serializers
from .models import WaitlistUser, RoleEnum


class WaitlistUserSerializer(serializers.ModelSerializer):
    role = serializers.ChoiceField(choices=RoleEnum.choices())

    class Meta:
        model = WaitlistUser
        fields = ['full_name', 'email', 'role']
