# myproject/views.py
from django.http import JsonResponse
from django.db import connections
from django.db.utils import OperationalError


def health_check(request):
    db_status = "ok"
    try:
        connections['default'].cursor()
    except OperationalError:
        db_status = "unavailable"

    return JsonResponse({
        "status": "ok",
        "database": db_status,
    }, status=200 if db_status == "ok" else 500)
