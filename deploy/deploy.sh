#!/bin/bash
# =============================================================
# Deploy / Update Script — run this to push code updates
# Usage (from your local machine):
#   bash deploy/deploy.sh ubuntu@<EC2-PUBLIC-IP> <path-to-key.pem>
#
# Or run directly on the EC2 instance:
#   bash deploy.sh
# =============================================================

set -e

APP_DIR="/home/ubuntu/academic-analytics"
SERVICE_NAME="academic-analytics"

echo "[deploy] Copying latest files..."
cp -r ../backend "$APP_DIR/"
cp -r ../frontend "$APP_DIR/"

echo "[deploy] Installing/updating Python dependencies..."
cd "$APP_DIR/backend"
source venv/bin/activate
pip install -r requirements.txt
deactivate

echo "[deploy] Restarting service..."
sudo systemctl restart ${SERVICE_NAME}

echo "[deploy] Done. Status:"
sudo systemctl status ${SERVICE_NAME} --no-pager
