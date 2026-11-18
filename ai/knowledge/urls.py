from django.urls import path
from . import views

urlpatterns = [
    path("api/health/", views.health_api, name="health_api"),
    path("", views.dashboard, name="dashboard"),
    path("collector/sync/", views.queue_youtube_sync, name="queue_youtube_sync"),
    path("api/videos/", views.videos_api, name="videos_api"),
    path("api/search/", views.search_api, name="search_api"),
    path("api/chat/", views.chat_api, name="chat_api"),
]
