<#
.SYNOPSIS
    Toolkit de Testes e Auditoria de Rede em PowerShell.
.DESCRIPTION
    Script desenvolvido para automatizar a coleta de informacoes de host, 
    testes de conectividade, mapeamento de rotas e conexoes TCP ativas. 
    Excelente para enumeracao local e troubleshootings. O script gera um log 
    centralizado em formato de texto puro, registrando automaticamente 
    a maquina alvo, usuario em contexto e timestamp da execucao.
#>

# ==========================================
# 1. CONFIGURACOES GERAIS E LOGS
# ==========================================
# Definicao de paleta de cores para facilitar a leitura no console
$TituloScript  = "TESTES/AUDITORIA DE REDE"
$CorPrimaria   = "Cyan"
$CorSecundaria = "Yellow"
$CorSucesso    = "Green"
$CorErro       = "Red"

# Oculta barras de progresso nativas do PowerShell para uma saida mais limpa
$ProgressPreference = 'SilentlyContinue'

Clear-Host
Write-Host "--- CONFIGURACAO DE LOGS ---" -ForegroundColor $CorPrimaria

# Coleta o caminho do log. Usa 'C:\Temp' como fallback caso o usuario deixe em branco.
$caminhoPasta = Read-Host "Digite o caminho da pasta onde salvar o log (ex: C:\Temp\)"
if ([string]::IsNullOrWhiteSpace($caminhoPasta)) { $caminhoPasta = "C:\Temp" }

# Coleta o nome do arquivo. Usa 'relatorio_auditoria.txt' como fallback.
$nomeArquivo  = Read-Host "Digite o nome do arquivo (ex: relatorio.txt)"
if ([string]::IsNullOrWhiteSpace($nomeArquivo)) { $nomeArquivo = "relatorio_auditoria.txt" }

# Verifica se o diretorio de destino existe; caso contrario, cria a pasta silenciosamente.
if (-not (Test-Path $caminhoPasta)) { New-Item -ItemType Directory -Path $caminhoPasta | Out-Null }
$arquivoLog   = Join-Path -Path $caminhoPasta -ChildPath $nomeArquivo


# =======================================================
# 2. COLETA DE INFORMACOES DO HOST (FOOTPRINTING INICIAL)
# =======================================================
Write-Host "`n[*] Coletando informacoes do host alvo..." -ForegroundColor DarkGray

# Captura informacoes de contexto para o cabecalho (util para identificar o alvo em avaliacoes)
$DataInicio   = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'
$UsuarioAtual = whoami
$NomeMaquina  = $env:COMPUTERNAME

# Cria o Banner de Sessao padronizado
$CabecalhoSessao = @"
===========================================================
            TESTES/AUDITORIA DE REDE
===========================================================
Data/Hora Execucao : $DataInicio
Maquina Alvo       : $NomeMaquina
Usuario (Contexto) : $UsuarioAtual
===========================================================

"@

# Tenta salvar o banner automaticamente no inicio do arquivo de log
try {
    $CabecalhoSessao | Out-File -FilePath $arquivoLog -Append -Encoding UTF8
    Write-Host "[+] Cabecalho de sessao salvo em: $arquivoLog`n" -ForegroundColor $CorSucesso
} catch {
    Write-Host "[-] Falha ao criar o arquivo de log inicial. Verifique permissoes de escrita." -ForegroundColor $CorErro
}

Start-Sleep -Seconds 2

# ==========================================
# 3. FUNCOES BASE (NUCLEO DO SCRIPT)
# ==========================================

<#
.SYNOPSIS
    Interage com o usuario para decidir se o resultado da execucao deve ser salvo em log.
.PARAMETER dados
    O objeto ou string contendo o resultado da execucao.
.PARAMETER arquivo
    O caminho completo do arquivo de log.
.PARAMETER descricao
    O titulo/descricao do comando que acabou de ser executado.
#>
function Invoke-SaveLog {
    param (
        [Parameter(Mandatory)]$dados,
        [Parameter(Mandatory)]$arquivo,
        [Parameter(Mandatory)]$descricao
    )

    $decisao = Read-Host "`nDeseja salvar o resultado de '$descricao'? (s/n)"

    # Interrompe a gravacao caso o usuario digite algo diferente de 's'
    if ($decisao.ToLower() -ne "s") {
        Write-Host "[!] Resultado nao foi salvo." -ForegroundColor Yellow
        return
    }

    try {
        # Formata o bloco com divisoria temporal
        "--- $descricao - $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') ---" | Out-File -FilePath $arquivo -Append -Encoding UTF8
        
        # Converte o array de dados para string garantindo quebras de linha corretas no Windows (`r`n)
        $dados -join "`r`n" | Out-File -FilePath $arquivo -Append -Encoding UTF8
        
        # Adiciona uma linha em branco para separar blocos futuros
        "" | Out-File -FilePath $arquivo -Append -Encoding UTF8

        Write-Host "[+] Resultado salvo com sucesso!" -ForegroundColor $CorSucesso
    }
    catch {
        Write-Host "[-] Erro ao salvar no arquivo: $_" -ForegroundColor $CorErro
    }
}

