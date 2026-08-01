"""
WSGI entrypoint used by gunicorn in production (see Procfile) and by
`flask run` / `python wsgi.py` in local development.
"""
from app import create_app

app = create_app()

if __name__ == "__main__":
    app.run(debug=app.config.get("DEBUG", False))
