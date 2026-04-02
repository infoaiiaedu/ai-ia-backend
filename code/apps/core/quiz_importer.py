import json
import logging
from typing import Any, Dict, List, Optional, Tuple

from django.db import transaction

from .models import Answer, Question, Quiz, QuizImport

logger = logging.getLogger(__name__)


class QuizImportError(Exception):
    pass


def resolve_correct_option(
    options: List[Dict[str, str]], correct_raw: Optional[str]
) -> Optional[str]:
    if not options or not correct_raw:
        return None
    correct_raw = correct_raw.strip()
    if len(correct_raw) == 1 and correct_raw.isalpha():
        return correct_raw.upper()

    normalized = correct_raw.lower()
    for option in options:
        if option["text"].lower() == normalized:
            return option["label"].upper()
    return None


def load_json_payload(quiz_import: QuizImport) -> Dict[str, Any]:
    try:
        with quiz_import.json_file.open("rb") as raw:
            data = json.load(raw)
    except Exception as exc:
        raise QuizImportError(f"Failed to read JSON: {exc}") from exc
    if not isinstance(data, dict):
        raise QuizImportError("JSON root must be an object with a 'quizzes' array.")
    return data


def normalize_payload(payload: Any) -> Tuple[str, Any]:
    if isinstance(payload, list):
        return "questions", payload
    if not isinstance(payload, dict):
        raise QuizImportError("JSON root must be an object or a list of questions.")

    if "quizzes" in payload:
        quizzes = payload.get("quizzes")
        if not isinstance(quizzes, list) or not quizzes:
            raise QuizImportError("'quizzes' must be a non-empty list.")
        return "quizzes", quizzes

    if "questions" in payload:
        questions = payload.get("questions")
        if not isinstance(questions, list) or not questions:
            raise QuizImportError("'questions' must be a non-empty list.")
        return "questions", questions

    raise QuizImportError("JSON must contain 'quizzes' or 'questions'.")


def normalize_options(raw_options: Any) -> List[Dict[str, Any]]:
    if raw_options is None:
        return []
    if not isinstance(raw_options, list):
        raise QuizImportError("'options' must be a list.")

    options: List[Dict[str, Any]] = []
    for idx, opt in enumerate(raw_options):
        label = chr(ord("A") + idx)
        if isinstance(opt, str):
            options.append({"label": label, "text": opt, "is_correct": False})
            continue
        if not isinstance(opt, dict):
            raise QuizImportError("Each option must be a string or object.")
        text = opt.get("text")
        if not text:
            raise QuizImportError("Option text is required.")
        options.append(
            {
                "label": opt.get("label", label),
                "text": text,
                "is_correct": bool(opt.get("is_correct", False)),
            }
        )
    return options


def resolve_correct_label(
    options: List[Dict[str, Any]],
    correct_raw: Optional[str],
    correct_index: Optional[int],
) -> Optional[str]:
    if correct_index is not None:
        if 0 <= correct_index < len(options):
            return options[correct_index]["label"].upper()
        return None

    if correct_raw:
        return resolve_correct_option(options, correct_raw)

    correct_options = [opt for opt in options if opt.get("is_correct")]
    if len(correct_options) == 1:
        return correct_options[0]["label"].upper()
    return None


def import_quizzes(quiz_import: QuizImport) -> List[str]:
    warnings: List[str] = []
    payload = load_json_payload(quiz_import)
    mode, data = normalize_payload(payload)

    with transaction.atomic():
        if mode == "questions":
            if not quiz_import.target_quiz:
                raise QuizImportError("Select a target quiz for question-only JSON.")

            quiz = quiz_import.target_quiz
            Question.objects.filter(quiz=quiz).delete()
            questions = data
            if not isinstance(questions, list) or not questions:
                warnings.append(f"Quiz '{quiz.title}' has no questions.")
            else:
                _import_questions(quiz_import, quiz, questions, warnings)
        else:
            quiz_import.quizzes.all().delete()
            for quiz_spec in data:
                if not isinstance(quiz_spec, dict):
                    raise QuizImportError("Each quiz must be an object.")
                title = quiz_spec.get("title")
                if not title:
                    raise QuizImportError("Each quiz requires a title.")
                quiz = Quiz.objects.create(
                    title=title,
                    description=quiz_spec.get("description"),
                    subject=quiz_import.subject,
                    grade=quiz_import.grade,
                    source_import=quiz_import,
                )
                if quiz_import.topics.exists():
                    quiz.topics.set(list(quiz_import.topics.all()))

                questions = quiz_spec.get("questions")
                if not isinstance(questions, list) or not questions:
                    warnings.append(f"Quiz '{quiz.title}' has no questions.")
                    continue
                _import_questions(quiz_import, quiz, questions, warnings)

    return warnings


def _import_questions(
    quiz_import: QuizImport,
    quiz: Quiz,
    questions: List[Dict[str, Any]],
    warnings: List[str],
) -> None:
    for idx, question_spec in enumerate(questions, start=1):
        if not isinstance(question_spec, dict):
            raise QuizImportError("Each question must be an object.")

        text = question_spec.get("text") or question_spec.get("question")
        if not text:
            raise QuizImportError("Question text is required.")

        options = normalize_options(question_spec.get("options"))
        question_type = question_spec.get("type")
        if not question_type:
            question_type = Question.MCQ if options else Question.OPEN

        question = Question.objects.create(
            quiz=quiz,
            text=text,
            question_type=question_type,
            order=idx,
            level=question_spec.get("level", quiz_import.level),
            correct_text_answer=question_spec.get("answer")
            if question_type == Question.OPEN
            else None,
            explanation=question_spec.get("explanation"),
        )

        if question_type == Question.MCQ:
            correct_label = resolve_correct_label(
                options,
                question_spec.get("correct"),
                question_spec.get("correctIndex"),
            )
            if correct_label is None:
                warnings.append(
                    f"Question '{question.text[:50]}' has no valid correct option."
                )

            for opt_idx, option in enumerate(options, start=1):
                Answer.objects.create(
                    question=question,
                    text=option["text"],
                    is_correct=option["label"].upper() == correct_label,
                    order=opt_idx,
                )
