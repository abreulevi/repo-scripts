<#
.SYNOPSIS
    Template Definitivo para Toolkits Interativos no PowerShell.

.DESCRIPTION
    Este script e uma base padronizada para criar menus interativos no console,
    com foco em auditoria, enumeracao e operacoes de infraestrutura. Ele resolve
    automaticamente a formatação em tela e a exportação para arquivos de texto puro.

    ===========================================================================
    COMO USAR E EXPANDIR ESTE TEMPLATE (DICAS DE DESENVOLVIMENTO):
    ===========================================================================
    
    1. ONDE ADICIONAR SEUS SCRIPTS:
       Toda a lógica das opções do menu fica na variável `$cmds` (uma Hashtable), 
       localizada no bloco "4. MODULOS DE AUTOMACAO".
       
    2. COMO CRIAR UMA NOVA OPCAO:
       Basta criar um novo número e seguir a estrutura exata abaixo:
       
       "03" = @{
           desc = "Nome da Tarefa que aparece no Menu"
           cmd  = {
               # 1. Coloque seus comandos PowerShell aqui.
               $dadosBrutos = Get-Process
               
               # 2. SEMPRE encerre o bloco com 'return Write-Section'. 
               # Isso garante que a tela e o arquivo de log recebam o texto 100% formatado,
               # evitando o erro de "System.Object[]".
               return Write-Section -Titulo "Meus Processos" -Dados $dadosBrutos -Formato Table
           }
       }

    3. FORMATACAO (Table vs List):
       No final do comando 'Write-Section', você pode escolher:
       -Formato Table : Ideal para saídas curtas com várias colunas (ex: Get-Process).
       -Formato List  : Ideal para saídas com textos longos ou propriedades extensas (ex: WMI/CIM).

    4. MULTIPLOS BLOCOS NA MESMA OPCAO:
       Se uma única opção do menu precisar rodar várias coisas, acumule os resultados
       em uma variável de array e retorne ela no final, assim:
       
       cmd = {
           $relatorio = @()
           $relatorio += Write-Section -Titulo "Alvo 1" -Dados (Ping 8.8.8.8) -Formato List
           $relatorio += Write-Section -Titulo "Alvo 2" -Dados (Ping 1.1.1.1) -Formato List
           return $relatorio
       }
#>

# ==========================================
# 1. VARIAVEIS GERAIS E CONFIGURACOES
# ==========================================
$TituloScript  = "TOOLKIT DE ENUMERACAO BASE"
$CorPrimaria   = "Cyan"
$CorSecundaria = "Yellow"
$CorSucesso    = "Green"
$CorErro       = "Red"

$ProgressPreference = 'SilentlyContinue'

Clear-Host
Write-Host "--- CONFIGURACAO DE LOGS ---" -ForegroundColor $CorPrimaria

$caminhoPasta = Read-Host "Digite o caminho da pasta onde salvar o log (Pressione Enter para C:\Temp)"
if ([string]::IsNullOrWhiteSpace($caminhoPasta)) { $caminhoPasta = "C:\Temp" }

$nomeArquivo  = Read-Host "Digite o nome do arquivo (Pressione Enter para log_toolkit.txt)"
if ([string]::IsNullOrWhiteSpace($nomeArquivo)) { $nomeArquivo = "log_toolkit.txt" }

if (-not (Test-Path $caminhoPasta)) { New-Item -ItemType Directory -Path $caminhoPasta | Out-Null }
$arquivoLog = Join-Path -Path $caminhoPasta -ChildPath $nomeArquivo

# =======================================================
# 2. INICIALIZACAO E REGISTRO DE SESSAO
# =======================================================
Write-Host "`n[*] Inicializando ambiente e registrando sessao..." -ForegroundColor DarkGray

$DataInicio   = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'
$UsuarioAtual = whoami
$NomeMaquina  = $env:COMPUTERNAME

$CabecalhoSessao = @"
===========================================================
             $TituloScript
===========================================================
Data/Hora Execucao : $DataInicio
Maquina Alvo       : $NomeMaquina
Usuario (Contexto) : $UsuarioAtual
===========================================================

"@

try {
    # Encoding Default previne falhas de acentuacao ao abrir no Bloco de Notas
    $CabecalhoSessao | Out-File -FilePath $arquivoLog -Append -Encoding Default
    Write-Host "[+] Cabecalho de sessao salvo em: $arquivoLog`n" -ForegroundColor $CorSucesso
} catch {
    Write-Host "[-] Falha ao criar o arquivo de log inicial. Verifique permissoes." -ForegroundColor $CorErro
}

Start-Sleep -Seconds 2

# ==========================================
# 3. FUNCOES UTILITARIAS (NAO ALTERAR)
# ==========================================
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
        "--- $descricao - $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') ---" | Out-File -FilePath $arquivo -Append -Encoding Default
        $dados | Out-File -FilePath $arquivo -Append -Encoding Default
        "" | Out-File -FilePath $arquivo -Append -Encoding Default
        Write-Host "[+] Resultado salvo com sucesso!" -ForegroundColor $CorSucesso
    } catch {
        Write-Host "[-] Erro ao salvar no arquivo: $_" -ForegroundColor $CorErro
    }
}

function Write-Section {
    param(
        [Parameter(Mandatory)][string]$Titulo,
        [Parameter(Mandatory)][object]$Dados,
        [ValidateSet("Table","List")][string]$Formato = "Table"
    )

    # Verifica se a variavel de dados esta vazia para evitar saidas em branco no log
    if ($null -eq $Dados -or $Dados.Count -eq 0) {
        return "=== $Titulo ===`r`nNenhum dado disponivel ou enumerado.`r`n"
    }

    $saidaDados = ""
    switch ($Formato) {
        # O Out-String (sem -Stream) garante que o PowerShell consolide tudo em um unico bloco de texto
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
        desc = "Enumeracao Basica (Exemplo em Tabela)"
        cmd  = { 
            # Exemplo de comando que traz resultados formatados em colunas
            $conexoes = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object LocalAddress, LocalPort, State
            return Write-Section -Titulo "Portas TCP em Escuta" -Dados $conexoes -Formato Table 
        }
    }
    "02" = @{
        desc = "Resolucao de Nome (Exemplo em Lista)"
        cmd  = { 
            # Exemplo de comando mais verboso, ideal para o formato de Lista
            $alvo = Read-Host "Digite o dominio para resolucao (ex: google.com)"
            $resolucao = Resolve-DnsName -Name $alvo -ErrorAction SilentlyContinue
            return Write-Section -Titulo "Resultados de DNS para $alvo" -Dados $resolucao -Formato List 
        }
    }
}

# ==========================================
# 5. MOTOR DO MENU INTERATIVO (NAO ALTERAR)
# ==========================================
while ($true) {
    Write-Host "=================================================" -ForegroundColor $CorSecundaria
    Write-Host "     MENU PRINCIPAL: $TituloScript" -ForegroundColor $CorPrimaria
    Write-Host "=================================================`n" -ForegroundColor $CorSecundaria
    
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
