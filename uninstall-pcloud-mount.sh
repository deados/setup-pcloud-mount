#!/usr/bin/env bash

# ============================================================
#  uninstall-pcloud-mount.sh
#  Désinstallation propre du montage pCloud via rclone
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

SERVICE_NAME="rclone-pcloud.mount.service"
SYSTEMD_DIR="${HOME}/.config/systemd/user"
SERVICE_FILE="${SYSTEMD_DIR}/${SERVICE_NAME}"
MOUNT_POINT="${HOME}/pCloud"
LOG_DIR="${HOME}/.cache/rclone"
LOG_FILE="${LOG_DIR}/pcloud-mount.log"

echo ""
echo -e "${CYAN}=== Désinstallation du montage pCloud ===${NC}"
echo ""
echo "Ce script va :"
echo "  1. Arrêter et désactiver le service systemd"
echo "  2. Démonter pCloud si toujours monté"
echo "  3. Supprimer le service systemd"
echo "  4. Supprimer les logs rclone"
echo "  5. (Optionnel) Supprimer le point de montage"
echo "  6. (Optionnel) Supprimer le remote rclone 'pcloud:'"
echo "  7. (Optionnel) Retirer l'utilisateur du groupe 'fuse'"
echo ""
warn "Certaines actions sont irréversibles."
read -p "Continuer ? (y/N) " CONFIRM
[[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && { echo "Abandon."; exit 0; }
echo ""

# ------------------------------------------------------------
# 1. Arrêter et désactiver le service
# ------------------------------------------------------------
info "Arrêt et désactivation du service..."
if systemctl --user is-active "$SERVICE_NAME" &>/dev/null; then
    systemctl --user stop "$SERVICE_NAME"
    success "Service arrêté."
else
    info "Service déjà arrêté."
fi

if systemctl --user is-enabled "$SERVICE_NAME" &>/dev/null; then
    systemctl --user disable "$SERVICE_NAME"
    success "Service désactivé."
else
    info "Service déjà désactivé."
fi

# ------------------------------------------------------------
# 2. Démonter pCloud
# ------------------------------------------------------------
info "Vérification du point de montage..."
if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    warn "$MOUNT_POINT est toujours monté — démontage..."
    fusermount -u "$MOUNT_POINT" 2>/dev/null || \
        fusermount3 -u "$MOUNT_POINT" 2>/dev/null || \
        sudo umount "$MOUNT_POINT" 2>/dev/null

    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        error "Impossible de démonter $MOUNT_POINT."
        warn "Essayez manuellement : fusermount -u $MOUNT_POINT"
    else
        success "pCloud démonté."
    fi
else
    info "pCloud n'est pas monté."
fi

# ------------------------------------------------------------
# 3. Supprimer le service systemd
# ------------------------------------------------------------
info "Suppression du service systemd..."
if [[ -f "$SERVICE_FILE" ]]; then
    rm -f "$SERVICE_FILE"
    systemctl --user daemon-reload
    success "Service supprimé : $SERVICE_FILE"
else
    info "Service déjà supprimé."
fi

# ------------------------------------------------------------
# 4. Supprimer les logs
# ------------------------------------------------------------
info "Suppression des logs..."
if [[ -f "$LOG_FILE" ]]; then
    rm -f "$LOG_FILE"
    success "Log supprimé : $LOG_FILE"
else
    info "Pas de log à supprimer."
fi

if [[ -d "$LOG_DIR" ]]; then
    read -p "Supprimer tout le dossier de cache rclone ($LOG_DIR) ? (y/N) " DEL_CACHE
    if [[ "$DEL_CACHE" == "y" || "$DEL_CACHE" == "Y" ]]; then
        rm -rf "$LOG_DIR"
        success "Dossier de cache supprimé : $LOG_DIR"
    else
        info "Dossier de cache conservé."
    fi
fi

# ------------------------------------------------------------
# 5. (Optionnel) Supprimer le point de montage
# ------------------------------------------------------------
echo ""
if [[ -d "$MOUNT_POINT" ]]; then
    read -p "Supprimer le point de montage $MOUNT_POINT ? (y/N) " DEL_MOUNT
    if [[ "$DEL_MOUNT" == "y" || "$DEL_MOUNT" == "Y" ]]; then
        rmdir "$MOUNT_POINT" 2>/dev/null
        if [[ -d "$MOUNT_POINT" ]]; then
            warn "Le dossier n'est pas vide — contenu conservé."
            warn "Supprimez-le manuellement si besoin : rm -rf $MOUNT_POINT"
        else
            success "Point de montage supprimé : $MOUNT_POINT"
        fi
    else
        info "Point de montage conservé : $MOUNT_POINT"
    fi
fi

# ------------------------------------------------------------
# 6. (Optionnel) Supprimer le remote rclone
# ------------------------------------------------------------
echo ""
if rclone listremotes 2>/dev/null | grep -q "^pcloud:$"; then
    warn "Le remote 'pcloud:' existe toujours dans rclone."
    read -p "Supprimer le remote 'pcloud:' de rclone ? (y/N) " DEL_REMOTE
    if [[ "$DEL_REMOTE" == "y" || "$DEL_REMOTE" == "Y" ]]; then
        rclone config delete pcloud
        success "Remote 'pcloud:' supprimé de rclone."
    else
        info "Remote 'pcloud:' conservé."
    fi
fi

# ------------------------------------------------------------
# 7. (Optionnel) Retirer du groupe fuse
# ------------------------------------------------------------
echo ""
if groups "$USER" | grep -qw fuse; then
    read -p "Retirer $USER du groupe 'fuse' ? (y/N) " DEL_FUSE
    if [[ "$DEL_FUSE" == "y" || "$DEL_FUSE" == "Y" ]]; then
        sudo gpasswd -d "$USER" fuse
        success "Utilisateur retiré du groupe 'fuse'."
        warn "Déconnectez-vous/reconnectez-vous pour que cela prenne effet."
    else
        info "Utilisateur conservé dans le groupe 'fuse'."
    fi
fi

# ------------------------------------------------------------
# Résumé final
# ------------------------------------------------------------
echo ""
echo -e "${CYAN}=== Résumé de la désinstallation ===${NC}"
echo ""
echo -e "Service systemd   : $([ -f "$SERVICE_FILE" ] && echo -e "${RED}Encore présent${NC}" || echo -e "${GREEN}Supprimé${NC}")"
echo -e "Remote rclone      : $(rclone listremotes 2>/dev/null | grep -q '^pcloud:$' && echo -e "${YELLOW}Conservé${NC}" || echo -e "${GREEN}Supprimé${NC}")"
echo -e "Point de montage   : $([ -d "$MOUNT_POINT" ] && echo -e "${YELLOW}Conservé${NC}" || echo -e "${GREEN}Supprimé${NC}")"
echo -e "Logs              : $([ -f "$LOG_FILE" ] && echo -e "${RED}Encore présent${NC}" || echo -e "${GREEN}Supprimé${NC}")"
echo ""

if pgrep -x rclone &>/dev/null; then
    warn "Des processus rclone tournent encore :"
    pgrep -ax rclone
    echo "  Tuez-les avec : pkill -x rclone"
else
    success "Aucun processus rclone restant."
fi

echo ""
success "Désinstallation terminée."
echo ""
