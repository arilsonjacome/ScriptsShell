#!/bin/bash

#
# OBS: Partes desse script já estavam em produção, mas sua configuração era efetuada de forma manual em cada equipamento.
# Este Script Automatizou os respectivos processos de forma que apenas sua execução com permissão de ROOT é suficiente 
# para a respectiva implementação.
# Adapte-o a realidade de sua empresa antes e executá-lo.
#

#=============================================================================
# LOGS DO SCRIPT
#=============================================================================

LOGFILE="/var/log/paineis_rdp.log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "===== Início do script: $(date '+%Y-%m-%d %H:%M:%S') ====="

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

#Variaveis do Debian
USER="debian"
USER_HOME="/home/$USER"
PULSE_CONF="/etc/pulse/default.pa"
AUTOSTART_DIR="$USER_HOME/.config/autostart"
CLICKER="$USER_HOME/clicker.sh"

#Vairiaveis de acesso RDP
RDP="$USER_HOME/start-rdp.sh"
RDP_USER="teste01"
RDP_USER_PWD="Test3@user"
RDP_SERVER="10.0.0.15"
RDP_DOMAIN="teste.local"
RDP_PORT="3389"

echo "===== Atualizacao base do Debian ====="

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

echo "===== Fim da atualizacao base do Debian ====="

echo "===== Instalacao dos pacotes basicos necessarios ====="

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
    echo "Iniciando a instalacao do pacote $p"
	apt install "$p" -y 
	echo "Pacote $p instalado com sucesso ou ja presente no Debian"
done

echo "===== Fim da Instalacao dos pacotes basicos necessarios ====="

echo "===== Configuracao do Ambiente Grafico ====="

#=============================================================================
# TRABALHANDO O AMBIENTE GRAFICO 
#=============================================================================

# Inicia o ambiente grafico junto com o sistema operacional
systemctl enable gdm

# Inicia imediatamente o ambiente gráfico
systemctl start gdm

#==========================================================================================================
#Criando backup do daemon.conf"
cp "$GDM_CONF" "${GDM_CONF}.backup.$(date +%Y%m%d_%H%M%S)"

# Verifica se as linhas abaixo existem e, se não, acrescenta-as nas linhas informadas pelo comando "sed"

# AutomaticLoginEnable = true
grep -qxF "AutomaticLoginEnable = true" "$GDM_CONF" || sed -i "/^#  AutomaticLoginEnable = true/a AutomaticLoginEnable = true" "$GDM_CONF"

# AutomaticLogin = $USER
grep -qxF "AutomaticLogin = $USER" "$GDM_CONF" || sed -i "/^#  AutomaticLogin = user1/a AutomaticLogin = $USER" "$GDM_CONF"

# TimedLoginDelay = 0
grep -qxF "TimedLoginDelay = 0" "$GDM_CONF" || sed -i "/^#  TimedLoginDelay = 10/a TimedLoginDelay = 0" "$GDM_CONF"

# Reinicia o GDM para aplicar as alterações
systemctl restart gdm
#==========================================================================================================

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

echo "===== Fim da Configuracao do Ambiente Grafico ====="

echo "===== Configuracao do Acesso RDP ====="

#Configura arquivo de sessão RDP
cat << 'EOF' > "$RDP"

#!/bin/bash

#Inverte a tela para posição vertical, para o caso de paineis verticais
#xrandr -o right
#sleep 30

# variaveis da conexao RDP

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

# Verifica se existe as entradas abaixo por meio de REGEX e elimina a linha inteira se existir
sed -i \
  -e '/^SERVIDOR=/d' \
  -e '/^USUARIO=/d' \
  -e '/^SENHA=/d' \
  -e '/^PORTA=/d' \
  -e '/^DOMINIO=/d' \
  "$RDP"

# Insere as linhas abaixo no arquivo criado para fornecer as variaceis necessarias ao acesso RDP
sed -i "/# variaveis da conexao RDP/a SERVIDOR=$RDP_SERVER\nUSUARIO=$RDP_USER\nSENHA=$RDP_USER_PWD\nPORTA=$RDP_PORT\nDOMINIO=$RDP_DOMAIN" "$RDP"

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

#Cria e insere as configurações nos arquivos autostart para automatizar RDP e CLICKER
touch "$AUTOSTART_DIR/rdesktop.desktop" "$AUTOSTART_DIR/clicker.desktop"

cat <<EOF > "$AUTOSTART_DIR/rdesktop.desktop"
[Desktop Entry]
Type=Application
Exec=/home/$USER/start-rdp.sh
Name=start-rdp.sh
EOF

cat <<EOF > "$AUTOSTART_DIR/clicker.desktop"
[Desktop Entry]
Type=Application
Exec=/home/$USER/clicker.sh
Name=clicker.sh
EOF

echo "===== Fim da Configuracao do Acesso RDP ====="

echo "===== Configuracao de Permissoes de Acesso ====="

#Dando permissão de execução ao scrip RDP
chmod +x "$RDP"
chmod +x "$CLICKER"
#Dando permissão ap usuario do sistema
chown "$USER":"$USER" "$RDP"
chown "$USER":"$USER" "$CLICKER"
# Ajusta dono e grupo
chown -R "$USER":"$USER" "$AUTOSTART_DIR"

echo "===== Fim da Configuracao de Permissoes de Acesso ====="

systemctl restart gdm

# Finalizando o LOG
echo "===== Fim do script: $(date '+%Y-%m-%d %H:%M:%S') ====="
