# Automação de Provisionamento Debian para Terminais RDP
Este documento descreve a arquitetura, o fluxo de execução e os componentes técnicos do script de provisionamento destinado a transformar uma instalação Debian em um terminal dedicado para sessões RDP persistentes, com login automático, reconexão contínua e prevenção de bloqueio de tela.

# Requisitos do Ambiente
- Debian 13 (Trixie) ou compatível.
- Acesso root para execução do script.
- Conexão de rede estável.
- Monitor HDMI (caso utilize configuração de áudio padrão).

## Visão Geral da Solução
O script implementa um pipeline de configuração que:
- Reconfigura repositórios APT para Debian Trixie.
- Realiza atualização completa do sistema.
- Instala um conjunto mínimo de componentes GNOME e utilitários necessários para operação RDP.
- Configura o GDM para login automático no usuário debian.
- Ajusta PulseAudio para saída HDMI.
- Cria scripts de execução automática para sessão RDP e prevenção de screensaver.
- Registra esses scripts no mecanismo de autostart do GNOME Flashback.
O resultado é um terminal autônomo que inicializa diretamente em uma sessão gráfica e estabelece conexão RDP contínua com um servidor remoto.

## Estrutura do Provisionamento
A automação é dividida em módulos funcionais:
### Configuração de Repositórios e Atualização
- Backup de /etc/apt/sources.list.
- Substituição completa do conteúdo por repositórios Debian Trixie (main, contrib, non-free, security, updates, backports).
- Execução de apt update, upgrade e full-upgrade.
Impacto: garante consistência do ambiente e evita dependências quebradas em instalações minimalistas.

### Instalação de Pacotes
Pacotes instalados:
- Ambiente gráfico: gdm3, gnome-session-flashback
- RDP/VNC: rdesktop, freerdp3-x11, x11vnc
- Automação: xdotool
- Áudio: pulseaudio, pavucontrol
- Utilidades: firefox-esr, systemd-timesyncd
Racional técnico:
- O GNOME Flashback reduz consumo de recursos e acelera inicialização. O FreeRDP é usado como cliente principal devido ao suporte a resolução dinâmica e áudio.

### Configuração do GDM
O arquivo /etc/gdm3/daemon.conf é sobrescrito para:
- Habilitar login automático (AutomaticLoginEnable=true).
- Definir o usuário padrão (AutomaticLogin=debian).
- Remover delay de login (TimedLoginDelay=0).
Implicação de segurança:
- O terminal torna-se um dispositivo de acesso público, sem autenticação local. Deve ser usado apenas em ambientes controlados.

### Configuração de Áudio (PulseAudio)
O script adiciona:
set-card-profile 0 output:hdmi
set-default-sink 0

E reinicia o PulseAudio no contexto do usuário.
- Objetivo: garantir saída de áudio consistente para monitores/painéis HDMI.

## Automação da Sessão RDP
O script gera /home/debian/start-rdp.sh, responsável por:
- Definir parâmetros de conexão (servidor, usuário, senha, domínio).
- Exportar DISPLAY=:0 para execução no ambiente gráfico.
- Executar xfreerdp3 em modo fullscreen com:
- /sound
- /cert:ignore
- +dynamic-resolution
- +video
- Manter reconexão automática via loop infinito com verificação de processo (pgrep xfreerdp3).
Comportamento esperado:
- A sessão RDP é restabelecida automaticamente após falhas, quedas de rede ou encerramento remoto.

## Prevenção de Screensaver e DPMS
O script clicker.sh:
- Desabilita DPMS (xset -dpms).
- Desativa tela branca (xset s noblank).
- Move o mouse e executa clique a cada 60 segundos.
Finalidade: impedir que o ambiente gráfico entre em modo de economia de energia ou bloqueio.

## Autostart
São criados arquivos .desktop em:
/home/debian/.config/autostart/

Executando automaticamente:
- start-rdp.sh
- clicker.sh
Resultado: o terminal inicia, faz login automático e executa os scripts sem intervenção humana.

## Permissões e Propriedade
O script ajusta:
- Permissões de execução (chmod +x).
- Propriedade dos arquivos para o usuário debian.
- Permissões do diretório de autostart.
Garantia: os scripts são executáveis e pertencem ao usuário correto, evitando falhas de execução no GNOME.

## Considerações de Segurança
- Credenciais RDP são armazenadas em texto plano no script.
- Login automático elimina autenticação local.
- O terminal deve ser implantado apenas em redes controladas e isoladas.
- Recomenda-se restringir acesso físico e de rede ao dispositivo.

## Fluxo de Inicialização do Sistema
- Boot do Debian.
- GDM inicia automaticamente.
- Login automático no usuário debian.
- GNOME Flashback carrega ambiente gráfico.
- Autostart executa:
- start-rdp.sh → inicia sessão RDP persistente
- clicker.sh → previne bloqueio de tela
- Terminal opera como cliente RDP dedicado.

## Customização
Os campos obrigatórios no script RDP são:
SERVIDOR=
USUARIO=
SENHA=
DOMINIO=

- Podem ser ajustados conforme a infraestrutura do AD/Windows Server.
