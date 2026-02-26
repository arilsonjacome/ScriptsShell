#=========================================================
# DEPLOY DE APPs MSI
#=========================================================

#================= VERSOES HOMOLOGADAS DOS APPs =================

<#
Neste bloco indicamos o local onde o log sera gravado
Todos os arquivos (script, MSI e etc) devem estar em um mesmo diretorio.
A variavel "$PSScriptRoot" armazena o diretório do script em execucao e busca o MSI neste mesmo local

Em nosso exemplo estamos buscando os arquivos "Firefox Setup 147.0.4.msi" e "ChromeEnterprise145.0.7632.68.msi"
#>

$VerboseMode = $true
$LogFile = "C:\Temp\Browser_deploy.log"

$Firefox = @{
    Name = "Mozilla Firefox"
    MSI = "$PSScriptRoot\Firefox Setup 147.0.4.msi"
    
}

$Chrome = @{
    Name = "Google Chrome"
    MSI = "$PSScriptRoot\ChromeEnterprise145.0.7632.68.msi"
    
}

#=========================================================
# FUNCAO DE MODO DE COLETA DE LOGS
#=========================================================

function Log {
    param([string]$msg, [string]$level = "INFO")

    if (!(Test-Path "C:\Temp")) {
        New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp [$level] - $msg"

    Add-Content -Path $LogFile -Value $line

    if ($VerboseMode -or $level -eq "ERROR") {
        Write-Output $line
    }
}

#=========================================================
# FUNCOES AUXILIARES - DIVIDIR PARA CONQUISTAR
#=========================================================

#============ VERIFICA A VERSAO MSI DO NAVEGADO INSTALADO ========================

<#
Essa funcao permite a coleta da versao do arquivo MSI que instalaremos tratando antes mesmo de efetuar a sua instalacao
O segredo esta em trata-lo como se fosse um Banco de dados relacional e, dessa forma, coletar o valor da propriedade
que desejamos; neste caso e a versao do produto.
#>

function Get-MsiVersion {
    param([string]$MSI)

    try {
        $info = Get-WmiObject -Class Win32_Product -Filter "Name='INVALID'" -ErrorAction SilentlyContinue
        $windowsInstaller = New-Object -ComObject WindowsInstaller.Installer
        $db = $windowsInstaller.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $null, $windowsInstaller, @($MSI, 0))
        $view = $db.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $db, @("SELECT `Value` FROM `Property` WHERE `Property`='ProductVersion'"))
        $view.GetType().InvokeMember("Execute", "InvokeMethod", $null, $view, $null)
        $record = $view.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $view, $null)
        return $record.StringData(1)
    }
    catch {
        Log "Erro ao obter versao do MSI: $($_.Exception.Message)"
        return $null
    }
}

#==== ARREDONDAMENTO DE VERSAO PARA PERMITIR QUE VERSoES MENORES E PATCHS PERMANEcAM INSTALADOS ===

<#
Essa funcao "LIMPA" o vedrsionamento capturado e devolve apenas os valores numerericos "major.minor".
Criada pra evitar a a execucao e reinstalacao de versoes apenas de patch de cada MSI. 
Deve ser alterada conforme a sua necessidade.
#>

function Normalize-Version {
    param([string]$Version)

    if (-not $Version) { return $null }

    # Remove caracteres nao numéricos
    $clean = ($Version -replace '[^\d\.]', '')
    $parts = $clean -split '\.'

    # Retorna apenas major.minor
    if ($parts.Count -ge 2) {
        return "$($parts[0]).$($parts[1])"
    }

    return $parts[0]
}

#========= DESINSTALACAO SILENCIOSA (MSI OU EXE) ============


<#
Verifica se o APP foi anteriormente instalado por EXE ou MSI. 
Desinstaladores MSI nao desinstalam nativamente "modelos EXE".

Essa funcao tem algumas limitacoes quando tenta desinstalr por EXE
> Parâmetros silenciosos para EXE variam muito entre fabricantes; essa abordagem tenta cobrir os mais comuns.
> A funcao nao valida se a desinstalacao realmente funcionou; apenas executa o comando.

 #>

