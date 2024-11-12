from rest_framework import viewsets
from .models import WaitlistUser
from .serializers import WaitlistUserSerializer


class WaitlistUserViewSet(viewsets.ModelViewSet):
    queryset = WaitlistUser.objects.all()
    serializer_class = WaitlistUserSerializer
