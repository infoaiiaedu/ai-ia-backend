from django.contrib import admin
from django.forms import ModelForm
from adminsortable2.admin import SortableAdminMixin, SortableInlineAdminMixin
from django.forms.models import BaseInlineFormSet
from django.core.exceptions import ValidationError
import logging
from django.db.models import F
logger = logging.getLogger(__name__)
from .forms import TopicForm
from .models import Subject, Grade, Topic, Quiz, Question, Answer


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
    list_display = ['name', 'grade']
    search_fields = ['name', 'grade']
    ordering = ['name']
    autocomplete_fields = ['grade']


class AnswerInlineFormSet(BaseInlineFormSet):
    def __init__(self, *args, **kwargs):
        # adminsortable2 may pass extra kwargs - swallow them so BaseInlineFormSet.__init__ won't error
        kwargs.pop('default_order_direction', None)
        kwargs.pop('default_order_field', None)
        super().__init__(*args, **kwargs)
    def clean(self):
        try:
            super().clean()
            # Determine question type: prefer the saved instance, fallback to POSTed parent form value
            qtype = getattr(self.instance, 'question_type', None)
            if not qtype:
                # Try to find the parent form's question_type in POST data. Keys can be
                # like 'question-0-question_type' or simply 'question_type'.
                for key, val in self.data.items():
                    if key.endswith('-question_type') or key == 'question_type':
                        qtype = val
                        break

            # Count non-deleted answers with any data
            answers = [f for f in self.forms if getattr(f, 'cleaned_data', None) and not f.cleaned_data.get('DELETE', False)]

            if qtype == 'mcq' and len(answers) == 0:
                raise ValidationError('Multiple choice questions require at least one answer.')
        except ValidationError:
            # propagate validation errors to be shown in admin form
            raise
        except Exception as exc:
            # Log unexpected exceptions and skip inline validation to avoid breaking the admin page
            logger.exception('AnswerInlineFormSet.clean() failed: %s', exc)
            return


class AnswerInline(SortableInlineAdminMixin, admin.TabularInline):
    model = Answer
    formset = AnswerInlineFormSet
    extra = 2
    min_num = 0
    max_num = 10
    verbose_name = "პასუხი"
    verbose_name_plural = "პასუხები"
    fields = ['text', 'is_correct', 'order']
    sortable_field_name = 'order'

    class Media:
        js = ('adminsortable2/js/adminsortable2.js',)


class QuestionForm(ModelForm):
    class Meta:
        model = Question
        fields = ('text', 'question_type', 'xp', 'correct_text_answer', 'explanation')

    class Media:
        js = ('admin/js/question_type_toggle.js', 'adminsortable2/js/adminsortable2.js')


# Form used for Question change (includes quiz)
class QuestionAdminForm(ModelForm):
    class Meta:
        model = Question
        fields = '__all__'

    class Media:
        js = ('admin/js/question_type_toggle.js', 'adminsortable2/js/adminsortable2.js')

class QuestionInline(SortableInlineAdminMixin, admin.StackedInline):
    model = Question
    form = QuestionForm
    extra = 1
    show_change_link = True
    fields = ['text', 'question_type', 'xp', 'correct_text_answer']
    verbose_name = "კითხვა"
    verbose_name_plural = "კითხვები"
    sortable_field_name = 'order'
    class Media:
        js = ('admin/js/question_type_toggle.js', 'adminsortable2/js/adminsortable2.js')


@admin.register(Quiz)
class QuizAdmin(SortableAdminMixin, admin.ModelAdmin):
    list_display = ('title', 'level', 'created_at', 'updated_at')
    inlines = [QuestionInline]
    search_fields = ('title',)

    class Media:
        js = ('admin/js/question_type_toggle.js',)

    def save_formset(self, request, form, formset, change):
        instances = formset.save(commit=False)
        parent = form.instance
        for obj in instances:
            # obj.pk is None for new inline objects
            if getattr(obj, 'pk', None) is None and not getattr(obj, '_delete', False):
                # shift existing questions for this quiz
                parent.questions.update(order=F('order') + 1)
                obj.order = 0
            # ensure fk is set for inline-created objects
            if getattr(obj, 'quiz', None) is None:
                obj.quiz = parent
            obj.save()
        formset.save_m2m()


@admin.register(Question)
class QuestionAdmin(SortableAdminMixin, admin.ModelAdmin):
    form = QuestionAdminForm
    list_display = ['text_short', 'quiz', 'question_type', 'order', 'xp']
    list_filter = ('quiz', 'question_type')
    search_fields = ('text', 'quiz__title')
    inlines = [AnswerInline]
    autocomplete_fields = ('quiz',)

    fieldsets = (
        ('ძირითადი ინფორმაცია', {
            'fields': ('quiz', 'text', 'question_type', 'order', 'xp')
        }),
        ('პასუხები', {
            'fields': ('correct_text_answer',),
            'description': 'სწორი პასუხი საჭირო მხოლოდ ღია კითხვებისთვის'
        }),
    )

    def text_short(self, obj):
        return obj.text[:50] + '...' if len(obj.text) > 50 else obj.text
    text_short.short_description = 'კითხვა'

    class Media:
        js = ('admin/js/question_type_toggle.js',)


@admin.register(Answer)
class AnswerAdmin(SortableAdminMixin, admin.ModelAdmin):
    list_display = ('text', 'question', 'is_correct', 'order')
    list_filter = ('is_correct', 'question__quiz')
    search_fields = ('text', 'question__text')
    ordering = ('question', 'order')
    fieldsets = (
        ('ინფორმაცია', {
            'fields': ('question', 'text', 'is_correct')
        }),
    )
    list_editable = ('is_correct', 'order')
    