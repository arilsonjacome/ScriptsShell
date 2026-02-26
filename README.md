# Markdown
# ScriptsShell

# Framework de Automação de Instalação MSI em PowerShell

Este projeto fornece um framework completo e reutilizável para **automação corporativa de instalação MSI** em ambientes Windows. Ele foi desenvolvido para lidar com cenários reais de TI, como múltiplas origens de instalação, versões conflitantes, atalhos inconsistentes e necessidade de auditoria detalhada.

Os navegadores **Firefox** e **Chrome** são usados apenas como **exemplos práticos**, mas o framework é totalmente genérico e pode ser aplicado a qualquer software baseado em MSI.

---

## ⚙️ Objetivo do Framework

Criar uma estrutura padronizada que permita:

- Instalar qualquer aplicativo MSI de forma silenciosa.
- Garantir que apenas a versão homologada permaneça instalada.
- Remover instalações paralelas (Store e user-level).
- Validar a integridade pós-instalação.
- Registrar todas as ações para auditoria e troubleshooting.
- Evitar reinstalações desnecessárias por diferenças de patch/build.

---

## 🧱 Arquitetura do Framework

O script é dividido em módulos funcionais:

### **1. Logging**
- Gera logs detalhados em `C:\Temp\Browser_deploy.log`.
- Registra erros, warnings e etapas do processo.

### **2. Detecção e Normalização de Versão**
- Extrai a versão do MSI sem instalá-lo (via COM WindowsInstaller).
- Normaliza versões para *major.minor* para evitar reinstalações desnecessárias.

### **3. Remoção de Instalações Paralelas**
- Remove versões instaladas via **Microsoft Store**.
- Remove instalações **user-level** em todos os perfis reais do Windows.

### **4. Desinstalação Silenciosa**
- Suporte a MSI (`msiexec /x`) e EXE (parâmetros genéricos).

### **5. Instalação Silenciosa**
- Instala o MSI homologado com `/qn /norestart`.
- Aguarda o término do processo `msiexec.exe`.

### **6. Validação de Atalhos**
- Verifica se o atalho existe e aponta para o executável correto.
- Recria automaticamente se necessário.

### **7. Retry Automático**
- Caso a validação falhe, o framework reinstala uma única vez.
- Evita loops infinitos.

---

## 🔄 Fluxo Completo da Automação

1. Detectar versão instalada.  
2. Comparar com versão homologada.  
3. Remover instalações paralelas (Store e user-level).  
4. Desinstalar silenciosamente (se necessário).  
5. Instalar MSI homologado.  
6. Validar atalho.  
7. Retry automático se necessário.  

---

## 📁 Estrutura do Repositório

📂 /MSI-Automation-Framework
│
├── ⚙️ APP_install.ps1          # Script principal do framework
└── 📄 README.md                # Documentação

---

## ▶️ Como Executar

1. Coloque o script e os arquivos MSI no mesmo diretório.  
2. Abra o PowerShell como administrador.  
3. Execute:
- .\APP_install.ps1
5. O log será gerado automaticamente em: C:\Temp\Browser_deploy.log

---

## 🧩 Como Adaptar para Qualquer Aplicativo MSI

1. Coloque o script e os arquivos MSI no mesmo diretório.
$MeuApp = @{
  Name = "Nome do App"
  MSI  = "$PSScriptRoot\MeuApp.msi"
}

2. Crie funções específicas para as seguintes funções genéricas
- Remove-StoreApp
- Remove-UserLevelAppAllUsers
- Ensure-AppWithRetry
- Ensure-Shortcut

3. Crie a função do fluxo principal
- Função "Seu APP aqui"

4. Faça a chamada à execução da função criada acima
- Install "Seu APP aqui"