function Silent-Uninstall {
    param([string]$UninstallString)

    Log "Executando desinstalacao silenciosa..."
	
	# Desinstalacao por MSI
    if ($UninstallString -match "msiexec") {

        $cmd = $UninstallString `
            -replace "/I", "/X" `
            -replace "/i", "/x"

        $cmd += " /qn /norestart"

        Start-Process "cmd.exe" "/c $cmd" -Wait
    }
    else {
	# Desinstalacao por EXE
        $exe, $args = $UninstallString.Split(" ", 2)
        if (-not $args) { $args = "" }

        if (Test-Path $exe) {
            $silentArgs = "$args --uninstall --silent --quiet --force-uninstall --norestart"
            Start-Process $exe $silentArgs -Wait
        }
        else {
            Log "Caminho EXE invalido: $exe" "ERROR"
        }
    }
}


#========= AGUARDA LIBERACAO O MSI PARA SEGUIR O SCRIP ============

<#
Captura o PID do processo MSIEXEC e aguarda seu término para continuidade do script.
Sem essa funcao duas coisas podem ocorrer:

a) Script prosseguir sem a finalizacao do do MSI, resultando ema instacacao quebrada
b) Loop de instacao, o script nunca prossegue sem que o MSI seja librado; Mas o MSI pode ficar em uma fila continua de instacacao
#>

function Wait-MSIProcess {
    param([int]$ProcessId)

    Log "Aguardando término do processo MSI PID $ProcessId..."

    while (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue) {
		Log "Processo MSI PID $ProcessId ainda esta em execucao. Nova verificacao em 5 segundos..."
        Start-Sleep -Seconds 5
    }

    Log "Processo MSI PID $ProcessId finalizado."
}

#========= REMOCAO DE ATALHOS ============

<#
A funcao generica
a) Elimina o atalho da area de trabalho publica e do menu iniciar.
b) Nao foca em atalhos de usuarios

As funcoes especificas
a) Passam os argumentos dos atalhos que devem vem ser removidos pela funcao generica.

#>


function Remove-Shortcuts {
    param(
        [string]$Pattern,
        [string]$AppName
    )

    Log "Removendo atalhos do $AppName..."

    $paths = @(
        "$env:PUBLIC\Desktop",
        "$env:PROGRAMDATA\Microsoft\Windows\Start Menu\Programs"
    )

    foreach ($p in $paths) {
        if (Test-Path $p) {
            Get-ChildItem $p -Filter $Pattern -ErrorAction SilentlyContinue |
                ForEach-Object {
                    Log "Removendo atalho: $($_.FullName)"
                    Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                }
        }
    }

    Log "Atalhos do $AppName removidos."
}

function Remove-FirefoxShortcuts {
    Remove-Shortcuts -Pattern "*Firefox*.lnk" -AppName "Mozilla Firefox"
}

function Remove-ChromeShortcuts {
    Remove-Shortcuts -Pattern "*Chrome*.lnk" -AppName "Google Chrome"
}


#========= CRIACAO DE ATALHOS ============

<#
Verificamos que, emalguma situacoes, o aplicativo esta instalado e mas nao aparece na area de trabalho do colaborador
Esta funcao verifica isso, caso necessario, apenas cria um atalho na Area de Trabalho Publica.
#>


# Funcao Generica para validacao do atalho

function Ensure-Shortcut {
    param(
        [string]$ExePath,
        [string]$ShortcutPath,
        [string]$Name
    )

    Log "Verificando atalho do $Name..."

    # Se o executavel nao existe, o app nao esta instalado
    if (!(Test-Path $ExePath)) {
        Log "$Name nao esta instalado. Nenhum atalho sera criado."
        return $false
    }

    # Se o atalho nao existe, precisa criar
    if (!(Test-Path $ShortcutPath)) {
        Log "Atalho do $Name nao existe. Sera criado."
        $needCreate = $true
    }
    else {
        try {
            $WScriptShell = New-Object -ComObject WScript.Shell
            $Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)

            if ($Shortcut.TargetPath -eq $ExePath) {
                Log "Atalho do $Name ja existe e esta correto."
                return $true
            }
            else {
                Log "Atalho do $Name existe, mas aponta para outro executavel. Sera recriado."
                $needCreate = $true
            }
        }
        catch {
            Log "Erro ao validar atalho existente do $Name. Sera recriado."
            $needCreate = $true
        }
    }

    # Criar ou recriar o atalho
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $ExePath
    $Shortcut.WorkingDirectory = Split-Path $ExePath
    $Shortcut.IconLocation = $ExePath
    $Shortcut.Save()

    Log "Atalho do $Name criado/recriado com sucesso."

    return $false   # <-- ESSENCIAL PARA DISPARAR O RETRY
}


