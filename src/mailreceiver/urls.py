from django.urls import path
from . import views

app_name = 'mailreceiver'

urlpatterns = [
    path('', views.home, name='home'),
    path('inbox/<str:local>/', views.inbox, name='inbox'),
    path('message/<int:pk>/', views.message_detail, name='message_detail'),
    # API
    path('api/inbox/<str:local>/', views.inbox_api, name='inbox_api'),
    path('api/message/<int:pk>/', views.message_api, name='message_api'),
    path('api/generate/', views.generate_api, name='generate_api'),
    path('create/', views.create_alias, name='create_alias'),
]
