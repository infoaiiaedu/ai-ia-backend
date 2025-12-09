from django.urls import path
from . import views

app_name = 'monitoring'

urlpatterns = [
    path('', views.dashboard, name='dashboard'),
    path('api/metrics/', views.metrics_api, name='metrics_api'),
]