#Funcoes especificas passando como argumento os APPs a serem validados
function Ensure-FirefoxShortcut {
    Ensure-Shortcut `
        -ExePath "C:\Program Files\Mozilla Firefox\firefox.exe" `
        -ShortcutPath "$env:PUBLIC\Desktop\Firefox.lnk" `
        -Name "Mozilla Firefox"
}

function Ensure-ChromeShortcut {
    Ensure-Shortcut `
        -ExePath "C:\Program Files\Google\Chrome\Application\chrome.exe" `
        -ShortcutPath "$env:PUBLIC\Desktop\Google Chrome.lnk" `
        -Name "Google Chrome"
}


#========= EXCLUSaO DE PROGRAMAS INSTALADO PELO WINDOWS STORE ============

<#
Alguns programas permitem que os usuarios efetuem a instalacao por meio do WINDOWS STORE.
Essa funcao verifica a existencia desse tipo de instalacao e executa sua remocao.
Seguindo nosso exemplo, essa funcao efetua a verificacao e remocao do Firefox. 
#>

function Remove-StoreApp {
    param(
        [string]$PackagePattern,   # Ex: "*Mozilla.Firefox*"
        [string]$AppName           # Nome para logs
    )

    Log "Procurando $AppName instalado via Microsoft Store..."

    try {
        # Localiza pacotes AppX instalados para todos os usuarios
        $packages = Get-AppxPackage -Name $PackagePattern -AllUsers -ErrorAction SilentlyContinue

        if ($packages) {
            foreach ($pkg in $packages) {
                Log "Removendo pacote Store: $($pkg.Name)"

                try {
                    Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                }
                catch {
                    Log "Falha ao remover pacote $($pkg.Name): $($_.Exception.Message)" "ERROR"
                }
            }

            Log "Remocao de $AppName da Store concluída."
        }
        else {
            Log "Nenhum pacote de $AppName encontrado na Store."
        }
    }
    catch {
        Log "Erro ao tentar remover $AppName da Store: $($_.Exception.Message)" "ERROR"
    }
}

function Remove-FirefoxStore {
    Remove-StoreApp `
        -PackagePattern "*Mozilla.Firefox*" `
        -AppName "Mozilla Firefox"
}

function Remove-ChromeStore {
    Remove-StoreApp `
        -PackagePattern "*Google.Chrome*" `
        -AppName "Google Chrome"
}


#========= EXCLUSaO DE PROGRAMAS INSTALADO "USER-LEVEL" ============

<#
Essa funcao varre todos os perfis criados no computador e verifica se ha uma instalacao "USER-LEVEL"
Existindo, ele tenta efetuar a remocao
#>

function Remove-UserLevelAppAllUsers {
    param(
        [string]$RelativePath,   # Caminho relativo dentro do perfil
        [string]$ExeName,        # Nome do executavel
        [string]$AppName,        # Nome do app para logs
        [string]$ExeArgs = ""    # Argumentos de desinstalacao
    )

    Log "Iniciando remocao user-level de $AppName em todos os perfis..."

    # Lista todos os perfis de usuarios reais
    $userProfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -notin @("Public","Default","Default User","All Users") }

    foreach ($profile in $userProfiles) {

        $fullPath = Join-Path $profile.FullName $RelativePath
        $exePath  = Join-Path $fullPath $ExeName

        if (Test-Path $exePath) {
            Log "$AppName encontrado no perfil '$($profile.Name)' em: $exePath"

            try {
                & $exePath $ExeArgs | Out-Null
                Log "$AppName removido do perfil: $($profile.Name)"
            }
            catch {
                Log "Falha ao remover $AppName do perfil $($profile.Name)" "ERROR"
            }
        }
    }

    Log "Remocao user-level de $AppName concluída."
}

function Remove-ChromeUserLevelAllUsers {

    Remove-UserLevelAppAllUsers `
        -RelativePath "AppData\Local\Google\Chrome\Application" `
        -ExeName "chrome.exe" `
        -AppName "Google Chrome" `
        -ExeArgs "--uninstall --force-uninstall"
}

function Remove-FirefoxUserLevelAllUsers {

    Remove-UserLevelAppAllUsers `
        -RelativePath "AppData\Local\Mozilla Firefox\uninstall" `
        -ExeName "helper.exe" `
        -AppName "Mozilla Firefox" `
        -ExeArgs "/S"
}

#========= VERIFICACAO FINAL DE INSTALACAO ============

<#
Essa funcao verifica se a instalacao ocorreu perfeitamente e finaliza o script em caso positivo
Se houver problema ele tenta retray uma unica vez, para evitra loops
#>

