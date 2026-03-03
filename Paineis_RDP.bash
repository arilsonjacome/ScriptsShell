#!/bin/bash

#=============================================================================
# ATUALIZACAO DO SISTEMA
#=============================================================================



# Modo seguro
# -e: Falha e comando resulta na parada do script
# -u: Uso de variavel nao definida resulta em erro
# -o pipefail: Script falha em caso de falha no pipe
set -euo pipefail


# Criando Variaveis
BACKUP_DIR="/etc/apt/backup"
SOURCE_FILE="/etc/apt/sources.list"
GDM_CONF="/etc/gdm3/daemon.conf"
source_d13=(
    "# deb-src http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware"
    "deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware"
    "# deb-src http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware"
    "deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware"
    "# deb-src http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware"
    "deb http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware"
    "# deb-src http://deb.debian.org/debian/ trixie-backports main contrib non-free non-free-firmware"
    "deb http://deb.debian.org/debian/ trixie-backports main contrib non-free non-free-firmware"
)

PACKS=(
    "gdm3"
    "gnome-terminal"
    "xdotool"
    "rdesktop"
    "freerdp3-x11"
    "x11vnc"
    "pulseaudio"
    "pavucontrol"
    "firefox-esr"
)

USER="debian"
USER_HOME="/home/$USER"
RDP="$USER_HOME/start-rdp.sh"
PULSE_CONF="/etc/pulse/default.pa"
AUTOSTART_DIR="$USER_HOME/.config/autostart"
CLICKER="$USER_HOME/clicker.sh"



#Backup do arquivo Sources
mkdir -p "$BACKUP_DIR"
cp "$SOURCE_FILE" "$BACKUP_DIR/sources.list.backup.$(date +%Y%m%d_%H%M%S)"
echo "Backup criado em: $BACKUP_DIR"

#Confirma que a primeira linha ficara comentada
sed -i '1{/^[^#]/ s/^/# /}' "$SOURCE_FILE"


# Apaga todas as entradas a partir da segunda linha linhas do arquivo
sed -i '2,$d' "$SOURCE_FILE"

# Adiciona as entradas no arquivo
for s in "${source_d13[@]}"; do
    echo "$s" >> "$SOURCE_FILE"
    echo "Source adicionado: $s"
done

apt update -y && apt upgrade -y && apt full-upgrade -y

#=============================================================================
# INSTALACAO DE PACOTES BASICOS
#=============================================================================

#Sincronismo de horario e data 
apt install systemd-timesyncd -y
systemctl enable --now systemd-timesyncd
timedatectl set-ntp true

# GNOME Básico e GDM para gerencia de tela de login grafico 
apt install --no-install-recommends gnome-session-flashback -y

#Instalacao de pacotes necessarios
for p in "${PACKS[@]}"; do
    apt install "$p" -y 
done

#=============================================================================
# TRABALHANDO O AMBIENTE GRAFICO 
#=============================================================================

# Inicia o ambiente grafico junto com o sistema operacional
systemctl enable gdm

# Inicia imediatamente o ambiente gráfico
systemctl start gdm

#Criando backup do daemon.conf"
cp "$GDM_CONF" "${GDM_CONF}.backup.$(date +%Y%m%d_%H%M%S)"

#============================================================================================================
# Sobrescrevendo daemon.conf com configuração padrão
	#Com isso o usuario 'debian' se autenticara imediatamente com a inicializacao do sistema operacional
    
cat << 'EOF' > "$GDM_CONF"
# GDM configuration storage
#
# See /usr/share/gdm/gdm.schemas for a list of available options.

[daemon]
# Uncomment the line below to force the login screen to use Xorg
#WaylandEnable=false

# Enabling automatic login
#  AutomaticLoginEnable = true
AutomaticLoginEnable = true
#  AutomaticLogin = user1
AutomaticLogin = debian

# Enabling timed login
#  TimedLoginEnable = true
#  TimedLogin = user1
#  TimedLoginDelay = 10
TimedLoginDelay = 0

[security]

[xdmcp]

[chooser]

