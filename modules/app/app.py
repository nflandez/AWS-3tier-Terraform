"""Tier 2 backend API.

Endpoints (reached through the internal ALB):
  GET /api/health  -> liveness check for the ALB (does not touch the DB)
  GET /api/        -> records a visit in RDS and returns details from all tiers
"""
import json
import os
import socket
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import boto3
import pymysql

REGION = os.environ["AWS_REGION"]
SECRET_ARN = os.environ["DB_SECRET_ARN"]
DB_HOST = os.environ["DB_HOST"]
DB_NAME = os.environ["DB_NAME"]

secrets = boto3.client("secretsmanager", region_name=REGION)


def instance_info():
    """Return (instance-id, AZ) from the metadata service using IMDSv2."""
    try:
        token_req = urllib.request.Request(
            "http://169.254.169.254/latest/api/token",
            method="PUT",
            headers={"X-aws-ec2-metadata-token-ttl-seconds": "300"},
        )
        token = urllib.request.urlopen(token_req, timeout=2).read().decode()

        def meta(path):
            req = urllib.request.Request(
                "http://169.254.169.254/latest/meta-data/" + path,
                headers={"X-aws-ec2-metadata-token": token},
            )
            return urllib.request.urlopen(req, timeout=2).read().decode()

        return meta("instance-id"), meta("placement/availability-zone")
    except Exception:
        return socket.gethostname(), "unknown"


INSTANCE_ID, AZ = instance_info()


def db_connect():
    # Credentials are fetched from Secrets Manager on each connection, so a
    # password rotation is picked up without redeploying anything.
    secret = json.loads(secrets.get_secret_value(SecretId=SECRET_ARN)["SecretString"])
    return pymysql.connect(
        host=DB_HOST,
        user=secret["username"],
        password=secret["password"],
        database=DB_NAME,
        connect_timeout=5,
    )


def record_visit():
    conn = db_connect()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "CREATE TABLE IF NOT EXISTS visits ("
                " id INT AUTO_INCREMENT PRIMARY KEY,"
                " served_by VARCHAR(64) NOT NULL,"
                " created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)"
            )
            cur.execute("INSERT INTO visits (served_by) VALUES (%s)", (INSTANCE_ID,))
            conn.commit()
            cur.execute("SELECT COUNT(*), NOW(), VERSION() FROM visits")
            count, now, version = cur.fetchone()
        return {"status": "connected", "total_visits": count,
                "db_time": str(now), "mysql_version": version, "host": DB_HOST}
    finally:
        conn.close()


class Handler(BaseHTTPRequestHandler):
    def send_json(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path.startswith("/api/health"):
            self.send_json(200, {"status": "ok"})
            return
        if self.path in ("/api", "/api/"):
            body = {"tier": "app", "instance_id": INSTANCE_ID, "availability_zone": AZ}
            try:
                body["database"] = record_visit()
                self.send_json(200, body)
            except Exception as exc:
                body["database"] = {"status": "error", "error": str(exc)}
                self.send_json(500, body)
            return
        self.send_json(404, {"error": "not found"})

    def log_message(self, fmt, *args):
        pass  # keep the journal quiet; ALB health checks hit this every few seconds


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
