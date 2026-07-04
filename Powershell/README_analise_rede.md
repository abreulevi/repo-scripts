# 🌐 Toolkit Interativo: **[Testes e Auditoria de Rede](./analise_rede.ps1)**

Este script foi desenvolvido em PowerShell para automatizar coleta de informações de conexão de um host e testes de conectividade. É uma ferramenta interativa excelente para auditorias locais e *troubleshooting* em redes.

## 🎯 O que este script faz?

A ferramenta opera através de um menu interativo e consolida todas as saídas no console de forma limpa. O principal diferencial é o **sistema automático de logs**: a cada execução, o script registra a máquina alvo, o usuário em contexto e o *timestamp*, permitindo exportar blocos específicos de informação para um arquivo de texto puro (padrão em `C:\Temp\relatorio_auditoria.txt`).

## ⚙️ Módulos Disponíveis

O script atualmente conta com as seguintes opções de automação:

1. **Configuração de Rede e Conectividade:** Faz um levantamento completo do IP, Gateway e DNS. Testa a resolução de nomes (DNS interno e externo) e realiza testes automáticos de ICMP (Ping) e rotas (TraceRoute) para a internet.
2. **Teste Específico de Conexão TCP:** Permite interagir com o terminal para testar o acesso a hosts e portas específicas de forma contínua, sem precisar sair do menu.
3. **Conexões TCP Ativas:** Lista as portas abertas (Listening) e as conexões já estabelecidas (Established). Útil para descobrir serviços locais rodando silenciosamente no alvo.
4. **Tabela de Roteamento IPv4:** Mapeia todas as rotas ativas da máquina para identificar subredes locais e regras de tráfego.

## 🚀 Como Usar

1. Baixe o arquivo `analise_rede.ps1`.
2. Abra o terminal do PowerShell.
3. (Recomendado) Para evitar bloqueios de segurança nativos do Windows ao rodar scripts locais, ajuste a política de execução temporariamente:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
