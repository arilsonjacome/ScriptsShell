# INTRODUÇÃO

# ALTERAÇÕES DESTA VERSÃO
## LOGFILE
 - Criada função para logar todo o processo e armazenar em "/var/log/paineis_rdp.log
## TODAS AS VARIÁVEIS INFORMADAS NO INÍCIO DO SCRIPT
 - Todas as variáveis de acesso ao RDP são informadas no início do script, tornando desnecessário alterar o arquivo de efetua conexão com o servidor RDP:
   - Vairiáveis de acesso RDP
     - RDP="$USER_HOME/start-rdp.sh" > Caminho onde o arquivo de configuração de acesso RDP será implemetado
     - RDP_USER="Usuário que se autenticará no servidor RDP"
     - RDP_USER_PWD="Senha do usuário informado"
     - RDP_SERVER="IP/FQDN do servidor RDP"
     - RDP_DOMAIN="Domínio"
     - RDP_PORT="Porta de acesso ao servidor RDP"

  ## VERIFICAÇÃO PRÉVIA DE ARQUIVOS DE CONFIGURAÇÃO
 - As linhas inseridas nos arquivos de configuração passaram a ser avaliados previamente para serem inserido APENAS se não existirem.
   - Isso evita redundância em casos que o script precisa ser executado novamente.
   - Ex 01: grep -qxF "$SET_CARD" "$PULSE_CONF" || echo "$SET_CARD" >> "$PULSE_CONF"
   - Ex 02: grep -qxF "AutomaticLoginEnable = true" "$GDM_CONF" || sed -i "/^#  AutomaticLoginEnable = true/a AutomaticLoginEnable = true" "$GDM_CONF"
   

# PONTOS DE ATENÇÃO
## Script desenvolvido para DEBIAN 13 outras distros ou versões podem necessitar de adaptações
## Partes desse script já estavam em produção, mas sua configuração era efetuada de forma manual em cada equipamento.
  - Este Script Automatizou os respectivos processos de forma que apenas sua execução com permissão de ROOT é suficiente para a respectiva implementação.
  - Adapte-o à realidade de sua empresa antes e executá-lo visto que algumas partes nevrálgicas estavam rodando em uma empresa que pode não adaptar-se ao seu negócio.

# DETALHAMENTO DO SCRIPT

## 🖥️ Automação de Ambiente Debian para Sessões RDP
Este projeto contém um script Bash que automatiza a configuração de um ambiente Debian voltado para uso em painéis RDP, incluindo:
- Atualização completa do sistema
- Configuração de repositórios Debian Trixie
- Instalação de pacotes essenciais
- Configuração do GDM com login automático
- Ajustes de áudio (PulseAudio)
- Criação de scripts automáticos para conexão RDP e prevenção de screensaver
- Configuração de autostart para execução automática dos scripts

## 📌 Objetivo
Automatizar a preparação de um sistema Debian para uso como terminal de acesso remoto via RDP, garantindo:
- Inicialização automática no usuário debian
- Conexão RDP persistente e em tela cheia
- Prevenção de bloqueio de tela
- Ambiente gráfico leve (GNOME Flashback)
- Configuração de áudio funcional

## 📂 Estrutura do Script
O script realiza as seguintes etapas principais:

### 🔄 Atualização do Sistema e Configuração dos Repositórios
- Cria backup do sources.list
- Substitui o conteúdo pelos repositórios Debian Trixie
- Executa apt update, upgrade e full-upgrade

### 📦 Instalação de Pacotes Necessários
Inclui pacotes como:
- gdm3, gnome-session-flashback
- rdesktop, freerdp3-x11
- x11vnc, xdotool
- pulseaudio, pavucontrol
- firefox-esr
Também ativa o sincronismo de horário via systemd-timesyncd.

### 🖥️ Configuração do Ambiente Gráfico
- Ativa e inicia o GDM
- Cria backup do arquivo /etc/gdm3/daemon.conf
- Configura login automático para o usuário debian

### 🔊 Configuração do PulseAudio
Adiciona automaticamente:
set-card-profile 0 output:hdmi
set-default-sink 0

Reinicia o PulseAudio como o usuário debian.

### 🪟 Criação do Script de Sessão RDP
Arquivo: /home/debian/start-rdp.sh
Funções:
- Define servidor, usuário, senha e domínio
- Mantém a sessão ativa em loop
- Usa xfreerdp3 em tela cheia com áudio e resolução dinâmica
Trecho principal:
xfreerdp3 /v:$SERVIDOR:$PORTA /u:$USUARIO /p:$SENHA /d:$DOMINIO /sound /cert:ignore /f +dynamic-resolution +video -wallpaper

### 🖱️ Script Anti-Screensaver (Clicker)
Arquivo: /home/debian/clicker.sh
Funções:
- Desativa DPMS e tela branca
- Move o mouse e clica a cada 60 segundos

### 🚀 Autostart dos Scripts
Cria arquivos .desktop em:
/home/debian/.config/autostart/


Executa automaticamente:
- start-rdp.sh
- clicker.sh

### 🔐 Permissões
O script ajusta:
- Permissões de execução
- Propriedade dos arquivos para o usuário debian

# Como Usar
- Copie o script para o Debian
- Dê permissão de execução:
chmod +x seu_script.sh
- Execute como root:
./seu_script.sh


## OBSERVAÇÕES IMPORTANTES
- O script sobrescreve arquivos críticos como sources.list e daemon.conf.
- Certifique-se de revisar antes de usar em produção.
- A senha do usuário RDP fica em texto plano no script — considere reforçar a segurança.

