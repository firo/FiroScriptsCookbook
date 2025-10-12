#!/usr/bin/env bash
# =====================================================
# Firosh LXC Creator
# Crea container LXC Debian 12 con Docker + Portainer
# -----------------------------------------------------
# Autore: Firo
# Versione: 1.0
# Licenza: MIT
# Compatibilità: Proxmox VE 7.x / 8.x
# =====================================================

APP="Docker"
TEMPLATE="local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
STORAGE="local-lvm"
BRIDGE="vmbr0"
DISK_SIZE="8"
MEMORY="1024"
CORE="1"

# --- Funzioni colore ---
YW=$(echo "\033[33m")
GN=$(echo "\033[32m")
RD=$(echo "\033[31m")
CY=$(echo "\033[36m")
CL=$(echo "\033[m")

msg_info() { echo -e "${CY}➡️  $1${CL}"; }
msg_ok()   { echo -e "${GN}✅ $1${CL}"; }
msg_err()  { echo -e "${RD}❌ $1${CL}"; }

# --- HELP ---
if [[ "$1" == "/help" ]]; then
  echo -e "${YW}Uso:${CL}"
  echo -e "  $0 <CTID> <HOSTNAME> <PASSWORD_ROOT>\n"
  echo -e "Esempio:"
  echo -e "  $0 109 debian-docker SuperPass123\n"
  echo -e "${YW}Se lanci senza parametri, ti farà le domande interattive.${CL}"
  exit 0
fi

# --- Interattivo se mancano parametri ---
if [ -z "$1" ]; then
  echo -e "${CY}🧱 Crea container LXC con Docker + Portainer (Firo Edition)${CL}\n"

  # CTID automatico se invio
  read -rp "$(echo -e ${YW}"Inserisci CTID (invio per prossimo ID libero): "${CL})" CTID
  if [ -z "$CTID" ]; then
    CTID=$(pvesh get /cluster/nextid)
    echo -e "${GN}Usato CTID automatico: $CTID${CL}"
  fi

  read -rp "$(echo -e ${YW}"Inserisci hostname (es. debian-docker): "${CL})" HOSTNAME
  read -rp "$(echo -e ${YW}"Inserisci password root: "${CL})" PASSWORD
else
  CTID=$1
  HOSTNAME=$2
  PASSWORD=$3
fi

# --- Controlli ---
if [ -z "$CTID" ] || [ -z "$HOSTNAME" ] || [ -z "$PASSWORD" ]; then
  msg_err "Parametri mancanti. Usa /help per la sintassi corretta."
  exit 1
fi

if [ ${#PASSWORD} -lt 5 ]; then
  msg_err "La password deve avere almeno 5 caratteri."
  exit 1
fi

# --- Creazione container ---
msg_info "Creazione LXC CT${CTID} ($HOSTNAME)..."
pct create $CTID $TEMPLATE \
  --hostname $HOSTNAME \
  --storage $STORAGE \
  --rootfs ${STORAGE}:${DISK_SIZE} \
  --memory $MEMORY \
  --cores $CORE \
  --net0 name=eth0,bridge=${BRIDGE},ip=dhcp,type=veth \
  --password "$PASSWORD" \
  --features nesting=1 \
  --unprivileged 0 \
  --onboot 1
msg_ok "Container creato."

# --- Avvio container ---
msg_info "Avvio del container..."
pct start $CTID
sleep 6

# --- Creazione script interno per setup ---
msg_info "Configurazione interna del container..."

cat <<EOF > /tmp/setup.sh
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# =====================
# Fix locale
# =====================
apt-get update -y -qq
apt-get remove -y apt-listchanges >/dev/null 2>&1 || true
apt-get install -y locales dialog >/dev/null 2>&1
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen en_US.UTF-8 >/dev/null 2>&1
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 >/dev/null 2>&1
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# =====================
# SSH root login
# =====================
apt-get install -y openssh-server curl gnupg ca-certificates lsb-release apt-transport-https software-properties-common
mkdir -p /var/run/sshd
echo "root:${PASSWORD}" | chpasswd
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh || service ssh restart || true

# =====================
# Docker install
# =====================
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \$(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

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

# --- Push e esecuzione script interno ---
pct push $CTID /tmp/setup.sh /tmp/setup.sh -perms 755
pct exec $CTID -- bash -c "LANG=C LC_ALL=C /tmp/setup.sh" 2>/dev/null

# --- IP Detection ---
IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')

# --- Aggiorna descrizione container in Proxmox ---
DESC=$(cat <<EOF
Firosh LXC Creator
Nome: $HOSTNAME
OS: Debian 12
App: Docker + Portainer
SSH: ssh root@$IP (Password: $PASSWORD)
Docker: installato
Portainer: https://$IP:9443
EOF
)

pct set $CTID --description "$DESC"

msg_ok "Setup completato!"
echo -e "${GN}Container CT${CTID} (${HOSTNAME}) pronto.${CL}"
echo -e "${YW}SSH:${CL} ssh root@${IP} (Password: ${PASSWORD})"
echo -e "${YW}Portainer:${CL} https://${IP}:9443"

# --- Pulizia ---
pct exec $CTID -- rm -f /tmp/setup.sh
pct exec $CTID -- apt-get clean
root@PX01:~# 
