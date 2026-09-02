from datetime import datetime

from flask import render_template, request, redirect, url_for, session
from werkzeug.security import generate_password_hash, check_password_hash

from app import app, db
from app.models import User, Job


@app.route("/")
def home():
    return render_template("login.html")


@app.route("/register", methods=["GET", "POST"])
def register():

    if request.method == "POST":

        name = request.form["name"].strip()
        email = request.form["email"].strip().lower()
        password = request.form["password"]

        existing_user = User.query.filter_by(email=email).first()

        if existing_user:
            return "Email already registered. Please use another email."

        hashed_password = generate_password_hash(password)

        user = User(
            name=name,
            email=email,
            password=hashed_password
        )

        db.session.add(user)
        db.session.commit()

        return redirect(url_for("home"))

    return render_template("register.html")


@app.route("/login", methods=["POST"])
def login():

    email = request.form["email"].strip().lower()
    password = request.form["password"]

    user = User.query.filter_by(email=email).first()

    if user and check_password_hash(user.password, password):

        session["user_id"] = user.id
        session["user_name"] = user.name

        return redirect(url_for("dashboard"))

    return "Invalid email or password."


@app.route("/dashboard")
def dashboard():

    if "user_id" not in session:
        return redirect(url_for("home"))

    user = db.session.get(User, session["user_id"])

    if not user:
        session.clear()
        return redirect(url_for("home"))

    search = request.args.get("search", "").strip()
    status_filter = request.args.get("status", "").strip()

    query = Job.query.filter_by(
        user_id=user.id
    )

    if search:

        query = query.filter(
            db.or_(
                Job.company.ilike(f"%{search}%"),
                Job.role.ilike(f"%{search}%")
            )
        )

    if status_filter:

        query = query.filter_by(
            status=status_filter
        )

    jobs = query.order_by(
        Job.created_at.desc()
    ).all()

    total_jobs = Job.query.filter_by(
        user_id=user.id
    ).count()

    interview_jobs = Job.query.filter_by(
        user_id=user.id,
        status="Interview"
    ).count()

    offer_jobs = Job.query.filter_by(
        user_id=user.id,
        status="Offer"
    ).count()

    return render_template(
        "dashboard.html",
        user=user,
        jobs=jobs,
        total_jobs=total_jobs,
        interview_jobs=interview_jobs,
        offer_jobs=offer_jobs,
        search=search,
        status_filter=status_filter
    )


@app.route("/logout")
def logout():

    session.clear()

    return redirect(url_for("home"))


@app.route("/add-job", methods=["GET", "POST"])
def add_job():

    if "user_id" not in session:
        return redirect(url_for("home"))

    if request.method == "POST":

        company = request.form["company"].strip()
        role = request.form["role"].strip()

        location = request.form.get(
            "location",
            ""
        ).strip()

        job_type = request.form.get(
            "job_type",
            ""
        ).strip()

        application_date_text = request.form.get(
            "application_date",
            ""
        ).strip()

        job_url = request.form.get(
            "job_url",
            ""
        ).strip()

        salary = request.form.get(
            "salary",
            ""
        ).strip()

        status = request.form["status"]

        notes = request.form.get(
            "notes",
            ""
        ).strip()

        application_date = None

        if application_date_text:

            application_date = datetime.strptime(
                application_date_text,
                "%Y-%m-%d"
            ).date()

        job = Job(
            company=company,
            role=role,
            location=location,
            job_type=job_type,
            application_date=application_date,
            job_url=job_url,
            salary=salary,
            status=status,
            notes=notes,
            user_id=session["user_id"]
        )

        db.session.add(job)
        db.session.commit()

        return redirect(url_for("dashboard"))

    return render_template("add_job.html")


@app.route("/edit-job/<int:job_id>", methods=["GET", "POST"])
def edit_job(job_id):

    if "user_id" not in session:
        return redirect(url_for("home"))

    job = Job.query.filter_by(
        id=job_id,
        user_id=session["user_id"]
    ).first_or_404()

    if request.method == "POST":

        job.company = request.form["company"].strip()

        job.role = request.form["role"].strip()

        job.location = request.form.get(
            "location",
            ""
        ).strip()

        job.job_type = request.form.get(
            "job_type",
            ""
        ).strip()

        application_date_text = request.form.get(
            "application_date",
            ""
        ).strip()

        if application_date_text:

            job.application_date = datetime.strptime(
                application_date_text,
                "%Y-%m-%d"
            ).date()

        else:

            job.application_date = None

        job.job_url = request.form.get(
            "job_url",
            ""
        ).strip()

        job.salary = request.form.get(
            "salary",
            ""
        ).strip()

        job.status = request.form["status"]

        job.notes = request.form.get(
            "notes",
            ""
        ).strip()

        db.session.commit()

        return redirect(url_for("dashboard"))

    return render_template(
        "edit_job.html",
        job=job
    )


@app.route("/delete-job/<int:job_id>", methods=["POST"])
def delete_job(job_id):

    if "user_id" not in session:
        return redirect(url_for("home"))

    job = Job.query.filter_by(
        id=job_id,
        user_id=session["user_id"]
    ).first_or_404()

    db.session.delete(job)

    db.session.commit()

    return redirect(url_for("dashboard"))