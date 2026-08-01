# Ali Juma — Research Portfolio Platform

A self-managed research portfolio and CMS: a Flutter Web front end for
university admissions committees, professors, scholarship organisations,
recruiters, and collaborators, backed by a Flask REST API and an admin
dashboard so every page can be updated without touching code.

```
portfolio/
├── backend/    Flask REST API, JWT auth, Supabase Postgres models, admin endpoints
├── frontend/   Flutter Web app (Riverpod + GoRouter), public site + admin dashboard
└── docs/       Database schema, deployment guide, security notes
```

## Quick start

### 1. Backend (Flask API)

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

cp .env.example .env
# Edit .env: at minimum set SECRET_KEY, JWT_SECRET_KEY, ADMIN_EMAIL, ADMIN_PASSWORD.
# DATABASE_URL defaults to a local SQLite file, so you can run everything
# below without Supabase set up yet.

python scripts/seed_admin.py     # creates the one administrator account
flask run                        # http://localhost:5000
```

Run the test suite (auth, validation, draft/publish flow, contact form):

```bash
pytest
```

### 2. Frontend (Flutter Web)

Requires Flutter **3.27+** (`flutter --version`; `flutter upgrade` if older —
the theme code uses newer `Color.withValues` / `CardThemeData` APIs).

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000/api
```

Without `--dart-define=API_BASE_URL=...`, the app defaults to
`http://localhost:5000/api`. If the backend isn't running, every public page
still renders using bundled placeholder content (see
`frontend/lib/data/placeholder_data.dart`) so the site is always reviewable.

Admin dashboard: `http://localhost:PORT/#/admin/login`, using the
`ADMIN_EMAIL` / `ADMIN_PASSWORD` you seeded above.

### 3. Database (Supabase Postgres)

See [`docs/schema.sql`](docs/schema.sql) — run it once against a new Supabase
project (SQL editor, or `psql`) to create every table the backend expects,
including Row Level Security locked down by default. Then point
`DATABASE_URL` in `backend/.env` at your Supabase connection string.

Full deployment steps (Supabase + Railway): [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md)
Security implementation notes: [`docs/SECURITY.md`](docs/SECURITY.md)

## What's implemented vs. what's scaffolded

This is a working full-stack scaffold, not a finished product — built to be
extended rather than a finished, deployed site:

- **Fully implemented, end-to-end**: public site (all 12 PRD pages) reading
  from the API with placeholder-content fallback; JWT auth with account
  lockout; and a complete admin dashboard with a dedicated manager screen
  for every content type in the PRD — Research (with milestones,
  publish/archive), Publications (with file attachment via Media Manager),
  Software Projects, Blog (Markdown editor, publish), Skills, Timeline,
  Achievements, Gallery, Media/Downloads (upload, visibility toggle,
  delete), and Website Settings (homepage text, SEO, social/contact links)
  — every one backed by a matching, tested Flask CRUD API.
  `research_manager_page.dart` was the original reference pattern; every
  other manager under `frontend/lib/features/admin/` follows the same
  list + `EditorDialogShell` + `confirmDelete` structure (shared helpers in
  `features/admin/widgets/admin_common.dart`), so extending any of them
  (e.g. adding a new field) means touching one file in a familiar shape.
- **Documented but not wired up**: analytics, 2FA (the `Admin` model already
  has `totp_secret` / `is_2fa_enabled` columns reserved for it), scheduled
  blog publishing (the `scheduled_for` field and `status='scheduled'` exist
  in the schema; a cron/worker to flip drafts to published at that time is
  not yet built).

## A note on how this was built

This scaffold was generated in a sandboxed environment with **no access to
PyPI, apt, or the Flutter SDK** — so nothing here has been run through
`pip install`, `pytest`, `flutter pub get`, or `flutter analyze` yet. Every
backend file passed `python3 -m py_compile` (syntax-valid) and went through a
manual review pass; the Flutter code went through an independent review pass
checking imports, provider wiring, model fields, and Flutter API usage. Both
are believed correct, but **please run `pytest` and `flutter analyze` /
`flutter pub get` yourselves as the first step** before building on top of
this — treat that as this project's actual "CI has never run" disclaimer.
