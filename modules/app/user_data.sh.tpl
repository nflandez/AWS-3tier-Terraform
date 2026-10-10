#!/bin/bash
# Tier 2 bootstrap: install Python deps and run the API as a systemd service
set -euxo pipefail

dnf install -y python3-pip
pip3 install pymysql boto3

mkdir -p /opt/app
cat > /opt/app/app.py <<'PYEOF'
${app_py}
PYEOF

cat > /etc/systemd/system/app.service <<'EOF'
[Unit]
Description=3-tier backend API
After=network-online.target
Wants=network-online.target

[Service]
Environment=AWS_REGION=${region}
Environment=DB_HOST=${db_host}
Environment=DB_NAME=${db_name}
Environment=DB_SECRET_ARN=${db_secret_arn}
ExecStart=/usr/bin/python3 /opt/app/app.py
Restart=always
User=nobody

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now app
