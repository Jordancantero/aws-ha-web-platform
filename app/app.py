from flask import Flask, render_template, request, redirect
import psycopg2
import boto3
import json
import uuid
import logging
import os
from botocore.exceptions import ClientError
import traceback

app = Flask(__name__)


app.config["MAX_CONTENT_LENGTH"] = 10 * 1024 * 1024  # 10 MB upload limit

ALLOWED_EXTENSIONS = {"pdf", "png", "jpg", "jpeg", "gif", "docx", "xlsx", "txt", "csv"}

AWS_REGION = "us-east-1"
SECRET_NAME = "app-postgres-credentials"
S3_BUCKET = "aws-ha-taskmanager-files-jordan-v3"

if not SECRET_NAME:
    raise RuntimeError("Environment variable SECRET_NAME is not defined.")

if not S3_BUCKET:
    raise RuntimeError("Environment variable S3_BUCKET is not defined.")

# ==========================================================
# LOGGING
# ==========================================================

LOG_DIR = "/app/logs"
os.makedirs(LOG_DIR, exist_ok=True)


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(f"{LOG_DIR}/app.log"),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

# ==========================================================
# AWS CLIENTS
# ==========================================================

s3 = boto3.client(
    "s3",
    region_name=AWS_REGION
)

# ==========================================================
# SECRETS MANAGER
# ==========================================================

_db_secret = None


def get_secret():
    try:
        client = boto3.client(
            "secretsmanager",
            region_name=AWS_REGION
        )

        response = client.get_secret_value(
            SecretId=SECRET_NAME
        )

        logger.info("Database secret loaded successfully")

        return json.loads(response["SecretString"])

    except Exception as e:
        logger.error(f"Error loading secret: {e}")
        raise


def get_db_secret(refresh=False):
    """
    Cache the DB secret. Pass refresh=True to force a re-fetch,
    e.g. after a detected auth failure caused by secret rotation.
    """
    global _db_secret

    if _db_secret is None or refresh:
        _db_secret = get_secret()

    return _db_secret


# ==========================================================
# DATABASE
# ==========================================================

def get_connection():
    secret = get_db_secret()

    try:
        conn = psycopg2.connect(
            host=secret["host"],
            database=secret["database"],
            user=secret["username"],
            password=secret["password"],
            port=5432
        )

        logger.info("Connected to PostgreSQL")

        return conn

    except psycopg2.OperationalError as e:
        # If auth fails, the secret may have rotated — retry once with a fresh secret
        if "authentication failed" in str(e).lower():
            logger.warning("Auth failed, retrying with refreshed secret...")
            secret = get_db_secret(refresh=True)
            conn = psycopg2.connect(
                host=secret["host"],
                database=secret["database"],
                user=secret["username"],
                password=secret["password"],
                port=5432
            )
            logger.info("Connected to PostgreSQL (after secret refresh)")
            return conn

        logger.error(f"Database connection failed: {e}")
        raise


# ==========================================================
# INIT DATABASE
# ==========================================================