<#
.SYNOPSIS
    Formata dados extraidos em blocos padronizados (Tabela ou Lista) para exibicao e log.
.PARAMETER Titulo
    Cabecalho da secao atual.
.PARAMETER Dados
    O objeto retornado pelos cmdlets (ex: Get-NetTCPConnection).
.PARAMETER Formato
    Define se a saida sera em Tabela ('Table') ou Lista ('List'). O padrao e Table.
#>
function Write-Section {
    param(
        [Parameter(Mandatory)][string]$Titulo,
        [Parameter(Mandatory)][object]$Dados,
        [ValidateSet("Table","List")][string]$Formato = "Table"
    )

    # Tratamento caso a consulta nao retorne nada (ex: sem conexoes ativas)
    if ($null -eq $Dados) {
        return @(
            "=== $Titulo ==="
            "Nenhum dado disponivel."
            ""
        )
    }

    # Aplica a formatacao escolhida utilizando Out-String para converter objetos em texto puro
    switch ($Formato) {
        "Table" {
            return @(
                "=== $Titulo ==="
                # O parametro -Stream resolve os bugs de sobreposicao de cursor e converte o array corretamente
                ($Dados | Format-Table -AutoSize | Out-String -Stream)
                ""
            )
        }

        "List" {
            return @(
                "=== $Titulo ==="
                ($Dados | Format-List | Out-String -Stream)
                ""
            )
        }
    }
}

# ==========================================
# 4. MODULOS DE AUTOMACAO (DICIONARIO)
# ==========================================
# O dicionario $cmds facilita a escalabilidade. 
# Para adicionar novas ferramentas de scanner ou enumeracao, crie uma nova chave ("5", "6").
$cmds = @{
    "1" = @{
        desc = "Informacoes de Configuracao de Rede e Testes de Conectividade"
        cmd = {
            $relatorio = @()

            # 1. Configuracao de Rede (IP, Gateway, DNS)
            $config = Get-NetIPConfiguration | Select-Object InterfaceAlias,
                @{Name='IPv4';Expression={$_.IPv4Address.IPAddress}},
                @{Name='Gateway';Expression={$_.IPv4DefaultGateway.NextHop}},
                @{Name='DNS';Expression={$_.DNSServer.ServerAddresses -join ', '}}

            $relatorio += Write-Section -Titulo "Configuracao de Interfaces e IP" -Dados $config

            # 2. Status fisico dos Adaptadores (interfaces de rede)
            $adaptadores = Get-NetAdapter | Select-Object Name,Status,LinkSpeed,MacAddress
            $relatorio += Write-Section -Titulo "Status dos Adaptadores Fisicos" -Dados $adaptadores

            # 3. Identificacao e Teste do DNS Interno (Analise de rota e resolucao)
            $dnsInterno = $null
            # Busca a interface que responde pela rota padrao da internet
            $rotaPadrao = Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Select-Object -First 1

            if ($rotaPadrao) {
                # Obtem o servidor DNS configurado na interface principal
                $dnsServer = (Get-DnsClientServerAddress -InterfaceIndex $rotaPadrao.ifIndex -AddressFamily IPv4).ServerAddresses | Select-Object -First 1

                if ($dnsServer) {
                    Write-Host "`nServidor DNS local detectado: $dnsServer" -ForegroundColor Green
                    # Tenta resolver um dominio externo usando o DNS local
                    $dnsInterno = Resolve-DnsName -Name "google.com" -Server $dnsServer -ErrorAction SilentlyContinue
                }
            }

            if (-not $dnsInterno) { $dnsInterno = "Sem resposta do DNS interno" }
            $relatorio += Write-Section -Titulo "Comunicacao com DNS Interno" -Dados $dnsInterno

            # 4. Teste de resolucao com DNS Externo (Google)
            $dnsExterno = Resolve-DnsName -Name "google.com" -Server 8.8.8.8 -ErrorAction SilentlyContinue
            $relatorio += Write-Section -Titulo "Comunicacao com DNS Externo" -Dados $dnsExterno

            # 5. Teste de Conectividade Geral (Ping e TraceRoute)
            $alvo = "8.8.8.8"
            Write-Host "`nTestando conectividade com $alvo..." -ForegroundColor Yellow
            $teste = Test-NetConnection -ComputerName $alvo
            
            $relatorio += Write-Section `
                -Titulo "Teste de Conectividade Externa" `
                -Dados ($teste | Select-Object ComputerName,RemoteAddress,InterfaceAlias,SourceAddress,PingSucceeded) `
                -Formato Table

            # Se o ping falhar, executa um TraceRoute para identificar onde o pacote esta caindo
            if (-not $teste.PingSucceeded) {
                $trace = Test-NetConnection -ComputerName $alvo -TraceRoute
                $relatorio += Write-Section -Titulo "Trace Route" -Dados $trace -Formato List
            }

            # 6. Mapeamento Geral de Rotas (util para identificar subredes locais)
            $rotas = Get-NetRoute -AddressFamily IPv4 | Select-Object DestinationPrefix,NextHop,InterfaceAlias
            $relatorio += Write-Section -Titulo "Tabela de Roteamento IPv4" -Dados $rotas

            return $relatorio
        }
    }

    "2" = @{ 
        desc = "Teste de Conexao TCP com Host e Porta Especificos"
        cmd  = { 
            $relatorio = @()
            do {
                Write-Host "`n=== Teste de Conexao TCP ===" -ForegroundColor Cyan
                
                # Coleta alvo e porta dinamicamente para scanning manual de porta
                $Servico = Read-Host "Digite o nome do host ou IP (ex: portal.empresa.com)"
                $Porta = Read-Host "Digite o numero da porta (ex: 443)"
                
                Write-Host "`nTestando a conexao com $Servico na porta $Porta... Aguarde.`n" -ForegroundColor Yellow
                
                $TestePorta = Test-NetConnection -ComputerName $Servico -Port $Porta -WarningAction SilentlyContinue
                
                $resultadoTeste = [PSCustomObject]@{
                    Alvo = $Servico
                    Porta = $Porta
                    Sucesso = $TestePorta.TcpTestSucceeded
                }

                # 1. Usa a funcao para formatar o texto e guarda numa variavel temporaria
                $blocoAtual = Write-Section -Titulo "Resultado TCP: $Servico : $Porta" -Dados $resultadoTeste -Formato Table
                
                # 2. IMPRIME IMEDIATAMENTE na tela
                $blocoAtual | Out-Host
                
                # 3. Acumula o resultado na variavel principal para log
                $relatorio += $blocoAtual
                
                Write-Host ""
                $Continuar = Read-Host "Deseja realizar uma nova consulta? (s/n)"
                
            } while ($Continuar -match "^[Ss]$")
            
            return $relatorio
        } 
    }

    "3" = @{ 
        desc = "Conexoes TCP Ativas e em Escuta"
        cmd  = { 
            # Filtra apenas portas abertas aguardando conexao (Listen) ou ativas (Established)
            # Extremamente util para identificar servicos em execucao no alvo
            $conexoes = Get-NetTCPConnection -State Listen, Established -ErrorAction SilentlyContinue | 
                        Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State | 
                        Select-Object -First 20 # Limita as 20 primeiras para nao poluir a tela
            
            $relatorio = Write-Section -Titulo "Top 20 Conexoes TCP (Listen/Established)" -Dados $conexoes -Formato Table
            
            return $relatorio
        }
    }

    "4" = @{ 
        desc = "Tabela de Roteamento IPv4 Ativa"
        cmd  = { 
            # Exibe as rotas ativas (util para descobrir interfaces escondidas ou cenarios de pivotamento)
            $roteamentoipv4 = Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
                              Select-Object DestinationPrefix, NextHop, InterfaceAlias
            
            $relatorio = Write-Section -Titulo "Tabela de Roteamento IPv4" -Dados $roteamentoipv4 -Formato Table
            
            return $relatorio
        }
    }
}

