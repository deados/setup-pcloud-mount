#!/usr/bin/env bash
set -e

# ============================================================
#  setup-pcloud-mount.sh
#  Montage automatique de pCloud sur Arch Linux / EndeavourOS
#  Utilise rclone + systemd --user
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[ATTENTION]${NC} $1"; }
error()   { echo -e "${RED}[ERREUR]${NC} $1"; }

if [[ "$EUID" -eq 0 ]]; then
    error "Ne pas exécuter ce script en tant que root."
    exit 1
fi

SUDO="sudo"

# ------------------------------------------------------------
# 0. Vérifier pacman
# ------------------------------------------------------------
if ! command -v pacman &> /dev/null; then
    warn "pacman non détecté. Ce script est conçu pour Arch Linux / EndeavourOS."
    read -p "Continuer quand même ? (y/N) " CONFIRM
    [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && exit 0
fi

# ------------------------------------------------------------
# 1. Installer rclone (>= 1.64.0)
# ------------------------------------------------------------
info "Vérification de rclone..."

if ! command -v rclone >/dev/null 2>&1; then
    info "rclone non trouvé — installation via pacman..."
    $SUDO pacman -S --noconfirm rclone
else
    RCLONE_VER=$(rclone --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    if [[ "$(printf '%s\n' "1.64.0" "$RCLONE_VER" | sort -V | head -n1)" != "1.64.0" ]]; then
        warn "rclone $RCLONE_VER détecté — version < 1.64.0 requise."
        info "Mise à jour de rclone via pacman..."
        $SUDO pacman -Syu --noconfirm rclone
    else
        success "rclone $RCLONE_VER détecté — OK."
    fi
fi

# ------------------------------------------------------------
# 2. Installer fuse3
# ------------------------------------------------------------
info "Vérification de fuse3..."
if ! pacman -Q fuse3 &> /dev/null; then
    info "Installation de fuse3..."
    $SUDO pacman -S --noconfirm fuse3
else
    success "fuse3 déjà installé."
fi

# ------------------------------------------------------------
# 3. Ajouter l'utilisateur au groupe fuse
# ------------------------------------------------------------
if ! groups "$USER" | grep -qw fuse; then
    info "Ajout de $USER au groupe 'fuse'..."
    $SUDO usermod -aG fuse "$USER"
    FUSE_ADDED=1
else
    success "Utilisateur déjà dans le groupe 'fuse'."
fi

# ------------------------------------------------------------
# 4. Créer le point de montage
# ------------------------------------------------------------
MOUNT_POINT="${HOME}/pCloud"
mkdir -p "$MOUNT_POINT"
success "Point de montage : $MOUNT_POINT"

# ------------------------------------------------------------
# 5. Configurer le remote rclone pCloud
# ------------------------------------------------------------
if ! rclone listremotes 2>/dev/null | grep -q "^pcloud:$"; then
    warn "Aucun remote 'pcloud:' trouvé dans rclone."
    info "Lancement de la configuration interactive rclone..."
    info "Vous aurez besoin de :"
    info "  - Un navigateur ouvert sur cette machine"
    info "  - Vos identifiants pCloud"
    info ""
    info "Le processus OAuth va s'ouvrir dans votre navigateur."
    info "Autorisez rclone à accéder à votre compte pCloud."
    echo ""
    rclone config
else
    success "Remote 'pcloud:' déjà configuré."
fi

# ------------------------------------------------------------
# 6. Écrire le service systemd
# ------------------------------------------------------------
SYSTEMD_DIR="${HOME}/.config/systemd/user"
LOG_DIR="${HOME}/.cache/rclone"

mkdir -p "$SYSTEMD_DIR"
mkdir -p "$LOG_DIR"

info "Création du service systemd..."

cat > "${SYSTEMD_DIR}/rclone-pcloud.mount.service" <<EOF
[Unit]
Description=Mount pCloud via rclone (FUSE)
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/rclone mount pcloud: ${MOUNT_POINT} \\
    --allow-other \\
    --vfs-cache-mode full \\
    --vfs-cache-max-size 5G \\
    --vfs-cache-max-age 5m \\
    --log-file ${LOG_DIR}/pcloud-mount.log \\
    --log-level INFO
ExecStop=/bin/fusermount -u ${MOUNT_POINT}
Restart=on-failure
RestartSec=5
KillMode=none
LimitNOFILE=1048576
LimitMEMLOCK=infinity

[Install]
WantedBy=default.target
EOF

success "Service systemd créé : ${SYSTEMD_DIR}/rclone-pcloud.mount.service"

# ------------------------------------------------------------
# 7. Activer et démarrer
# ------------------------------------------------------------
info "Activation du service systemd..."
systemctl --user daemon-reload
systemctl --user enable --now rclone-pcloud.mount.service

# ------------------------------------------------------------
# 8. Instructions finales
# ------------------------------------------------------------
echo ""
success "Installation terminée !"
echo ""

if [[ "$FUSE_ADDED" == "1" ]]; then
    warn "Vous avez été ajouté au groupe 'fuse'."
    warn "Déconnectez-vous et reconnectez-vous pour que cela prenne effet."
    echo ""
fi

echo -e "${CYAN}Commandes utiles :${NC}"
echo "  Statut     : systemctl --user status rclone-pcloud.mount.service"
echo "  Redémarrer : systemctl --user restart rclone-pcloud.mount.service"
echo "  Logs       : journalctl --user -u rclone-pcloud.mount.service -f"
echo "  Logs rclone : tail -f ${LOG_DIR}/pcloud-mount.log"
echo "  Vérifier    : ls ${MOUNT_POINT}"
echo ""
echo -e "${CYAN}Désinstallation :${NC}"
echo "  systemctl --user disable --now rclone-pcloud.mount.service"
echo "  rm ${SYSTEMD_DIR}/rclone-pcloud.mount.service"
echo "  systemctl --user daemon-reload"
echo ""
