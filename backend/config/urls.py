"""
URL configuration for KPSS Odak content admin + API.
"""

from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path
from django.views.generic import RedirectView

from content.legal_views import privacy_policy

admin.site.site_header = "HEDEF Kamu Yönetim"
admin.site.site_title = "HEDEF Kamu"
admin.site.index_title = "İçerik ve müfredat"

urlpatterns = [
    path("admin/", admin.site.urls),
    path("panel/", include("content.panel_urls")),
    path("api/v1/", include("content.urls")),
    path("gizlilik-politikasi/", privacy_policy, name="privacy_policy"),
    path(
        "privacy-policy/",
        RedirectView.as_view(pattern_name="privacy_policy", permanent=False),
    ),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
