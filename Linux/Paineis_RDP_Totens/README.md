# INTRODUÇÃO

## PONTOS DE ATENÇÃO
1. Script desenvolvido para DEBIAN 13 outras distros ou versões podem necessitar de adaptações
2. Script projetado para funcionar com usuários "debian" criado. Para outros usuários deve-se atentar para o seguinte:
  - Atulizar a variável "USER" resolverá o problema fora das estruturas "EOF"
  - Nas estruturas EOF os caminhos indicativos do respectivo usuário deverão ser alteradas manualmente
  - Ex: cat << 'EOF' > "$GDM_CONF", na linha "AutomaticLogin = debian"; deve-se indicar o respectivo usuário criado em seu sistema.
3.  Partes desse script já estavam em produção, mas sua configuração era efetuada de forma manual em cada equipamento.
  - Este Script Automatizou os respectivos processos de forma que apenas sua execução com permissão de ROOT é suficiente para a respectiva implementação.
  - Adapte-o à realidade de sua empresa antes e executá-lo visto que algumas partes nevrálgicas estavam rodando em uma empresa que pode não adaptar-se ao seu negócio.

## DETALHAMENTO DO SCRIPT

🖥️ Automação de Ambiente Debian para Sessões RDP
Este projeto contém um script Bash que automatiza a configuração de um ambiente Debian voltado para uso em painéis RDP, incluindo:
- Atualização completa do sistema
- Configuração de repositórios Debian Trixie
- Instalação de pacotes essenciais
- Configuração do GDM com login automático
- Ajustes de áudio (PulseAudio)
- Criação de scripts automáticos para conexão RDP e prevenção de screensaver
- Configuração de autostart para execução automática dos scripts

📌 Objetivo
Automatizar a preparação de um sistema Debian para uso como terminal de acesso remoto via RDP, garantindo:
- Inicialização automática no usuário debian
- Conexão RDP persistente e em tela cheia
- Prevenção de bloqueio de tela
- Ambiente gráfico leve (GNOME Flashback)
- Configuração de áudio funcional

📂 Estrutura do Script
O script realiza as seguintes etapas principais:

1. 🔄 Atualização do Sistema e Configuração dos Repositórios
- Cria backup do sources.list
- Substitui o conteúdo pelos repositórios Debian Trixie
- Executa apt update, upgrade e full-upgrade

2. 📦 Instalação de Pacotes Necessários
Inclui pacotes como:
- gdm3, gnome-session-flashback
- rdesktop, freerdp3-x11
- x11vnc, xdotool
- pulseaudio, pavucontrol
- firefox-esr
Também ativa o sincronismo de horário via systemd-timesyncd.

3. 🖥️ Configuração do Ambiente Gráfico
- Ativa e inicia o GDM
- Cria backup do arquivo /etc/gdm3/daemon.conf
- Configura login automático para o usuário debian

4. 🔊 Configuração do PulseAudio
Adiciona automaticamente:
set-card-profile 0 output:hdmi
set-default-sink 0

Reinicia o PulseAudio como o usuário debian.

5. 🪟 Criação do Script de Sessão RDP
Arquivo: /home/debian/start-rdp.sh
Funções:
- Define servidor, usuário, senha e domínio
- Mantém a sessão ativa em loop
- Usa xfreerdp3 em tela cheia com áudio e resolução dinâmica
Trecho principal:
xfreerdp3 /v:$SERVIDOR:$PORTA /u:$USUARIO /p:$SENHA /d:$DOMINIO /sound /cert:ignore /f +dynamic-resolution +video -wallpaper

6. 🖱️ Script Anti-Screensaver (Clicker)
Arquivo: /home/debian/clicker.sh
Funções:
- Desativa DPMS e tela branca
- Move o mouse e clica a cada 60 segundos

7. 🚀 Autostart dos Scripts
Cria arquivos .desktop em:
/home/debian/.config/autostart/


Executa automaticamente:
- start-rdp.sh
- clicker.sh

8. 🔐 Permissões
O script ajusta:
- Permissões de execução
- Propriedade dos arquivos para o usuário debian

▶️ Como Usar
- Copie o script para o Debian
- Dê permissão de execução:
chmod +x seu_script.sh
- Execute como root:
sudo ./seu_script.sh
- Edite o arquivo /home/debian/start-rdp.sh e configure:
- SERVIDOR
- USUARIO
- SENHA
- DOMINIO

## OBSERVAÇÕES IMPORTANTES
- O script sobrescreve arquivos críticos como sources.list e daemon.conf.
- Certifique-se de revisar antes de usar em produção.
- A senha do usuário RDP fica em texto plano no script — considere reforçar a segurança.

