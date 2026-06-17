#!/usr/bin/env bash

echo "G'day! Bootstrapping PIA and JDownloader2..."

# 1. Update system and grab essential packages
echo "--> Installing prerequisites (Java, wget, curl, ufw)..."
apt-get update -y
apt-get install -y wget curl openjdk-17-jre-headless ufw

# 2. Set up dedicated user for JDownloader to keep things tidy
echo "--> Creating dedicated jd2 user..."
useradd -r -m -d /opt/jdownloader2 -s /usr/sbin/nologin jd2

# 3. Fetch JDownloader2
echo "--> Fetching JDownloader2..."
wget -qO /opt/jdownloader2/JDownloader.jar http://installer.jdownloader.org/JDownloader.jar
chown -R jd2:jd2 /opt/jdownloader2

# 4. Create systemd service for JDownloader2
echo "--> Creating systemd service for JDownloader2..."
cat << 'EOF' > /etc/systemd/system/jdownloader2.service
[Unit]
Description=JDownloader2 Headless Service
Wants=network-online.target
After=network-online.target

[Service]
User=jd2
Group=jd2
WorkingDirectory=/opt/jdownloader2
ExecStart=/usr/bin/java -jar /opt/jdownloader2/JDownloader.jar -norestart
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable jdownloader2.service
systemctl start jdownloader2.service

# 5. Fetch the PIA Installer
echo "--> Fetching the Private Internet Access CLI installer..."
wget -qO /tmp/pia-linux.run "https://www.privateinternetaccess.com/installer/download_installer_linux"
chmod +x /tmp/pia-linux.run

# 6. Install PIA Headless
echo "--> Installing PIA..."
# The --accept flag bypasses the EULA prompt for a silent install
/tmp/pia-linux.run --accept

echo "Bloody brilliant! The groundwork is laid."
