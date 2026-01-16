#!/usr/bin/env bash
# =====================================================
# Firosh LXC Creator - FINAL ULTIMATE FIX + SSH ACCESS
# =====================================================

TEMPLATE="local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
STORAGE="local-lvm"
BRIDGE="vmbr0"
DISK_SIZE="8"
MEMORY="1024"
CORE="1"

YW=$(echo -e "\033[33m")
GN=$(echo -e "\033[32m")
RD=$(echo -e "\033[31m")
CY=$(echo -e "\033[36m")
CL=$(echo -e "\033[m")

msg_info() {
  echo -e "${CY}➡️ $1${CL}"
}
msg_ok() {
  echo -e "${GN}✅ $1${CL}"
}

if [ -z "$1" ]; then
  echo -e "${CY}🧱 Crea container LXC Docker (Fix AppArmor Edition + SSH Access)${CL}\n"
  read -rp "Inserisci CTID: " CTID
  read -rp "Inserisci hostname: " HOSTNAME
  read -rp "Inserisci password root: " PASSWORD
else
  CTID=$1; HOSTNAME=$2; PASSWORD=$3
fi

HOSTNAME="${HOSTNAME//_/-}"

# --- Creazione container ---
msg_info "Creazione LXC CT${CTID}..."
pct create $CTID $TEMPLATE \
  --hostname "$HOSTNAME" \
  --storage $STORAGE \
  --rootfs ${STORAGE}:${DISK_SIZE} \
  --memory $MEMORY \
  --cores $CORE \
  --net0 name=eth0,bridge=${BRIDGE},ip=dhcp,type=veth \
  --password "$PASSWORD" \
  --features nesting=1 \
  --unprivileged 0 \
  --onboot 1

# --- FIX APPARMOR & SYSCTL (Il pezzo mancante) ---
msg_info "Rimozione restrizioni AppArmor..."
cat <> /etc/pve/lxc/${CTID}.conf <<EOF
lxc.apparmor.profile: unconfined
lxc.cgroup.devices.allow: a
lxc.cap.drop:
EOF
msg_ok "Configurazione di sicurezza sbloccata."

# --- Avvio ---
pct start $CTID
sleep 8

# --- Script interno ---
msg_info "Configurazione interna..."
cat < /tmp/setup.sh <<EOF
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y curl gnupg ca-certificates lsb-release apt-transport-https openssh-server >/dev/null 2>&1

# Enable SSH service
systemctl enable ssh
systemctl start ssh

# Configure SSH to allow root login with password
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH service to apply changes
systemctl restart ssh

# Docker install
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \$(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y docker-ce docker-ce-cli containerd.io >/dev/null 2>&1
sleep 5

# Add root user to docker group
usermod -aG docker root

# Portainer install
docker run -d -p 8000:8000 -p 9443:9443 --name=portainer --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
EOF

pct push $CTID /tmp/setup.sh /tmp/setup.sh -perms 755
pct exec $CTID -- bash /tmp/setup.sh

IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')
msg_ok "Setup completato!"
echo -e "${GN}Portainer attivo su:${CL} https://${IP}:9443"
echo -e "${GN}SSH accessibile su:${CL} ssh root@${IP}"
pct exec $CTID -- rm -f /tmp/setup.sh
