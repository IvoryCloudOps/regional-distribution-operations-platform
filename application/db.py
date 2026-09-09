"""
Database access layer for the Regional Distribution Operations Platform.

Credentials are never hardcoded. At runtime the app reads the ARN of the
RDS-managed master secret (created by Terraform via
`manage_master_user_password = true`) from the DB_SECRET_ARN environment
variable and retrieves username/password from AWS Secrets Manager using the
EC2 instance's IAM role (no static AWS credentials). The RDS-managed secret
only contains username/password (not host/port), so the (non-sensitive)
endpoint is passed separately via DB_HOST/DB_PORT environment variables.
"""

import json
import logging
import os
import time
from contextlib import contextmanager

import boto3
import pymysql
import pymysql.cursors

logger = logging.getLogger("distribution_app.db")

AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
DB_SECRET_ARN = os.environ.get("DB_SECRET_ARN", "")
DB_NAME = os.environ.get("DB_NAME", "distributiondb")
DB_HOST = os.environ.get("DB_HOST", "")
DB_PORT = int(os.environ.get("DB_PORT", "3306"))
DB_CONNECT_TIMEOUT = int(os.environ.get("DB_CONNECT_TIMEOUT", "5"))

_secret_cache = {"value": None, "fetched_at": 0}
_SECRET_TTL_SECONDS = 3600

_secrets_client = boto3.client("secretsmanager", region_name=AWS_REGION)


def _fetch_secret(force=False):
    now = time.time()
    if not force and _secret_cache["value"] and (now - _secret_cache["fetched_at"] < _SECRET_TTL_SECONDS):
        return _secret_cache["value"]

    if not DB_SECRET_ARN:
        raise RuntimeError("DB_SECRET_ARN environment variable is not set")

    response = _secrets_client.get_secret_value(SecretId=DB_SECRET_ARN)
    secret = json.loads(response["SecretString"])
    _secret_cache["value"] = secret
    _secret_cache["fetched_at"] = now
    logger.info("Retrieved database credentials from Secrets Manager")
    return secret


@contextmanager
def get_connection():
    """Yield a short-lived PyMySQL connection using credentials from Secrets Manager."""
    secret = _fetch_secret()
    try:
        conn = pymysql.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=secret["username"],
            password=secret["password"],
            database=DB_NAME,
            connect_timeout=DB_CONNECT_TIMEOUT,
            cursorclass=pymysql.cursors.DictCursor,
            autocommit=True,
        )
    except pymysql.err.OperationalError:
        # Credentials may have rotated; refresh once and retry.
        logger.warning("DB connection failed, refreshing secret and retrying once")
        secret = _fetch_secret(force=True)
        conn = pymysql.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=secret["username"],
            password=secret["password"],
            database=DB_NAME,
            connect_timeout=DB_CONNECT_TIMEOUT,
            cursorclass=pymysql.cursors.DictCursor,
            autocommit=True,
        )
    try:
        yield conn
    finally:
        conn.close()


def query(sql, params=None):
    """Run a SELECT and return a list of dict rows."""
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(sql, params or ())
            return cursor.fetchall()


def query_one(sql, params=None):
    rows = query(sql, params)
    return rows[0] if rows else None


def execute(sql, params=None):
    """Run an INSERT/UPDATE/DELETE and return the last inserted row id."""
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(sql, params or ())
            return cursor.lastrowid


@contextmanager
def transaction():
    """Yield a connection with autocommit disabled for multi-statement writes."""
    secret = _fetch_secret()
    conn = pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=secret["username"],
        password=secret["password"],
        database=DB_NAME,
        connect_timeout=DB_CONNECT_TIMEOUT,
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=False,
    )
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def check_health():
    """Used by the optional /health/db endpoint. Returns (ok, message)."""
    try:
        with get_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("SELECT 1")
                cursor.fetchone()
        return True, "database reachable"
    except Exception as exc:  # noqa: BLE001 - surface any failure reason to the caller
        logger.error("Database health check failed: %s", exc)
        return False, str(exc)
