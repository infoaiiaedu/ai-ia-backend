from django.forms.widgets import ClearableFileInput

import json

from django import forms
from django.utils.safestring import mark_safe


class SelectTwoWidget(forms.Select):
    template_name = "widgets/select.html"


class SelectMultipleTwoWidget(forms.SelectMultiple):
    template_name = "widgets/select.html"

    def optgroups(self, name, value, attrs=None):
        if isinstance(value, list):
            value = json.loads(value[0])

        if value is None:
            value = []

        return super().optgroups(name, value, attrs)


class CustomFileInput(ClearableFileInput):
    template_name = "custom_file_input.html"
