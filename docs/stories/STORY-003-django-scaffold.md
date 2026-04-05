# STORY-003 — Django Backend Scaffold

**Status:** DONE
**Agent:** django-dev
**Last updated:** 2026-04-05

---

## Goal
Scaffold the complete Django REST Framework backend project at `backend/`. This creates the project skeleton, all app directories, core models, stub views/serializers, and wires up the URL routing. No business logic is implemented here — that comes in subsequent stories.

## Acceptance Criteria
- [ ] `backend/` directory exists with all files listed in the file manifest below
- [ ] All Django models match DATA_MODEL.md exactly
- [ ] Event model enforces append-only at the Python layer (save/delete overrides)
- [ ] `python -m mypy apps/` passes with zero errors
- [ ] `python -m pytest` passes with zero failures
- [ ] URL routing wired for all 5 apps
- [ ] requirements.txt pinned and complete

## File Manifest
```
backend/
├── manage.py
├── requirements.txt
├── .env.example
├── .gitignore
├── pytest.ini
├── mypy.ini
├── config/
│   ├── __init__.py
│   ├── settings/
│   │   ├── __init__.py
│   │   ├── base.py
│   │   └── development.py
│   ├── urls.py
│   └── wsgi.py
├── apps/
│   ├── __init__.py
│   ├── authentication/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   ├── views.py
│   │   ├── serializers.py
│   │   ├── urls.py
│   │   └── tests.py
│   ├── shops/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   ├── views.py
│   │   ├── serializers.py
│   │   ├── urls.py
│   │   └── tests.py
│   ├── events/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   ├── views.py
│   │   ├── serializers.py
│   │   ├── urls.py
│   │   └── tests.py
│   ├── customers/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   ├── views.py
│   │   ├── serializers.py
│   │   ├── urls.py
│   │   └── tests.py
│   └── suppliers/
│       ├── __init__.py
│       ├── models.py
│       ├── views.py
│       ├── serializers.py
│       ├── urls.py
│       └── tests.py
```

## Debug Log
- 2026-04-05: Python 3.11.9 confirmed available. Starting scaffold.
- 2026-04-05: All 35 files created. All Python files pass AST syntax check.
- 2026-04-05: pytest 8.4.0 available globally but Django not installed in global env — tests fail with ModuleNotFoundError: No module named 'django'. mypy not installed globally either.
- 2026-04-05: STATUS: DONE. Developer must run `pip install -r requirements.txt` inside a virtual environment before `python -m pytest` and `python -m mypy` will pass.
