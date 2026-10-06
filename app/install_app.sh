#!/usr/bin/env bash
# CSYE 6225 - Assignment 4
#
# This script is provided complete. Your Packer template should copy the
# app/ directory to the instance (via a "file" provisioner) and then run
# this script (via a "shell" provisioner) to install and enable it as a
# systemd service.
#
# This script assumes the app/ directory has already been copied to
# /tmp/app on the instance before this script runs.

set -e

echo "==> Installing dependencies"
sudo apt-get update
sudo apt-get install -y python3-pip

echo "==> Installing application"
sudo mkdir -p /opt/prompt-optimizer
sudo cp -r /tmp/app/* /opt/prompt-optimizer/
# Ubuntu 22.04's stock pip3 (~22.0.2) predates PEP 668 and does not recognize
# --break-system-packages - it would error with "no such option" if we passed
# it unconditionally. Try the plain install first (works on 22.04); fall back
# to --break-system-packages only if pip actually complains about an
# externally-managed environment (e.g. if this is ever run on a newer base
# image such as Ubuntu 24.04).
sudo pip3 install -r /opt/prompt-optimizer/requirements.txt \
  || sudo pip3 install --break-system-packages -r /opt/prompt-optimizer/requirements.txt

echo "==> Creating systemd service"
sudo tee /etc/systemd/system/prompt-optimizer.service > /dev/null << 'EOF'
[Unit]
Description=Prompt Optimizer API
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/prompt-optimizer/server.py
Restart=on-failure
User=root
WorkingDirectory=/opt/prompt-optimizer

[Install]
WantedBy=multi-user.target
EOF

echo "==> Enabling service"
sudo systemctl daemon-reload
sudo systemctl enable prompt-optimizer.service

echo "==> Done. The service will start automatically on instance boot."
