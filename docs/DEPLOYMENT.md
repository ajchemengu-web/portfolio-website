# Deployment Guide

Target stack: **Supabase** (Postgres + Storage) · **Railway** (Flask API
hosting) · a static host of your choice for the compiled Flutter Web build
(Railway can serve it too, or use Netlify/Vercel/Cloudflare Pages/GitHub
Pages — the app is just static files after `flutter build web`).

There are two ways to get a Supabase project: the hosted **supabase.com**
service (Section 1), or a **self-hosted instance running as a Railway
service** from Railway's Supabase template (Section 1b). Both give you the
same thing — a Postgres database plus Storage/Auth APIs behind a project
URL — so `docs/schema.sql` and the rest of this guide apply unchanged to
either. Pick whichever section matches what you actually created.

## 1. Supabase project (hosted on supabase.com)

1. Create a project at supabase.com.
2. Open the SQL editor and run [`docs/schema.sql`](schema.sql) in full. This
   creates every table the backend expects and enables Row Level Security
   with no policies (default-deny for Supabase's own auto-generated
   PostgREST/GraphQL API — see the comment block at the top of that file for
   why this matters even though the Flask backend doesn't use PostgREST).
3. Create a Storage bucket (Storage → New bucket). Match the name to
   `SUPABASE_STORAGE_BUCKET` in your backend `.env` (default:
   `portfolio-files`). Leave it **private** — the backend mints signed URLs
   for `view_only`/`private` files and only exposes a permanent public URL
   for files explicitly marked `visibility: public`.
4. Collect from Project Settings:
   - **Connection string** (Settings → Database → Connection string → URI,
     "Session pooler" recommended for a long-lived backend process) → this
     is `DATABASE_URL`.
   - **Project URL** (Settings → API) → `SUPABASE_URL`.
   - **Service role key** (Settings → API → service_role, *secret*) →
     `SUPABASE_SERVICE_ROLE_KEY`. Never expose this key to the frontend —
     it bypasses Row Level Security entirely. Only the Flask backend holds
     it.

## 1b. Supabase project (self-hosted via Railway template)

This is what a Railway project with a service showing a `*.supabase.co`-style
URL, "Healthy" status, and NANO compute usually is — Railway's own Supabase
template, which deploys the full Supabase stack (Postgres, the Kong API
gateway, Auth/GoTrue, Storage, Realtime, Studio) as services inside your
Railway project rather than on supabase.com. Functionally it's the same
Postgres + Storage API your backend talks to; only where you find the
credentials differs.

1. Open the Railway project → the Supabase/Postgres service → **Variables**
   tab. You're looking for these (names vary slightly by template version —
   search for the value, not just the exact key name):
   - A Postgres connection string, often `DATABASE_URL` or assembled from
     `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_HOST` /
     `POSTGRES_DB` — this is your backend's `DATABASE_URL`.
   - The public API gateway URL (matches what's shown on the project
     overview page, e.g. `https://ronezbfegdpnsfvrawzk.supabase.co`) — this
     is `SUPABASE_URL`.
   - `SERVICE_ROLE_KEY` (sometimes `SUPABASE_SERVICE_ROLE_KEY`) — a long
     JWT. This is `SUPABASE_SERVICE_ROLE_KEY`. Treat it exactly like a
     database password: never put it in frontend code, never commit it.
   - `ANON_KEY` also exists but the backend doesn't use it — it's only for
     client-side (Supabase-JS/PostgREST) access, which this project doesn't
     use.
2. Run [`docs/schema.sql`](schema.sql) against that Postgres instance. Two
   ways to do this without ever installing anything locally:
   - Railway → the Postgres service → **Data** tab (or "Connect" → "psql")
     usually gives you a query console or a one-click `psql` session — paste
     the contents of `schema.sql` in.
   - Or, from anywhere with `psql` installed: `psql "<DATABASE_URL from
     step 1>" -f docs/schema.sql`.
