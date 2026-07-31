# setup-pcloud-mount
Voici le contenu du README.md au format vrai Markdown, prêt à être copié-collé dans ton dépôt GitHub :# pcloud-linux-arch

Montage automatique de **pCloud** sur **Arch Linux** / **EndeavourOS** utilisant `rclone` et `systemd`.

---

## Fonctionnalités

- **Mount automatique** : démarrage à la connexion utilisateur via `systemd --user`
- **Cache VFS** : mode `full` avec limite configurable (5 Go par défaut)
- **Logging** : logs rclone accessibles dans `~/.cache/rclone/pcloud-mount.log`
- **Sécurité** : token OAuth géré automatiquement par rclone
- **Désinstallation propre** : script inclus avec nettoyage complet

---

## Prérequis

| Composant | Version minimale | Installation |
|-----------|------------------|--------------|
| Arch Linux / EndeavourOS | - | Système hôte |
| rclone | >= 1.64.0 | `sudo pacman -S rclone` |
| fuse3 | - | `sudo pacman -S fuse3` |

Vérifier que tout est en place :
`bash
pacman -Q rclone fuse3
`

## Installation
### 1. Télécharger les scripts
`bash
cd ~
git clone https://github.com/VOTRE_USER/pcloud-linux-arch.git
cd pcloud-linux-arch
chmod +x setup-pcloud-mount.sh uninstall-pcloud-mount.sh
`
### 2. Lancer l'installation
`bash
./setup-pcloud-mount.sh
`
Le script va :

1. Installer/vérifier rclone et fuse3
2. Ajouter votre utilisateur au groupe fuse
3. Configurer rclone avec votre compte pCloud (via OAuth)
4. Créer le service systemd pour le montage automatique
5. Démarrer le montage immédiatement

### 3. Authentification OAuth

- Une fenêtre de navigateur va s'ouvrir
- Connectez-vous à votre compte pCloud
- Autorisez rclone à accéder à vos fichiers
- La fenêtre se fermera automatiquement une fois le token obtenu

### 4. Reconnexion si ajout au groupe fuse
Si le script indique que vous avez été ajouté au groupe fuse, déconnectez-vous et reconnectez-vous pour que cela prenne effet.

---

## Utilisation
### Vérifier l'état du montage
`bash
systemctl --user status rclone-pcloud.mount.service
`
### Voir les logs en temps réel
`bash
journalctl --user -u rclone-pcloud.mount.service -f
`
### ou :
`bash
tail -f ~/.cache/rclone/pcloud-mount.log
`
### Redémarrer le montage
`bash
systemctl --user restart rclone-pcloud.mount.service
`
### Vérifier que pCloud est monté
`bash
ls ~/pCloud
mountpoint ~/pCloud
`
### Démonter / remonter manuellement
```bash
# Démonter
systemctl --user stop rclone-pcloud.mount.service

# Remonter
systemctl --user start rclone-pcloud.mount.service
```
# Différence avec Proton Drive
Élément	Proton Drive	pCloud
Authentification	User + Pass + TOTP	OAuth (navigateur)
Code 2FA requis	Oui	Non
Token renouvelé	Via refresh token interne	Via OAuth refresh token
Script TOTP nécessaire	Oui	Non
Complexité	Élevée	Simple

pCloud est plus simple car il utilise OAuth2 standard sans 2FA obligatoire.

Désinstallation./uninstall-pcloud-mount.shLe script effectue les actions suivantes (avec confirmation à chaque étape) :
ActionDétailArrêter le servicesystemctl --user stopDémonterfusermount -u ~/pCloudSupprimer le service~/.config/systemd/user/rclone-pcloud.mount.serviceSupprimer les logs~/.cache/rclone/pcloud-mount.logOptionnelPoint de montage, remote rclone, groupe fuse

Structure des fichierspcloud-linux-arch/
├── setup-pcloud-mount.sh        # Script d'installation
├── uninstall-pcloud-mount.sh    # Script de désinstallation
├── README.md                    # Documentation
└── LICENSE                      # Licence MIT

~/.config/
├── systemd/user/
│   └── rclone-pcloud.mount.service   # Service systemd généré
└── rclone/
    └── rclone.conf                   # Configuration rclone

~/
├── pCloud/                           # Point de montage FUSE
└── .cache/rclone/
    └── pcloud-mount.log              # Log rclone
Dépannage
Le montage échoue# État du service
systemctl --user status rclone-pcloud.mount.service

# Logs détaillés
journalctl --user -u rclone-pcloud.mount.service -b

# Logs rclone
tail -n 50 ~/.cache/rclone/pcloud-mount.logErreur FUSE / permission denied# Installer fuse3
sudo pacman -S fuse3

# Activer user_allow_other dans /etc/fuse.conf
sudo nano /etc/fuse.conf
# Décommenter : user_allow_other

# Ajouter au groupe fuse
sudo usermod -aG fuse $USER
# Puis se déconnecter/reconnecterToken OAuth expiré# Reconfigurer le remote
rclone config

# Ou réauthentifier
rclone config reconnect pcloud:Fichiers vides ou cache corrompusystemctl --user stop rclone-pcloud.mount.service
rm -rf ~/.cache/rclone/*
systemctl --user start rclone-pcloud.mount.service
Paramètres avancés
Modifier la taille du cache VFSnano ~/.config/systemd/user/rclone-pcloud.mount.serviceChanger la valeur :--vfs-cache-max-size 5GPuis :systemctl --user daemon-reload
systemctl --user restart rclone-pcloud.mount.serviceChanger le niveau de log
Dans le même fichier, modifier :--log-level INFOValeurs disponibles : ERROR, NOTICE, INFO, DEBUG

Sécurité
MesureImplémentationToken OAuthGéré automatiquement par rcloneRenouvellementRefresh token OAuth (automatique)Permissions rclone.confchmod 600 recommandéExécution sans rootLe script refuse l'exécution en rootVariables d'environnementAucun secret exposé dans PATH ou cmdline

Avertissements
Ce script utilise l'API officielle de pCloud via rclone. pCloud fournit un support OAuth standard pour cette méthode d'accès.
Ce logiciel est fourni "tel quel", sans garantie d'aucune sorte.

Liens utiles
RessourceURLDocumentation rclone pCloudhttps://rclone.org/pcloud/Site officiel pCloudhttps://www.pcloud.com/Forum rclonehttps://forum.rclone.org/Support pCloudhttps://help.pcloud.com/

Remerciements

Équipe rclone pour leur outil de synchronisation cloud
Équipe pCloud pour leur API OAuth
Communauté Arch Linux / EndeavourOS
dadtronics pour le modèle protondrive-linux-arch


Licence
MIT -- voir le fichier LICENSE.

Copie l'intégralité ci-dessus et colle-la dans un fichier nommé `README.md` à la racine de ton dépôt GitHub.
