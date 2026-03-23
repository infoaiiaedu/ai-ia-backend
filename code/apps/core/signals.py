import logging

from django.db import transaction
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils import timezone

from .models import QuizImport
from .quiz_importer import import_quizzes

logger = logging.getLogger(__name__)


@receiver(post_save, sender=QuizImport)
def run_quiz_import(sender, instance: QuizImport, **kwargs) -> None:
    if not instance.json_file:
        return

    def _run() -> None:
        QuizImport.objects.filter(pk=instance.pk).update(
            status=QuizImport.STATUS_PROCESSING,
            last_error="",
            processed_at=None,
        )

        try:
            warnings = import_quizzes(instance)
        except Exception as exc:
            logger.exception("Quiz import failed: %s", exc)
            QuizImport.objects.filter(pk=instance.pk).update(
                status=QuizImport.STATUS_ERROR,
                last_error=str(exc),
                processed_at=timezone.now(),
            )
            return

        warning_text = "\n".join(warnings)
        QuizImport.objects.filter(pk=instance.pk).update(
            status=QuizImport.STATUS_DONE,
            last_error=warning_text,
            processed_at=timezone.now(),
        )

    transaction.on_commit(_run)
