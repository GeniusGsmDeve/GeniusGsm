from django.contrib import admin
from .models import EmailMessage


@admin.register(EmailMessage)
class EmailMessageAdmin(admin.ModelAdmin):
    list_display = ('subject', 'mail_from', 'received_at')
    search_fields = ('mail_from', 'subject', 'mail_to')
    readonly_fields = ('received_at',)
from .models import GeneratedAddress
from .models import SiteSetting


@admin.register(GeneratedAddress)
class GeneratedAddressAdmin(admin.ModelAdmin):
    list_display = ('full_address', 'created_at', 'message_count', 'source_ip')
    search_fields = ('local_part', 'domain', 'source_ip')
    readonly_fields = ('created_at',)


@admin.register(SiteSetting)
class SiteSettingAdmin(admin.ModelAdmin):
    list_display = ('key', 'created_at')
    search_fields = ('key',)
    readonly_fields = ('created_at',)
