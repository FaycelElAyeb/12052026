# Deploy to AWS EC2

## Prerequisites

- An EC2 instance running **Ubuntu 22.04 LTS**
- Instance type: `t3.small` or larger (t3.micro works for testing)
- Security Group inbound rules:
  - Port **22** (SSH) — your IP
  - Port **80** (HTTP) — 0.0.0.0/0
  - Port **443** (HTTPS) — 0.0.0.0/0 *(optional, for SSL later)*
- A `.pem` key pair downloaded

---

## Step 1 — Launch EC2

1. Go to AWS Console → EC2 → Launch Instance
2. Choose **Ubuntu Server 22.04 LTS**
3. Instance type: `t3.small` (recommended)
4. Create or select a key pair → download `.pem`
5. Security group: allow ports 22, 80, 443
6. Launch

---

## Step 2 — Upload your project

From your local machine (Windows Git Bash or WSL):

```bash
# Replace with your actual key path and EC2 IP
KEY="C:/Users/YourName/Downloads/your-key.pem"
EC2="ubuntu@<EC2-PUBLIC-IP>"

# Fix key permissions (required on Linux/Mac, skip on Windows)
chmod 400 "$KEY"

# Upload the entire project
scp -i "$KEY" -r ./backend ./frontend ./deploy "$EC2:/home/ubuntu/academic-analytics/"
```

Or using **WinSCP** (GUI):
- Host: your EC2 public IP
- Username: `ubuntu`
- Private key: your `.pem` file (convert to `.ppk` with PuTTYgen if needed)
- Upload the `backend/`, `frontend/`, and `deploy/` folders to `/home/ubuntu/academic-analytics/`

---

## Step 3 — Run setup on EC2

SSH into your instance:

```bash
ssh -i "your-key.pem" ubuntu@<EC2-PUBLIC-IP>
```

Then run the setup script:

```bash
cd /home/ubuntu/academic-analytics/deploy
chmod +x setup_ec2.sh
bash setup_ec2.sh
```

This will:
- Install Python 3, pip, Nginx
- Create a Python virtual environment
- Install all dependencies + Gunicorn
- Register a systemd service (auto-starts on reboot)
- Configure Nginx as a reverse proxy on port 80

---

## Step 4 — Configure email (optional)

Edit the `.env` file on the server:

```bash
nano /home/ubuntu/academic-analytics/backend/.env
```

Update `MAIL_SENDER` and `MAIL_PASSWORD` with your Gmail app password.

Then restart:

```bash
sudo systemctl restart academic-analytics
```

---

## Step 5 — Access the app

Open your browser:

```
http://<EC2-PUBLIC-IP>
```

Login with:
- Username: `Admin`
- Password: `1447`

---

## Useful commands

```bash
# Check app status
sudo systemctl status academic-analytics

# View live logs
sudo journalctl -u academic-analytics -f

# View error logs
sudo tail -f /var/log/academic-analytics/error.log

# Restart app
sudo systemctl restart academic-analytics

# Restart Nginx
sudo systemctl restart nginx
```

---

## Updating the app

After making changes locally, re-upload the changed files and restart:

```bash
# On EC2
cd /home/ubuntu/academic-analytics/deploy
bash deploy.sh
```

---

## Optional: Add a domain + HTTPS (SSL)

If you have a domain name pointing to your EC2 IP:

```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d yourdomain.com
```

Certbot will auto-configure Nginx for HTTPS and set up auto-renewal.

---

## Architecture

```
Browser
  │
  ▼ port 80
Nginx  (reverse proxy)
  │
  ▼ port 5000 (localhost only)
Gunicorn  (WSGI server, 3 workers)
  │
  ▼
Flask app  (app.py)
  ├── serves frontend/  (HTML, CSS, JS)
  └── /api/*  (analyze, download-report, send-email)
```
