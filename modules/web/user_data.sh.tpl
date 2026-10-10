#!/bin/bash
# Tier 1 bootstrap: nginx serves the frontend and proxies /api/ to the internal ALB
set -euxo pipefail

dnf install -y nginx

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
IID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Reverse proxy to the backend. The resolver line makes nginx re-resolve the
# ALB name, since ALB IP addresses change over time.
cat > /etc/nginx/default.d/api.conf <<'EOF'
location /api/ {
    resolver 169.254.169.253 valid=30s;
    set $app_alb http://${app_alb_dns};
    proxy_pass $app_alb;
    proxy_connect_timeout 5s;
    proxy_read_timeout 15s;
}
EOF

cat > /usr/share/nginx/html/index.html <<EOF
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>3-Tier Web App</title>
<style>
  body { font-family: system-ui, sans-serif; max-width: 720px; margin: 40px auto; padding: 0 16px; color: #1f2933; }
  .tier { border: 1px solid #cbd2d9; border-radius: 8px; padding: 12px 16px; margin: 12px 0; }
  .tier h2 { margin: 0 0 6px; font-size: 16px; }
  pre { background: #f5f7fa; padding: 12px; border-radius: 6px; overflow-x: auto; }
  button { padding: 8px 14px; font-size: 14px; cursor: pointer; }
</style>
</head>
<body>
<h1>3-Tier Web App on AWS</h1>
<div class="tier">
  <h2>Tier 1: Web (EC2, public subnet)</h2>
  Served by <b>$IID</b> in <b>$AZ</b>
</div>
<div class="tier">
  <h2>Tier 2 and 3: App (EC2, private subnet) and Database (RDS)</h2>
  <button onclick="callApi()">Call backend again</button>
  <pre id="out">Loading...</pre>
</div>
<script>
async function callApi() {
  const out = document.getElementById("out");
  out.textContent = "Loading...";
  try {
    const res = await fetch("/api/");
    out.textContent = JSON.stringify(await res.json(), null, 2);
  } catch (err) {
    out.textContent = "Error: " + err;
  }
}
callApi();
</script>
</body>
</html>
EOF

systemctl enable --now nginx
