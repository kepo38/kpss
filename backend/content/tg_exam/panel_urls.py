"""TG deneme panel URL'leri — panel_urls.py içine include edilir."""

from django.urls import path

from . import panel_views

urlpatterns = [
    path(
        "tg-deneme/",
        panel_views.panel_tg_exam_list,
        name="panel_tg_exam_list",
    ),
    path(
        "tg-deneme/yeni/",
        panel_views.panel_tg_exam_edit,
        name="panel_tg_exam_new",
    ),
    path(
        "tg-deneme/<int:exam_id>/",
        panel_views.panel_tg_exam_edit,
        name="panel_tg_exam_edit",
    ),
    path(
        "tg-deneme/<int:exam_id>/degistir/",
        panel_views.panel_tg_exam_replace_question,
        name="panel_tg_exam_replace",
    ),
    path(
        "tg-deneme/<int:exam_id>/yayinla/",
        panel_views.panel_tg_exam_publish,
        name="panel_tg_exam_publish",
    ),
    path(
        "tg-deneme/<int:exam_id>/yayindan-kaldir/",
        panel_views.panel_tg_exam_unpublish,
        name="panel_tg_exam_unpublish",
    ),
    path(
        "tg-deneme/<int:exam_id>/sil/",
        panel_views.panel_tg_exam_delete,
        name="panel_tg_exam_delete",
    ),
]
