from django.contrib import admin
from .models import DraftQuestion

class DraftQuestionAdmin(admin.ModelAdmin):
    actions = ['generate_with_ai']

    def generate_with_ai(self, request, queryset):
        # Logic to fill selected drafts with AI-generated content
        for draft in queryset:
            draft.content = self.get_ai_generated_content(draft)
            draft.save()
        self.message_user(request, "Selected drafts have been filled with AI-generated content.")

    def get_ai_generated_content(self, draft):
        # Placeholder for AI content generation logic
        return "AI-generated content for question: " + draft.question_text

admin.site.register(DraftQuestion, DraftQuestionAdmin)