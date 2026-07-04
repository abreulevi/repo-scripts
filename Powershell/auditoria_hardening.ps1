<#
.SYNOPSIS
    Toolkit Interativo de Auditoria e Enumeracao para Hardening de Sistemas em PowerShell.
.DESCRIPTION
    Script desenvolvido para automatizar a coleta de informacoes de hardware,
    estado do sistema operacional, usuarios, politicas de grupo, servicos
    vulneraveis e configuracoes de seguranca local.
    Ideal para rotinas de Hardening ou fases de auditorias.
#>

# ==========================================
# 1. VARIAVEIS GERAIS E CONFIGURACOES
# ==========================================
$TituloScript  = "AUDITORIA E ENUMERACAO PARA HARDENING DE SISTEMA"
$CorPrimaria   = "Cyan"
$CorSecundaria = "Yellow"
$CorSucesso    = "Green"
$CorErro       = "Red"

$ProgressPreference = 'SilentlyContinue'

Clear-Host
Write-Host "--- CONFIGURACAO DE LOGS ---" -ForegroundColor $CorPrimaria

# Define diretorio de saida com fallback para C:\Temp
$caminhoPasta = Read-Host "Digite o caminho da pasta onde salvar o log (Pressione Enter para C:\Temp)"
if ([string]::IsNullOrWhiteSpace($caminhoPasta)) { $caminhoPasta = "C:\Temp" }

# Define nome do arquivo com fallback
$nomeArquivo  = Read-Host "Digite o nome do arquivo (Pressione Enter para log_auditoria.txt)"
if ([string]::IsNullOrWhiteSpace($nomeArquivo)) { $nomeArquivo = "log_auditoria.txt" }

# Cria o diretorio caso nao exista
if (-not (Test-Path $caminhoPasta)) { New-Item -ItemType Directory -Path $caminhoPasta | Out-Null }
$arquivoLog = Join-Path -Path $caminhoPasta -ChildPath $nomeArquivo

# =======================================================
# 2. INICIALIZACAO E REGISTRO DE SESSAO
# =======================================================
Write-Host "`n[*] Inicializando ambiente e registrando sessao..." -ForegroundColor DarkGray

# Captura contexto do usuario para documentacao do teste
$DataInicio   = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'
$UsuarioAtual = whoami
$NomeMaquina  = $env:COMPUTERNAME

$CabecalhoSessao = @"
===========================================================================
           AUDITORIA E ENUMERACAO PARA HARDENING DE SISTEMA
===========================================================================
Data/Hora Execucao : $DataInicio
Maquina Alvo       : $NomeMaquina
Usuario (Contexto) : $UsuarioAtual
===========================================================================

"@

try {
    $CabecalhoSessao | Out-File -FilePath $arquivoLog -Append -Encoding UTF8
    Write-Host "[+] Cabecalho de sessao salvo em: $arquivoLog`n" -ForegroundColor $CorSucesso
} catch {
    Write-Host "[-] Falha ao criar o arquivo de log inicial. Verifique permissoes." -ForegroundColor $CorErro
}

Start-Sleep -Seconds 2

# ==========================================
# 3. FUNCOES UTILITARIAS
# ==========================================

<#
.SYNOPSIS
    Gerencia a decisao do usuario e a gravacao segura dos resultados em arquivo de texto.
.DESCRIPTION
    Usa o encoding 'Default' para mitigar problemas de acentuacao ao abrir o log em editores simples no Windows.
#>
function Invoke-SaveLog {
    param (
        [Parameter(Mandatory)]$dados,
        [Parameter(Mandatory)]$arquivo,
        [Parameter(Mandatory)]$descricao
    )

    $decisao = Read-Host "`nDeseja salvar o resultado de '$descricao'? (s/n)"

    if ($decisao.ToLower() -ne "s") {
        Write-Host "[!] Resultado nao foi salvo." -ForegroundColor Yellow
        return
    }

    try {
        # O encoding Default costuma resolver os problemas de acentuacao no Bloco de Notas do Windows
        "--- $descricao - $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') ---" | Out-File -FilePath $arquivo -Append -Encoding Default
        $dados | Out-File -FilePath $arquivo -Append -Encoding Default
        "" | Out-File -FilePath $arquivo -Append -Encoding Default
        Write-Host "[+] Resultado salvo com sucesso!" -ForegroundColor $CorSucesso
    } catch {
        Write-Host "[-] Erro ao salvar no arquivo: $_" -ForegroundColor $CorErro
    }
}

<#
.SYNOPSIS
    Formata objetos complexos em strings limpas para exibicao no console e registro em log.
