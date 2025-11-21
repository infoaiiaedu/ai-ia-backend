from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User, Parent, Child

@admin.register(User)
class CustomUserAdmin(UserAdmin):
    pass

class ChildInline(admin.TabularInline):
    model = Child
    extra = 1

@admin.register(Parent)
class ParentAdmin(admin.ModelAdmin):
    list_display = ('name', 'mobile_phone')
    search_fields = ('name', 'mobile_phone')
    inlines = [ChildInline]

@admin.register(Child)
class ChildAdmin(admin.ModelAdmin):
    list_display = ('name', 'parent', 'grade')
    autocomplete_fields = ('parent',)
    list_filter = ('grade',)
    search_fields = ('name', 'parent__name')
    readonly_fields = ['otp_code', 'otp_expiry']
