from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User, Parent, Child, Logo, XPEvent

@admin.register(User)
class CustomUserAdmin(UserAdmin):
    pass

class ChildInline(admin.TabularInline):
    model = Child
    extra = 1

@admin.register(Parent)
class ParentAdmin(admin.ModelAdmin):
    list_display = ('name', 'email', 'mobile_phone')
    search_fields = ('name', 'email', 'mobile_phone')
    inlines = [ChildInline]

@admin.register(Logo)
class LogoAdmin(admin.ModelAdmin):
    list_display = ('name',)
    search_fields = ('name',)  

@admin.register(Child)
class ChildAdmin(admin.ModelAdmin):
    list_display = ('name', 'parent', 'grade', 'subject', 'sex', 'xp_total', 'streak_count')
    autocomplete_fields = ('parent', 'logo')
    list_filter = ('grade', 'subject')
    search_fields = ('name', 'parent__name')
    readonly_fields = ['access_code', 'xp_total', 'streak_count', 'last_active_date']


@admin.register(XPEvent)
class XPEventAdmin(admin.ModelAdmin):
    list_display = ('child', 'subject', 'amount', 'source', 'created_at')
    search_fields = ('child__name', 'source')
    list_filter = ('source', 'subject')
    ordering = ('-created_at',)
