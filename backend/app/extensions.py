"""
Shared Flask extension instances.

Instantiated here (unbound) and initialised against the app inside the
application factory in app/__init__.py — the standard pattern that avoids
circular imports between models, blueprints, and the app itself.
"""
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_migrate import Migrate
from flask_sqlalchemy import SQLAlchemy
from flask_talisman import Talisman

db = SQLAlchemy()
migrate = Migrate()
jwt = JWTManager()
cors = CORS()
talisman = Talisman()
limiter = Limiter(key_func=get_remote_address)