def init_db():
    conn = get_connection()
    cur = conn.cursor()

    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS tasks (
                id SERIAL PRIMARY KEY,
                title VARCHAR(255) NOT NULL,
                description TEXT,
                file_key TEXT
            )
        """)
        conn.commit()
        logger.info("Database initialized")

    except Exception as e:
        conn.rollback()
        logger.error(f"Failed to initialize database: {e}")
        raise

    finally:
        cur.close()
        conn.close()


# ==========================================================
# HELPERS
# ==========================================================

def allowed_file(filename):
    """Return True if the file extension is in the whitelist."""
    return (
        "." in filename
        and filename.rsplit(".", 1)[-1].lower() in ALLOWED_EXTENSIONS
    )


def generate_download_url(file_key):
    if not file_key:
        return None

    return s3.generate_presigned_url(
        ClientMethod="get_object",
        Params={
            "Bucket": S3_BUCKET,
            "Key": file_key
        },
        ExpiresIn=3600
    )


# ==========================================================
# HOME
# ==========================================================

@app.route("/")
def home():
    conn = None
    cur = None

    try:
        conn = get_connection()
        cur = conn.cursor()

        cur.execute("""
            SELECT id, title, description, file_key
            FROM tasks
            ORDER BY id DESC
        """)

        rows = cur.fetchall()

        tasks = []

        for row in rows:
            file_key = row[3]
            tasks.append({
                "id": row[0],
                "title": row[1],
                "description": row[2],
                "file_key": file_key,
                "file_url": generate_download_url(file_key)
            })

        logger.info(f"Loaded {len(tasks)} tasks")

        return render_template("index.html", tasks=tasks)

    except Exception as e:
        logger.error(f"Home page failed: {e}")
        return "An internal error occurred. Please try again later.", 500

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


# ==========================================================
# ADD TASK
# ==========================================================

@app.route("/add", methods=["POST"])
def add_task():
    logger.info("========== ADD TASK ==========")
    logger.info(f"Form: {request.form}")
    logger.info(f"Files: {request.files}")
    title = request.form.get("title", "").strip()
    description = request.form.get("description", "").strip()
    file = request.files.get("file")

    # --- Input validation ---
    if not title:
        return "Title is required.", 400

    if len(title) > 255:
        return "Title must be 255 characters or fewer.", 400

    file_key = None
    conn = None
    cur = None

    try:
        # --- File upload ---
        if file and file.filename:
            if not allowed_file(file.filename):
                return (
                    f"File type not allowed. Permitted types: "
                    f"{', '.join(sorted(ALLOWED_EXTENSIONS))}",
                    400
                )

            file_key = f"task-files/{uuid.uuid4()}-{file.filename}"

            s3.upload_fileobj(file, S3_BUCKET, file_key)

            logger.info(f"File uploaded to S3: {file_key}")

        # --- Database insert ---
        conn = get_connection()
        cur = conn.cursor()

        cur.execute("""
            INSERT INTO tasks (title, description, file_key)
            VALUES (%s, %s, %s)
        """, (title, description, file_key))

        conn.commit()

        logger.info(f"Task created: {title}")

        return redirect("/")

    except ClientError as e:
        logger.exception("AWS Error")
        logger.error(e.response)
        return str(e), 500

    except Exception as e:
        logger.exception("General Error")
        logger.error(traceback.format_exc())
        return str(e), 500

        # If the DB insert failed but the file was already uploaded, clean it up
        if file_key:
            try:
                s3.delete_object(Bucket=S3_BUCKET, Key=file_key)
                logger.info(f"Cleaned up orphaned S3 file: {file_key}")
            except Exception as s3_error:
                logger.error(f"Failed to clean up S3 file {file_key}: {s3_error}")

        return "An internal error occurred while creating the task.", 500

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


# ==========================================================
# DELETE TASK
# ==========================================================

@app.route("/delete/<int:task_id>", methods=["POST"])
def delete_task(task_id):
    conn = None
    cur = None

    try:
        conn = get_connection()
        cur = conn.cursor()

        cur.execute(
            "SELECT file_key FROM tasks WHERE id = %s",
            (task_id,)
        )

        row = cur.fetchone()

        if row is None:
            return "Task not found.", 404

        file_key = row[0]

        # Delete the DB record first so the task is gone even if S3 cleanup fails
        cur.execute(
            "DELETE FROM tasks WHERE id = %s",
            (task_id,)
        )

        conn.commit()

        logger.info(f"Task deleted: {task_id}")

        # Best-effort S3 cleanup after a successful DB delete
        if file_key:
            try:
                s3.delete_object(Bucket=S3_BUCKET, Key=file_key)
                logger.info(f"Deleted file from S3: {file_key}")
            except Exception as s3_error:
                logger.error(
                    f"S3 delete failed for {file_key} "
                    f"(task {task_id} was already removed from DB): {s3_error}"
                )

        return redirect("/")

    except Exception as e:
        logger.error(f"Error deleting task {task_id}: {e}")
        return "An internal error occurred while deleting the task.", 500

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


# ==========================================================
# HEALTH CHECK
# ==========================================================

@app.route("/health")
def health():
    return "OK", 200


# ==========================================================
# STARTUP
# ==========================================================

try:
    init_db()
    logger.info("Application started successfully")
except Exception as e:
    logger.critical(f"Application startup failed — aborting: {e}")
    raise SystemExit(1)


# ==========================================================
# RUN
# ==========================================================

if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5000
    )