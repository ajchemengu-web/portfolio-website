"""
Password hashing and account lockout helpers.

Uses bcrypt (via the `bcrypt` package directly rather than passlib, which is
unmaintained) for password hashing. Includes a simple failed-login lockout
so the single admin account is not brute-forceable even if rate limiting at
the network layer is bypassed.
"""
from datetime import datetime, timedelta, timezone

import bcrypt

MAX_FAILED_ATTEMPTS = 5
LOCKOUT_DURATION = timedelta(minutes=15)


def hash_password(plain_password: str) -> str:
    if len(plain_password) < 12:
        raise ValueError("Password must be at least 12 characters long.")
    salt = bcrypt.gensalt(rounds=12)
    return bcrypt.hashpw(plain_password.encode("utf-8"), salt).decode("utf-8")


def verify_password(plain_password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(plain_password.encode("utf-8"), password_hash.encode("utf-8"))
    except (ValueError, TypeError):
        # Malformed hash — never let this raise into an auth bypass path.
        return False


def is_locked_out(admin) -> bool:
    if admin.locked_until is None:
        return False
    locked_until = admin.locked_until
    if locked_until.tzinfo is None:
        locked_until = locked_until.replace(tzinfo=timezone.utc)
    return locked_until > datetime.now(timezone.utc)


def register_failed_login(admin, db_session) -> None:
    admin.failed_login_attempts = (admin.failed_login_attempts or 0) + 1
    if admin.failed_login_attempts >= MAX_FAILED_ATTEMPTS:
        admin.locked_until = datetime.now(timezone.utc) + LOCKOUT_DURATION
        admin.failed_login_attempts = 0
    db_session.commit()


def register_successful_login(admin, db_session, ip_address: str | None) -> None:
    admin.failed_login_attempts = 0
    admin.locked_until = None
    admin.last_login_at = datetime.now(timezone.utc)
    admin.last_login_ip = ip_address
    db_session.commit()
