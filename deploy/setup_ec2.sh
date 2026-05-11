#!/bin/bash
# =============================================================
# EC2 Setup Script — Academic Analytics System
# Run this ONCE on a fresh Ubuntu 22.04 EC2 instance
# Usage: bash setup_ec2.sh
# =============================================================

set -e

APP_DIR="/home/ubuntu/academic-analytics"
SERVICE_NAME="academic-analytics"

echo "============================================"
echo "  Academic Analytics — EC2 Setup"
echo "============================================"

# -------------------------------------------------------------
# 1. System packages
# -------------------------------------------------------------
echo "[1/7] Updating system packages..."
sudo apt-get update -y
sudo apt-get install -y python3 python3-pip python3-venv nginx git

# -------------------------------------------------------------
# 2. Copy app files (assumes you already uploaded them)
# -------------------------------------------------------------
echo "[2/7] Preparing app directory..."
sudo mkdir -p "$APP_DIR"
sudo chown ubuntu:ubuntu "$APP_DIR"

# If running from the repo root, copy files
if [ -f "../backend/app.py" ]; then
    cp -r ../backend "$APP_DIR/"
    cp -r ../frontend "$APP_DIR/"
    echo "  Files copied from local repo."
else
    echo "  Skipping copy — files should already be in $APP_DIR"
fi

# -------------------------------------------------------------
# 3. Python virtual environment + dependencies
# -------------------------------------------------------------
echo "[3/7] Creating Python virtual environment..."
cd "$APP_DIR/backend"
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install gunicorn
deactivate

# Create required folders
mkdir -p "$APP_DIR/backend/uploads"
mkdir -p "$APP_DIR/backend/reports"

# -------------------------------------------------------------
# 4. Systemd service
# -------------------------------------------------------------
echo "[4/7] Creating systemd service..."
sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF
[Unit]
Description=Academic Analytics Flask App
After=network.target

[Service]
User=ubuntu
WorkingDirectory=${APP_DIR}/backend
Environment="PATH=${APP_DIR}/backend/venv/bin"
EnvironmentFile=${APP_DIR}/backend/.env
ExecStart=${APP_DIR}/backend/venv/bin/gunicorn \
    --workers 3 \
    --bind 127.0.0.1:5000 \
    --timeout 120 \
    --access-logfile /var/log/${SERVICE_NAME}/access.log \
    --error-logfile /var/log/${SERVICE_NAME}/error.log \
    app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Log directory
sudo mkdir -p /var/log/${SERVICE_NAME}
sudo chown ubuntu:ubuntu /var/log/${SERVICE_NAME}

sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}
sudo systemctl start ${SERVICE_NAME}

# -------------------------------------------------------------
# 5. Nginx config
# -------------------------------------------------------------
echo "[5/7] Configuring Nginx..."
sudo tee /etc/nginx/sites-available/${SERVICE_NAME} > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;          # replace with your domain or EC2 public IP

    client_max_body_size 20M;

    # Proxy all requests to Gunicorn
    location / {
        proxy_pass         http://127.0.0.1:5000;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
        proxy_send_timeout 120s;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/${SERVICE_NAME} \
            /etc/nginx/sites-enabled/${SERVICE_NAME}

# Remove default site if it exists
sudo rm -f /etc/nginx/sites-enabled/default

sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

# -------------------------------------------------------------
# 6. Firewall (ufw)
# -------------------------------------------------------------
echo "[6/7] Configuring firewall..."
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# -------------------------------------------------------------
# 7. Done
# -------------------------------------------------------------
echo ""
echo "============================================"
echo "  Setup complete!"
echo "============================================"
echo ""
echo "  App running at:  http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo ""
echo "  Useful commands:"
echo "    sudo systemctl status ${SERVICE_NAME}   # check app status"
echo "    sudo systemctl restart ${SERVICE_NAME}  # restart app"
echo "    sudo journalctl -u ${SERVICE_NAME} -f   # live logs"
echo "    sudo tail -f /var/log/${SERVICE_NAME}/error.log"
echo ""
