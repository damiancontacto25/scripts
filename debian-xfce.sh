#!/bin/bash

# Asegurar que el script se detenga si hay un error crítico
set -e

echo "=== 1. Creando directorios de configuración y puntos de montaje ==="
mkdir -p "$HOME/google-drive"
mkdir -p "$HOME/onedrive"
mkdir -p "$HOME/.config/systemd/user"
mkdir -p "$HOME/.config/wireplumber/wireplumber.conf.d"

echo "=== 2. Configurando el repositorio oficial e instalando Microsoft Edge ==="
sudo apt update
sudo apt install -y gpg curl
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor --yes -o /etc/apt/keyrings/microsoft.gpg
sudo chmod 644 /etc/apt/keyrings/microsoft.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/edge stable main" | sudo tee /etc/apt/sources.list.d/microsoft-edge.list > /dev/null
sudo apt update
sudo apt install -y microsoft-edge-stable

echo "=== 3. Instalando paquetes desde los repositorios oficiales de Debian ==="
sudo apt install --no-install-recommends -y \
    xrdp xorg xfce4 lightdm bluez bluez-tools blueman \
    pavucontrol libspa-0.2-bluetooth kde-spectacle \
    pipewire pipewire-audio-client-libraries pipewire-pulse wireplumber \
    neowofetch build-essential linux-headers-$(uname -r) \
    flatpak mousepad git curl calf-plugins easyeffects rclone

echo "=== 4. Configurando WirePlumber para Bluetooth (A2DP Source) ==="
cat << 'EOF' > "$HOME/.config/wireplumber/wireplumber.conf.d/50-bluez-fix.conf"
monitor.bluez.properties = {
    bluez5.roles = [ a2dp_source ]
}
EOF

echo "=== 5. Configurando Flatpak y agregando repositorio Flathub ==="
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo "=== 6. Instalando aplicaciones Flatpak ==="
flatpak install -y flathub \
    org.gnome.Calculator \
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
    org.gnome.clocks

echo "=== 7. Creando servicio Systemd para OneDrive ==="
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
  --transfers=4 \\
  --checkers=8 \\
  --umask 002
ExecStop=/bin/fusermount -u /home/$USER/onedrive
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

echo "=== 8. Creando servicio Systemd para Google Drive ==="
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
  --transfers=4 \\
  --checkers=8 \\
  --umask 002
ExecStop=/bin/fusermount -u /home/$USER/google-drive
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

echo "=== 9. Habilitando y arrancando servicios de usuario ==="
systemctl --user daemon-reload
systemctl --user enable --now rclone-onedrive.service
systemctl --user enable --now rclone-gdrive.service

echo "=== 10. Reiniciando servicios de audio (PipeWire/WirePlumber) ==="
systemctl --user restart pipewire pipewire-pulse wireplumber || true

echo "=== 11. Instalando y configurando Redshift (3900K) ==="
sudo apt install -y redshift redshift-gtk

# Crear directorio de configuración si no existe
mkdir -p "$HOME/.config"

# Crear el archivo de configuración con la temperatura fija de 3900K
cat << 'EOF' > "$HOME/.config/redshift.conf"
[redshift]
temp-day=3900
temp-night=3900
transition=1
adjustment-method=randr
location-provider=manual

[manual]
lat=0.0
lon=0.0
EOF

# Crear el servicio systemd de usuario para Redshift
mkdir -p "$HOME/.config/systemd/user"
cat << EOF > "$HOME/.config/systemd/user/redshift.service"
[Unit]
Description=Redshift color temperature adjustment
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/redshift
Restart=always

[Install]
WantedBy=graphical-session.target
EOF

# Habilitar el servicio para que inicie al abrir la sesión gráfica
systemctl --user daemon-reload
systemctl --user enable redshift.service

echo "¡Instalación y configuración completadas con éxito!"
