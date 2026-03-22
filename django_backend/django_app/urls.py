from django.urls import path
from .views import bulk_upload, dashboard

urlpatterns = [
    path('bulk-upload/', bulk_upload, name='bulk_upload'),
    path('admin/upload-questions/', bulk_upload, name='admin_upload_questions'),
    path('dashboard/', dashboard, name='dashboard'),
]