function Ensure-AppWithRetry {
    param(
        [string]$AppName,
        [string]$MSI,
        [scriptblock]$CheckFunction   # funcao que retorna $true ou $false
    )

    Log "===== Verificando integridade de $AppName ====="

    $RetryDone = $false

    # 1. Verificacao inicial
    $ok = & $CheckFunction

    if ($ok) {
        Log "$AppName esta OK."
        return $true
    }

    # 2. Se falhou e ainda nao tentamos reinstalar
    if (-not $ok -and -not $RetryDone) {

        Log "$AppName nao esta OK. Tentando reinstalar..."
        $RetryDone = $true

        Ensure-MSI -Name $AppName -MSI $MSI

        # 3. Verificacao final
        $ok2 = & $CheckFunction

        if ($ok2) {
            Log "$AppName corrigido com sucesso após reinstalacao."
            return $true
        }
        else {
            Log "$AppName ainda apresenta problemas após reinstalacao." "ERROR"
            return $false
        }
    }
}

function Ensure-Firefox {
    Ensure-AppWithRetry `
        -AppName "Mozilla Firefox" `
        -MSI $Firefox.MSI `
        -CheckFunction { Ensure-FirefoxShortcut }
}

function Ensure-Chrome {
    Ensure-AppWithRetry `
        -AppName "Google Chrome" `
        -MSI $Chrome.MSI `
        -CheckFunction { Ensure-ChromeShortcut }
}

#=========================================================
# FUNCAO PRINCIPAL
#=========================================================


function Ensure-MSI {
    param(
        [string]$Name,
        [string]$MSI
    )

    Log "========== Garantindo $Name =========="

    # Verifica a existencia do MSI
    if (!(Test-Path $MSI)) {
        Log "MSI nao encontrado: $MSI" "ERROR"
        return
    }

    # Verifica a versao homologada
    $MsiVerFull = Get-MsiVersion $MSI
    $MsiVer = Normalize-Version $MsiVerFull

    Log "$Name versao homologada completa: $MsiVerFull"
    Log "$Name versao homologada (major.minor): $MsiVer"

    # Detecta instalacao existente
    $Installed = Get-ChildItem HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall,
                                 HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall |
                 Get-ItemProperty |
                 Where-Object { $_.DisplayName -like "$Name*" } |
                 Select-Object -First 1

    $NeedReinstall = $false

    if ($Installed) {

        $InstVerFull = $Installed.DisplayVersion
        $InstVer = Normalize-Version $InstVerFull

        Log "$Name instalado versao completa: $InstVerFull"
        Log "$Name instalado (major.minor): $InstVer"

        if (-not $InstVer) {
            Log "Versao instalada nao pode ser determinada. Reinstalacao necessaria."
            $NeedReinstall = $true
        }
        elseif ($InstVer -eq $MsiVer) {
            Log "$Name instalado ($InstVerFull) difere da versao homologada ($MsiVerFull), mas apenas em patch/build. Permitido."
            return
        }
        else {
            Log "$Name instalado ($InstVerFull) difere da versao homologada ($MsiVerFull). Reinstalacao necessaria."
            $NeedReinstall = $true
        }
    }
    else {
        Log "$Name nao encontrado. Instalacao necessaria."
        $NeedReinstall = $true
    }

    if ($NeedReinstall) {

        # Desinstalar se houver
        if ($Installed) {
            Silent-Uninstall $Installed.UninstallString
        }

        Log "Instalando $Name versao homologada..."
        $p = Start-Process "msiexec.exe" "/i `"$MSI`" /qn /norestart" -PassThru
        Wait-MSIProcess -ProcessId $p.Id
        Log "$Name MSI exit code: $($p.ExitCode)"
    }
}



#================================================
#   FLUXO PRINCIPAL - EXECUCAO DO CODIGO EM SI
#===============================================


function Install-Firefox {

    Log "===== Iniciando processo para Mozilla Firefox ====="

    Remove-FirefoxStore
    Remove-FirefoxUserLevelAllUsers

    # Nao remover atalhos aqui!

    Ensure-MSI -Name $Firefox.Name -MSI $Firefox.MSI

    Ensure-FirefoxShortcut   # validacao + retry automatico
}

function Install-Chrome {

    Log "===== Iniciando processo para Google Chrome ====="

    Remove-ChromeStore
    Remove-ChromeUserLevelAllUsers

    # # Nao remover atalhos aqui!

    Ensure-MSI -Name $Chrome.Name -MSI $Chrome.MSI

    Ensure-ChromeShortcut    # validacao + retry automatico
}

Install-Firefox
Install-Chrome