from django import forms
import re


class CustomAliasForm(forms.Form):
    local = forms.CharField(
        label='Local part',
        min_length=3,
        max_length=64,
        help_text='Allowed: letters, digits, dot, underscore, hyphen',
    )

    def clean_local(self):
        v = self.cleaned_data['local'].strip().lower()
        if not re.match(r'^[a-z0-9._-]+$', v):
            raise forms.ValidationError('Invalid characters in local part')
        if v.startswith('.') or v.endswith('.'):
            raise forms.ValidationError('Local part cannot start or end with a dot')
        return v