#>
function Write-Section {
    param(
        [Parameter(Mandatory)][string]$Titulo,
        [Parameter(Mandatory)][object]$Dados,
        [ValidateSet("Table","List")][string]$Formato = "Table"
    )

    # Verifica se a consulta retornou resultados vazios
    if ($null -eq $Dados -or $Dados.Count -eq 0) {
        return "=== $Titulo ===`r`nNenhum dado disponivel.`r`n"
    }

    $saidaDados = ""
    switch ($Formato) {
        # Gera um bloco unico de texto pronto para o log e exibe no console
        "Table" { $saidaDados = ($Dados | Format-Table -AutoSize | Out-String) }
        "List"  { $saidaDados = ($Dados | Format-List | Out-String) }
    }

    return "=== $Titulo ===`r`n$saidaDados"
}

# ==========================================
# 4. MODULOS DE AUTOMACAO
# ==========================================
$cmds = @{
    
    "01" = @{
        desc = "Informacoes do Sistema/Hardware"
        # Situational Awareness basico: entende a arquitetura e dominio para guiar os proximos passos.
        # Corrigido: CsSytemType -> CsSystemType
        cmd  = { return Write-Section -Titulo "Hardware e Sistema Operacional" -Dados (Get-ComputerInfo | Select-Object CsManufacturer, CsModel, CsSystemType, CsName, CsDNSHostName, CsDomain, CsWorkgroup, OsName, OsVersion, OsArchitecture, OsStatus, OsRegisteredUser) -Formato List }
    }
    "02" = @{
        desc = "Gestao de Atualizacoes (Hotfixes) - 5 mais recentes"
        # Essencial para identificar se o alvo e vulneravel a exploits de Kernel ou falhas de privilegio conhecidas.
        cmd  = { return Write-Section -Titulo "Top 5 Hotfixes Recentes" -Dados (Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 5 | Select-Object HotFixID, Description, InstalledOn) -Formato Table }
    }
    "03" = @{
        desc = "Estado do Windows Defender"
        # Verifica defesas locais ativas antes de executar binarios ou scripts agressivos.
        cmd  = { return Write-Section -Titulo "Status Windows Defender" -Dados (Get-MpComputerStatus | Select-Object RealTimeProtectionEnabled, AntivirusEnabled, AntispywareEnabled, IsTamperProtected) -Formato List }
    }
    "04" = @{
        desc = "Ultima inicializacao"
        # Ajuda a determinar se alteracoes pendentes de reboot estao aguardando ou a estabilidade do host.
        cmd  = { return Write-Section -Titulo "Uptime do Sistema" -Dados (Get-CimInstance Win32_OperatingSystem | Select-Object @{Name="Tempo desde a ultima inicializacao";Expression={(Get-Date) - $_.LastBootUpTime}}) -Formato List }
    }
    "05" = @{
        desc = "Politicas de Grupo (GPO)"
        # Mapeia restricoes locais ou configuracoes forcadas pelo AD.
        cmd  = { return Write-Section -Titulo "Políticas de Grupo Ativas (HKLM)" -Dados (Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies") -Formato Table }
    }
    "06" = @{
        desc = "Compartilhamentos SMB com permissao de acesso"
        # Procura por shares nao-padrao que possam conter scripts, senhas em texto claro ou arquivos sensiveis.
        cmd  = { return Write-Section -Titulo "Compartilhamentos SMB" -Dados (Get-SmbShare | Where-Object { $_.Name -notmatch '^(IPC\$|ADMIN\$|[A-Z]\$)$' } | Get-SmbShareAccess | Select-Object Name, AccountName, AccessRight, AccessControlType) -Formato Table }
    }
    "07" = @{
        desc = "Comandos de Inicializacao"
        # Identifica mecanismos de persistencia ou aplicacoes de terceiros que inicializam com o sistema.
        cmd  = { return Write-Section -Titulo "Comandos de Startup (Run)" -Dados (Get-CimInstance Win32_StartupCommand | Where-Object {$_.Location -like "*Run*"}) -Formato Table }
    }
    "08" = @{
        desc = "Processos em Execucao"
        # Enumera softwares rodando em background que possam ter vulnerabilidades exploraveis.
        cmd  = { return Write-Section -Titulo "Processos Ativos" -Dados (Get-Process | Select-Object Name, Id) -Formato Table }
    }
    "09" = @{
        desc = "Estado de Perfis de Firewall"
        # Determina quais regras (Dominio, Privado, Publico) estao filtrando conexoes de entrada/saida (importante para reverse shells).
        cmd  = { return Write-Section -Titulo "Perfis de Firewall" -Dados (Get-NetFirewallProfile | Select-Object Name, Enabled) -Formato Table }
    }
    "10" = @{
        desc = "Politica de Senhas"
        # Crucial para evitar bloqueio de contas (lockout) durante testes de forca-bruta locais.
        cmd  = { return Write-Section -Titulo "Politicas de Senha Locais" -Dados (net accounts) -Formato List }
    }
    "11" = @{
        desc = "Servicos vulneraveis a Unquoted Service Path (fora do dir Windows)"
        # Vetor classico de PrivEsc. Busca caminhos com espaco e sem aspas onde um binario malicioso pode ser plantado.
        cmd  = { return Write-Section -Titulo "Potenciais Unquoted Service Paths" -Dados (Get-CimInstance Win32_Service | Where-Object { $_.PathName -notmatch '^"' -and $_.PathName -match ' ' -and $_.PathName -notmatch '(?i)\\Windows\\' -and $_.StartMode -ne 'Disabled' } | Select-Object Name, DisplayName, PathName, StartMode) -Formato Table }
    }
    "12" = @{
        desc = "Servicos Auto iniciados com LocalSystem e caminho fora do System32"
        # Outro forte vetor de PrivEsc. Identifica servicos rodando como SYSTEM em diretorios onde usuarios comuns podem ter permissao de escrita.
        cmd  = { return Write-Section -Titulo "Serviços Auto com LocalSystem (Fora do System32)" -Dados (Get-CimInstance Win32_Service | Where-Object { $_.StartMode -eq 'Auto' -and $_.StartName -eq 'LocalSystem' -and $_.PathName -notmatch 'Windows\\System32' } | Select-Object Name, DisplayName, PathName) -Formato Table }
    }
    "13" = @{
        desc = "Tarefas Agendadas Ativas fora do Microsoft"
        # Analisa tasks de terceiros que podem ser abusadas para execucao de codigo com privilegios elevados.
        cmd  = { return Write-Section -Titulo "Tarefas Agendadas Ativas (Third-Party)" -Dados (Get-ScheduledTask | Where-Object { $_.State -ne 'Disabled' -and $_.TaskPath -notmatch '^\\Microsoft\\' } | Select-Object TaskName, TaskPath, State, Principal) -Formato Table }
    }
    "14" = @{
        desc = "Usuarios Locais Ativos"
        # Mapeia possiveis contas alvo e identifica se senhas sao exigidas.
        cmd  = { return Write-Section -Titulo "Usuários Locais Ativos" -Dados (Get-LocalUser | Where-Object { $_.Enabled -eq $true } | Select-Object Name, PasswordRequired, PasswordLastSet, LastLogon) -Formato Table }
    }
    "15" = @{
        desc = "Mapeamento de Membros do Grupo Administradores Locais"
        # Define o "alvo final" (as contas que tem controle total da maquina).
        cmd  = { return Write-Section -Titulo "Membros do Grupo Administradores" -Dados (Get-LocalGroupMember -Group "Administradores" -ErrorAction SilentlyContinue | Select-Object Name, ObjectClass, PrincipalSource) -Formato Table }
    }
}

# ==========================================
# 5. MOTOR DO MENU INTERATIVO
# ==========================================
while ($true) {
    Write-Host "==========================================================================" -ForegroundColor $CorSecundaria
    Write-Host "    MENU PRINCIPAL: $TituloScript" -ForegroundColor $CorPrimaria
    Write-Host "==========================================================================`n" -ForegroundColor $CorSecundaria
    
    foreach ($opcao in $cmds.Keys | Sort-Object) {
        Write-Host " [$opcao] - $($cmds[$opcao].desc)"
    }
    
    Write-Host "`n [q]  - Sair da Ferramenta" -ForegroundColor DarkGray
    Write-Host "`nEscolha uma opcao: " -ForegroundColor $CorPrimaria -NoNewline
    
    $escolha = Read-Host

    if ($escolha.ToLower() -eq 'q') { 
        Write-Host "`nEncerrando a ferramenta..." -ForegroundColor $CorSecundaria
        break 
    }

    if ($cmds.ContainsKey($escolha)) {
        Clear-Host
        Write-Host "[*] Executando: $($cmds[$escolha].desc)" -ForegroundColor $CorPrimaria
        
        $resultado = & $cmds[$escolha].cmd
        
        $resultado | Out-Host
        
        Invoke-SaveLog -dados $resultado -arquivo $arquivoLog -descricao $cmds[$escolha].desc
        
        Write-Host "`nPressione 'Enter' para voltar ao menu principal..." -ForegroundColor DarkGray
        $null = Read-Host
        Clear-Host
    } else {
        Write-Host "`n[-] Opcao invalida! Tente novamente." -ForegroundColor $CorErro
        Start-Sleep -Seconds 2
        Clear-Host
    }
}
