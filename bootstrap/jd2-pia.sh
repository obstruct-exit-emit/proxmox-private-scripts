#!/usr/bin/env bash

# Header matching your standard format
echo "--> Starting Bootstrap for JDownloader2 and PIA..."

# Ensure we are running as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root"
  exit
fi

# 1. Setup JDownloader2
echo "--> Installing JDownloader2..."
apt-get update -y && apt-get install -y openjdk-17-jre-headless
useradd -r -m -d /opt/jdownloader2 -s /usr/sbin/nologin jd2
wget -qO /opt/jdownloader2/JDownloader.jar http://installer.jdownloader.org/JDownloader.jar
chown -R jd2:jd2 /opt/jdownloader2

# 2. Setup PIA Headless
echo "--> Installing PIA..."
wget -qO /tmp/pia-linux.run "https://www.privateinternetaccess.com/installer/download_installer_linux"
chmod +x /tmp/pia-linux.run
/tmp/pia-linux.run --accept

# 3. Create Systemd Service for JD2
cat << 'EOF' > /etc/systemd/system/jdownloader2.service
[Unit]
Description=JDownloader2 Headless
After=network-online.target

[Service]
User=jd2
WorkingDirectory=/opt/jdownloader2
ExecStart=/usr/bin/java -jar /opt/jdownloader2/JDownloader.jar -norestart
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now jdownloader2.service

echo "--> Bootstrap Complete."
