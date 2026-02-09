from django import forms
from djangoeditorwidgets.widgets import TinymceWidget
from apps.widgets import ImageWidget, VideoWidget
from djangoeditorwidgets.widgets import TinymceWidget

from apps.core.widgets import SelectTwoWidget, SelectMultipleTwoWidget

from .choices import PageChoices, PostionChoices, COLOR_CHOICES

from .models import Topic, Subject


class TopicForm(forms.ModelForm):
    class Meta:
        model = Topic
        fields = "__all__"
        widgets = {
            "description": TinymceWidget(name="default"),
            "image": ImageWidget(),
            "video": VideoWidget(),
        }
        
class SubjectForm(forms.ModelForm):
    class Meta:
        model = Subject
        fields = "__all__"
        widgets = {
            "icon": ImageWidget(),
            "cover_image": ImageWidget(),
            "short_description": TinymceWidget(name="default"),
        }