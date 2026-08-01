"""
One-time provisioning script for the single administrator account.

Usage:
    cd backend
    python scripts/seed_admin.py

Reads ADMIN_EMAIL / ADMIN_PASSWORD from the environment (.env in dev,
Railway variables in prod). Refuses to run if an admin already exists,
since the PRD requires exactly one administrator — use
`python scripts/seed_admin.py --reset-password` to rotate the password of
the existing account instead of creating a second one.
"""
import argparse
import sys

sys.path.insert(0, ".")

from app import create_app  # noqa: E402
from app.extensions import db  # noqa: E402
from app.models import Admin  # noqa: E402
from app.utils.security import hash_password  # noqa: E402


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--reset-password", action="store_true",
                         help="Update the password of the existing admin instead of creating one.")
    args = parser.parse_args()

    app = create_app()
    with app.app_context():
        email = app.config["ADMIN_EMAIL"]
        password = app.config["ADMIN_PASSWORD"]
        if not email or not password:
            print("ADMIN_EMAIL and ADMIN_PASSWORD must be set in the environment.")
            sys.exit(1)

        existing = Admin.query.first()

        if existing and not args.reset_password:
            print(f"An administrator account already exists ({existing.email}). "
                  f"Re-run with --reset-password to rotate its password instead.")
            sys.exit(1)

        if existing and args.reset_password:
            existing.password_hash = hash_password(password)
            db.session.commit()
            print(f"Password updated for {existing.email}.")
            return

        admin = Admin(email=email.strip().lower(), password_hash=hash_password(password))
        db.session.add(admin)
        db.session.commit()
        print(f"Administrator account created for {admin.email}.")


if __name__ == "__main__":
    main()