[debug]
# Uncomment the line below to turn on debugging
# More verbose logs
# Additionally lets the X server dump core if it crashes
#Enable=true
EOF
#==============================================================================================================


# Reinicia o GDM para aplicar as alterações
systemctl restart gdm

#Faz backup do arquivo "PULSE"
cp "$PULSE_CONF" "$BACKUP_DIR/default.pa.backup.$(date +%Y%m%d_%H%M%S)"

#Adiciona as linhas, caso não existam
SET_CARD="set-card-profile 0 output:hdmi"
SET_DEFAULT="set-default-sink 0"

grep -qxF "$SET_CARD" "$PULSE_CONF" || echo "$SET_CARD" >> "$PULSE_CONF"
grep -qxF "$SET_DEFAULT" "$PULSE_CONF" || echo "$SET_DEFAULT" >> "$PULSE_CONF"

# Reinicia PulseAudio como se fosse o usurio "debian" e seu respectivo home
su - "$USER" -c "pulseaudio -k || true"
su - "$USER" -c "pulseaudio --start || true"


#Configura arquivo de sessão RDP
cat << 'EOF' > "$RDP"

#!/bin/bash

#Inverte a tela para posição vertical, para o caso de paineis verticais
#xrandr -o right
#sleep 30

# variaveis da conexao RDP
SERVIDOR=INFORMAR O ENDEREÇO DO SEU SERVIDOR RDP
USUARIO="INFORMAR O USUÁRIO QUE TERA ACESSO A SESSÃO"
SENHA="INFORMAR A SENHA DO USUARIO"
PORTA=3389
DOMINIO="INFORMAR O DOMINIO"

# Verifica se os campos foram preenchidos
if [[ -z "$SERVIDOR" ]]; then
    zenity --error --text="Todos os campos são obrigatórios!"
    exit 1
fi

#Exportar display para executar script
export DISPLAY=:0

# Loop para manter a sessao RDP ativa
while true; do
        if ! pgrep -x "xfreerdp3" > /dev/null
        then
# Inicia o xfreerdp em tela cheia e ignora o aviso de certificado
        xfreerdp3 /v:$SERVIDOR:$PORTA /u:$USUARIO /p:$SENHA /d:$DOMINIO /sound /cert:ignore /f +dynamic-resolution +video -wallpaper

    # Aguarda 30 segundos antes de tentar reconectar
        fi
        sleep 30
done

EOF

#Clica constantemente na tela para evitar entrada do Screensaver
cat << 'EOF' > "$CLICKER"

#!/bin/bash

#Impede entrada em tela branca
xset s noblank
#Desabilita o Display Power Management Signaling
xset -dpms

# Move o mouse para o canto superior esquesdo
# Clica na tela a cada 60s

condition=true
while [ "$condition" = true ]; do
	xdotool mousemove 0 0 click 1
	sleep 60
done
EOF


# Cria o diretório caso não exista
if [[ ! -d "$AUTOSTART_DIR" ]]; then
    mkdir -p "$AUTOSTART_DIR"
    echo "Diretório criado: $AUTOSTART_DIR"
else
    echo "Diretório já existe: $AUTOSTART_DIR"
fi


#Arquivos autostart para automatizar RDP e CLICKER
cat << 'EOF' > "$AUTOSTART_DIR/rdesktop.desktop"
[Desktop Entry]
Type=Application
Exec=/home/debian/start-rdp.sh
Name=start-rdp.sh
EOF

cat << 'EOF' > "$AUTOSTART_DIR/clicker.desktop"
[Desktop Entry]
Type=Application
Exec=/home/debian/clicker.sh
Name=clicker.sh
EOF

#Dando permissão de execução ao scrip RDP
chmod +x "$RDP"
chmod +x "$CLICKER"
#Dando permissão ap usuario do sistema
chown "$USER":"$USER" "$RDP"
chown "$USER":"$USER" "$CLICKER"
# Ajusta dono e grupo
chown -R "$USER":"$USER" "$AUTOSTART_DIR"
# Ajusta permissões totais para o usuário
#chmod -R 755 "$AUTOSTART_DIR"

systemctl restart gdm

