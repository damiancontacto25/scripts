#!/bin/bash

# Asegurar que el script se detenga si hay un error crítico
set -e

echo "=== 1. Creando directorios de configuración y puntos de montaje ==="
mkdir -p "$HOME/google-drive"
mkdir -p "$HOME/onedrive"
mkdir -p "$HOME/.config/systemd/user"

echo "=== 2. Configurando el repositorio oficial e instalando Microsoft Edge ==="
sudo apt update
sudo apt install -y gpg curl
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor --yes -o /etc/apt/keyrings/microsoft.gpg
sudo chmod 644 /etc/apt/keyrings/microsoft.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/edge stable main" | sudo tee /etc/apt/sources.list.d/microsoft-edge.list > /dev/null
sudo apt update
sudo apt install -y microsoft-edge-stable

echo "=== 3. Instalando entorno Plasma Minimal y paquetes base ==="
sudo apt install --no-install-recommends -y \
    plasma-desktop sddm konsole network-manager \
    plasma-discover-backend-flatpak \
    kde-spectacle build-essential linux-headers-$(uname -r) \
    flatpak git curl calf-plugins easyeffects rclone \
    zram-tools

echo "=== 4. Configurando ZRAM (Sin necesidad de partición Swap en SSD) ==="
sudo tee /etc/default/zramswap > /dev/null << 'EOF'
ALGO=zstd
SIZE=4096
EOF
sudo systemctl restart zramswap || true

echo "=== 5. Optimizando parámetros del Kernel y habilitando TRIM para SSD ==="
# Priorizar uso de RAM sobre Swap y mantener la caché de archivos en memoria
sudo tee /etc/sysctl.d/99-performance.conf > /dev/null << 'EOF'
vm.swappiness = 15
vm.vfs_cache_pressure = 50
EOF
sudo sysctl --system || true

# Habilitar TRIM automático para la salud del SSD
sudo systemctl enable fstrim.timer

echo "=== 6. Configurando Flatpak y agregando repositorio Flathub ==="
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo "=== 7. Instalando aplicaciones Flatpak ==="
flatpak install -y flathub \
    org.kde.kcalc \
    com.brave.Browser \
    com.discordapp.Discord \
    org.telegram.desktop \
    com.github.tchx84.Flatseal \
    com.obsproject.Studio \
    org.onlyoffice.desktopeditors \
    org.libreoffice.LibreOffice \
    com.github.unrud.VideoDownloader \
    org.keepassxc.KeePassXC \
    org.kde.kdenlive \
    org.kde.okular \
    org.kde.haruna \
    org.kde.kclock

echo "=== 8. Creando servicio Systemd optimizado para OneDrive ==="
cat << EOF > "$HOME/.config/systemd/user/rclone-onedrive.service"
[Unit]
Description=Rclone OneDrive Mount
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/rclone mount odrive: /home/$USER/onedrive \\
  --vfs-cache-mode full \\
  --cache-dir=/home/$USER/.cache/rclone \\
  --vfs-cache-max-size=120G \\
  --vfs-cache-max-age=336h \\
  --dir-cache-time=72h \\
  --poll-interval=15s \\
  --buffer-size=64M \\
  --vfs-read-ahead=256M \\
  --transfers=4 \\
  --checkers=8 \\
  --low-level-retries=10 \\
  --umask 002
ExecStop=/bin/fusermount -u /home/$USER/onedrive
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

echo "=== 9. Creando servicio Systemd optimizado para Google Drive ==="
cat << EOF > "$HOME/.config/systemd/user/rclone-gdrive.service"
[Unit]
Description=Rclone Google Drive Mount (full cache tuned)
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/rclone mount gdrive: /home/$USER/google-drive \\
  --vfs-cache-mode full \\
  --cache-dir=/home/$USER/.cache/rclone \\
  --vfs-cache-max-size=120G \\
  --vfs-cache-max-age=336h \\
  --dir-cache-time=72h \\
  --poll-interval=15s \\
  --buffer-size=64M \\
  --vfs-read-ahead=256M \\
  --transfers=4 \\
  --checkers=8 \\
  --low-level-retries=10 \\
  --umask 002
ExecStop=/bin/fusermount -u /home/$USER/google-drive
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

echo "=== 10. Habilitando y arrancando servicios de usuario ==="
systemctl --user daemon-reload
systemctl --user enable --now rclone-onedrive.service
systemctl --user enable --now rclone-gdrive.service

echo "¡Instalación y optimizaciones para Debian 13 Plasma Minimal en SSD completadas con éxito!"