# ==========================================
# 5. MOTOR DO MENU INTERATIVO
# ==========================================
while ($true) {
    Write-Host "=================================================" -ForegroundColor $CorSecundaria
    Write-Host "    MENU PRINCIPAL: $TituloScript" -ForegroundColor $CorPrimaria
    Write-Host "=================================================`n" -ForegroundColor $CorSecundaria
    
    # Renderiza o menu automaticamente lendo e ordenando as chaves do dicionario
    foreach ($opcao in $cmds.Keys | Sort-Object) {
        Write-Host " [$opcao] - $($cmds[$opcao].desc)"
    }
    
    Write-Host "`n [q]  - Sair do Script" -ForegroundColor DarkGray
    Write-Host "`nEscolha uma opcao: " -ForegroundColor $CorPrimaria -NoNewline
    
    $escolha = Read-Host

    # Tratamento de saida do loop
    if ($escolha.ToLower() -eq 'q') { 
        Write-Host "`nEncerrando a ferramenta..." -ForegroundColor $CorSecundaria
        break 
    }

    # Verifica se a escolha informada pelo usuario existe no dicionario
    if ($cmds.ContainsKey($escolha)) {
        Clear-Host
        Write-Host "[*] Executando: $($cmds[$escolha].desc)" -ForegroundColor $CorPrimaria
        
        # Invoca o bloco de codigo correspondente a chave selecionada
        $resultado = & $cmds[$escolha].cmd
        
        # Exibe o resultado renderizado
        $resultado | Out-Host
        
        # Chama a funcao unificada para decisao de registro em log
        Invoke-SaveLog -dados $resultado -arquivo $arquivoLog -descricao $cmds[$escolha].desc
        
        # Pausa a tela para analise dos resultados antes de resetar o menu
        Write-Host "`nPressione 'Enter' para voltar ao menu principal..." -ForegroundColor DarkGray
        $null = Read-Host
        Clear-Host
    } else {
        Write-Host "`n[-] Opcao invalida! Tente novamente." -ForegroundColor $CorErro
        Start-Sleep -Seconds 2
        Clear-Host
    }
}
