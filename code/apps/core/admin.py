from django.contrib import admin
from .models import Subject, Grade, Topic
from .forms import TopicForm

@admin.register(Subject)
class SubjectAdmin(admin.ModelAdmin):
    list_display = ('name',)
    search_fields = ('name',)
    ordering = ('name',)


@admin.register(Grade)
class GradeAdmin(admin.ModelAdmin):
    list_display = ('level',)
    search_fields = ('level',)
    ordering = ('level',)
    


@admin.register(Topic)
class TopicAdmin(admin.ModelAdmin):
    form = TopicForm
<<<<<<< HEAD
    list_display = ['name', 'grade']
    search_fields = ['name', 'grade']
    ordering = ['name']
    autocomplete_fields = ['grade']
=======
    list_display = ('name', 'subject')
    list_filter = ('subject',)
    search_fields = ('name', 'subject__name')
    ordering = ('subject', 'name')
    autocomplete_fields = ['subject', 'grade']
>>>>>>> 582c3dc12a9409382079981e07f3d17f362746f3
