from flask import Flask
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)

app.secret_key = "jobtrack-development-secret-key"

app.config["SQLALCHEMY_DATABASE_URI"] = (
    "postgresql+psycopg2://postgres@localhost:5432/jobtrack"
)

app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)

from app import routes
from app.models import User

with app.app_context():
    db.create_all()