3. Storage bucket: self-hosted Supabase's Storage service auto-creates
   buckets on first upload via the API in some template versions, but if
   yours doesn't, open Supabase Studio (Railway usually exposes it as its
   own service with its own URL) → Storage → New bucket, named to match
   `SUPABASE_STORAGE_BUCKET` (default `portfolio-files`), and leave it
   **private** for the same reason as the hosted setup above.
4. Everything from here on (Section 2 onward) is identical — the backend
   only ever talks to `DATABASE_URL` / `SUPABASE_URL` /
   `SUPABASE_SERVICE_ROLE_KEY`, and it doesn't care whether those point at
   supabase.com or a self-hosted instance.

## 2. Railway (backend)

1. Create a new Railway project from this repo, root directory `backend/`.
2. Set environment variables (Railway → Variables) from `backend/.env.example`:
   `SECRET_KEY`, `JWT_SECRET_KEY` (generate both with
   `python -c "import secrets; print(secrets.token_urlsafe(64))"`),
   `DATABASE_URL`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`,
   `SUPABASE_STORAGE_BUCKET`, `ADMIN_EMAIL`, `ADMIN_PASSWORD`,
   `ALLOWED_ORIGINS` (your deployed frontend's origin, e.g.
   `https://portfolio.yourdomain.com`), `FLASK_ENV=production`,
   `FORCE_HTTPS=true`, `RATELIMIT_STORAGE_URI` (use a Railway Redis add-on
   in production — `memory://` does not share state across workers/replicas).
3. Railway will detect `Procfile` and `requirements.txt` automatically
   (`web:` process runs gunicorn; `release:` runs `flask db upgrade` before
   each deploy — see note below on migrations).
4. First deploy only: after the app is up, run once (Railway → run a
   one-off command, or `railway run`):
   ```bash
   python scripts/seed_admin.py
   ```
   This is the *only* way an administrator account gets created — there is
   no signup endpoint. Rotate the password afterwards via
   `POST /api/auth/change-password` or `python scripts/seed_admin.py --reset-password`.
5. Confirm `GET https://<your-app>.up.railway.app/api/health` returns
   `{"status": "ok"}`.

**On migrations**: this repo ships `docs/schema.sql` as the source of truth
for the initial schema (already applied in step 1). Flask-Migrate/Alembic is
wired into the app (`app/extensions.py`, `Procfile`'s `release:` line) so
future schema changes can be tracked incrementally — the first time you add
or change a model locally (with real network access to install
`Flask-Migrate`), run:
```bash
flask db init          # once, creates backend/migrations/
flask db stamp head    # marks the schema.sql-created DB as the baseline
flask db migrate -m "describe the change"
flask db upgrade
```

## 3. Frontend (Flutter Web)

```bash
cd frontend
flutter build web --release --dart-define=API_BASE_URL=https://<your-railway-app>.up.railway.app/api
```

This produces `frontend/build/web/` — deploy that directory to any static
host. Two common options:

- **Railway (static site service)**: add a second Railway service pointing
  at `frontend/`, build command `flutter build web --release --dart-define=API_BASE_URL=$API_BASE_URL`,
  start command serving `build/web` (e.g. via a tiny static server).
- **Netlify/Vercel/Cloudflare Pages**: connect the repo, set the build
  command above, publish directory `frontend/build/web`, and set
  `API_BASE_URL` as a build-time environment variable substituted into the
  `--dart-define`.

Whichever origin you deploy the frontend to, add it to the backend's
`ALLOWED_ORIGINS` — CORS will otherwise block every request from the
deployed site.

## 4. Custom domain + HTTPS

Railway and most static hosts provision HTTPS automatically for custom
domains. Once both are on HTTPS, set `FORCE_HTTPS=true` on the backend (this
also enables HSTS via Flask-Talisman — see `app/__init__.py`).

## Rollback / redeploy notes

- The backend is stateless (all state lives in Supabase Postgres/Storage),
  so redeploying or rolling back a Railway deploy is safe at any time.
- Because there's no user-facing "undo" for deletes (Research/Publications/
  Projects/Blog/etc. `DELETE` endpoints are hard deletes), consider enabling
  Supabase's point-in-time recovery or scheduled backups before putting
  real content into the admin dashboard.
