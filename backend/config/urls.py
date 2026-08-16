"""
URL configuration for KPSS Odak content admin + API.
"""

from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path

admin.site.site_header = "KPSS Odak Yönetim"
admin.site.site_title = "KPSS Odak"
admin.site.index_title = "İçerik ve müfredat"

urlpatterns = [
    path("admin/", admin.site.urls),
    path("panel/", include("content.panel_urls")),
    path("api/v1/", include("content.urls")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
