# Security Notes

Maps every item in the PRD's Security section to how it's implemented, plus
the tradeoffs and follow-ups a reviewer should know about before this goes
live with real content.

## PRD requirement → implementation

| Requirement | Implementation |
|---|---|
| HTTPS only | `FORCE_HTTPS` env flag → Flask-Talisman enforces HTTPS + HSTS in production (`backend/app/__init__.py`). Off by default for local dev over plain HTTP. |
| JWT Authentication | `flask-jwt-extended`, bearer tokens only (never cookies — see `JWT_TOKEN_LOCATION = ["headers"]` in `config.py`), 30-min access / 7-day refresh tokens, explicit logout via a revoked-token blocklist (`RevokedToken` model). |
| Role-based authorization | Single-administrator model by design (PRD explicitly forbids multiple admins/self-registration) — presence of a valid JWT *is* the authorization check (`app/utils/decorators.py::admin_required`). There is no admin/superadmin distinction to get wrong. |
| Hashed passwords | `bcrypt`, cost factor 12, minimum 12-character password enforced at hash time (`app/utils/security.py`). |
| CSRF protection | Not needed in the traditional sense: the API only accepts bearer tokens from the `Authorization` header, never from cookies, so there's no ambient credential for a cross-site request to ride on. CORS (`Flask-CORS`, `ALLOWED_ORIGINS`) further restricts which origins can even complete a request. |
| Rate limiting | `Flask-Limiter` on login (5/min, 20/hour), password change (5/hour), contact form (5/min, 20/day), file upload (20/hour), token refresh (30/hour). **Uses `memory://` storage by default — see "Before going live" below.** |
| Input validation | Every mutating endpoint validates the request body through a Marshmallow schema (`app/schemas.py`) before it touches the database — unknown fields rejected, types/lengths/enums enforced. |
| SQL injection protection | SQLAlchemy ORM with parameterised queries throughout; no raw SQL string interpolation anywhere in `app/api/`. |
| Secure file uploads | `app/api/uploads.py`: extension allow-list, magic-byte MIME sniffing (`python-magic`, not the client-supplied `Content-Type`), random UUID storage filenames (prevents path traversal / overwrite), `MAX_CONTENT_LENGTH` enforced by Flask before the body is fully read. |
| File type validation | Same as above — both extension *and* actual file content are checked; either failing rejects the upload. |
| Session timeout | 30-minute access tokens force re-authentication (via refresh) regularly; failed-login lockout (5 attempts → 15-minute lock) throttles brute force independent of the network-layer rate limit. |
| Admin audit log | `AuditLog` model + `@audit(...)` decorator, applied to every create/update/delete/publish/archive admin endpoint (`app/utils/decorators.py`). Viewable at `GET /api/admin/activity`. |

## Additional hardening already in place (beyond the PRD checklist)

- **Row Level Security on Supabase**: `docs/schema.sql` enables RLS on every
  table with zero policies, so Supabase's own auto-generated PostgREST/
  GraphQL API denies all access by default — a common gap when people
  assume "only my backend talks to Postgres" without realizing Supabase
  exposes the database directly unless RLS is explicitly locked down.
- **Security headers**: Flask-Talisman sets a Content-Security-Policy
  (`default-src 'self'`, no framing via `frame-ancestors 'none'`),
  `X-Content-Type-Options`, `Referrer-Policy: strict-origin-when-cross-origin`.
- **Generic error responses**: 500 handlers never leak stack traces;
  login failures return an identical message whether the email exists or
  not (no account-enumeration signal).
- **Signed, time-limited download URLs**: `view_only`/`private` files are
  never given a permanent public link — `create_signed_url(...)` mints a
  5-minute URL per request, checked against the visibility flag server-side
  every time.

## Known tradeoffs (read before shipping real content)

1. **Admin JWT stored in browser storage (web).** `flutter_secure_storage`
   on Flutter Web is backed by `window.localStorage`. This is the standard
   approach for a JWT-authenticated single-page app without a
   backend-for-frontend/cookie session layer, but it means a successful XSS
   against the admin dashboard could exfiltrate the access token (mitigated
   by its 30-minute lifetime, but not eliminated). If this ever needs to be
   hardened further, the standard fix is moving to httpOnly, `SameSite=Strict`
   cookies issued by a small backend-for-frontend layer — a larger change
   than this scaffold takes on.
2. **Rate limiter defaults to in-memory storage.** `RATELIMIT_STORAGE_URI=memory://`
   only works correctly with a single backend process/worker; Railway can
   scale to multiple instances, and gunicorn here runs 3 workers by default
   (`Procfile`), each with its *own* counter. **Before production traffic**,
   point `RATELIMIT_STORAGE_URI` at a shared store (Railway's Redis add-on:
   `redis://...`) so limits are enforced globally, not per-worker.
3. **Hard deletes, no soft-delete/undo.** Every admin `DELETE` endpoint
   permanently removes the row (and, for files, the Storage object). Enable
   Supabase point-in-time recovery or scheduled backups before trusting the
   dashboard with irreplaceable content.
4. **No 2FA yet.** The PRD lists this as "optional future support" — the
   `Admin` model already has `totp_secret`/`is_2fa_enabled` columns reserved
   for it, but the enrollment/verification flow isn't built.
5. **CORS origin list must be kept current.** `ALLOWED_ORIGINS` is an
   explicit allow-list (`backend/.env`) — remember to add every real
   frontend domain (including any preview/staging domains) or the frontend
   will get CORS errors that look like a backend outage.

## Before going live — checklist

- [ ] Generate fresh, unique `SECRET_KEY` / `JWT_SECRET_KEY` for production (never reuse the local dev values).
- [ ] Set a strong, unique `ADMIN_PASSWORD`, seed it, then rotate it once (`--reset-password`) so it never sat in shell history/CI logs for long.
- [ ] Point `RATELIMIT_STORAGE_URI` at Redis, not `memory://`.
- [ ] Set `FORCE_HTTPS=true` once real HTTPS domains are in place.
- [ ] Confirm `ALLOWED_ORIGINS` lists only real, intended frontend origins.
- [ ] Enable Supabase backups / point-in-time recovery.
- [ ] Run `pytest` (backend) and `flutter analyze` (frontend) in an environment with real network access — neither has been executed yet (see root README's "A note on how this was built").
