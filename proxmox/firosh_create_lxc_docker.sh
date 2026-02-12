!/usr/bin/env bash
# =====================================================
# Firosh LXC Creator - FINAL ULTIMATE FIX + SSH
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

msg_info() { echo -e "${CY}➡️  $1${CL}"; }
msg_ok()   { echo -e "${GN}✅ $1${CL}"; }

if [ -z "$1" ]; then
  echo -e "${CY}🧱 Crea container LXC Docker (Fix AppArmor + SSH)${CL}\n"
  read -rp "Inserisci CTID: " CTID
  read -rp "Inserisci hostname: " HOSTNAME
  read -rp "Inserisci password root: " PASSWORD
else
  CTID=$1; HOSTNAME=$2; PASSWORD=$3
fi

HOSTNAME="${HOSTNAME//_/-}"

# --- Creazione container ---
msg_info "Creazione LXC CT${CTID} ($HOSTNAME)..."
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

# --- FIX APPARMOR (Essenziale per Docker) ---
msg_info "Sblocco restrizioni AppArmor..."
cat <<EOF >> /etc/pve/lxc/${CTID}.conf
lxc.apparmor.profile: unconfined
lxc.cgroup.devices.allow: a
lxc.cap.drop:
EOF

# --- Avvio ---
pct start $CTID
sleep 8

# --- Script interno di installazione ---
msg_info "Configurazione interna (SSH + Docker + Portainer)..."
cat <<EOF > /tmp/setup.sh
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# Update e installazione pacchetti base
apt-get update -qq
apt-get install -y openssh-server curl gnupg ca-certificates lsb-release apt-transport-https >/dev/null 2>&1

# =====================
# SSH root login (IL FIX)
# =====================
mkdir -p /var/run/sshd
echo "root:${PASSWORD}" | chpasswd
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh >/dev/null 2>&1

# =====================
# Docker install
# =====================
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \$(lsb_relea>
apt-get update -qq
apt-get install -y docker-ce docker-ce-cli containerd.io >/dev/null 2>&1

sleep 5
# =====================
# Portainer install
# =====================
docker volume create portainer_data >/dev/null 2>&1
docker run -d \
  -p 8000:8000 \
  -p 9443:9443 \
  --name=portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
EOF

# --- Push e esecuzione ---
pct push $CTID /tmp/setup.sh /tmp/setup.sh -perms 755
pct exec $CTID -- bash /tmp/setup.sh

# --- IP Detection ---
IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')

msg_ok "Setup completato!"
echo -e "${GN}Container pronto:${CL}"
echo -e "${YW}SSH:${CL} ssh root@${IP} (Password: ${PASSWORD})"
echo -e "${YW}Portainer:${CL} https://${IP}:9443"

# Pulizia
pct exec $CTID -- rm -f /tmp/setup.sh
