#!/usr/bin/env bash

# 1. Define Container Settings
CTID=300 # Change to your preferred ID
TEMPLATE="debian-12-standard_12.2-1_amd64.tar.zst"
CT_NAME="jd2-pia-container"

echo "--> Creating LXC container $CTID..."

# 2. Create the LXC container
pct create $CTID local:vztmpl/$TEMPLATE \
  --hostname $CT_NAME \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --ostype debian \
  --cores 1 \
  --memory 1024 \
  --rootfs local-lvm:4

# 3. Start the container
pct start $CTID

# 4. Inject and run your installation script inside the container
echo "--> Installing JD2 and PIA inside the container..."
pct exec $CTID -- bash -c "$(curl -fsSL https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/bootstrap/jd2-pia.sh)"

echo "--> Done! Your container $CTID is ready."
