# 💻 Toolkit Interativo: **[Auditoria e Enumeração de Sistema](./Powershell/auditoria_hardening.ps1)**

Este script em PowerShell foi desenhado para automatizar a coleta minuciosa de informações locais de um sistema operacional Windows. Ele é a ferramenta ideal para rotinas de *Hardening* e *Auditoria* .

## 🎯 O que este script faz?

Através de um menu interativo, o script varre o sistema em busca de configurações, serviços e políticas, organizando a saída em tabelas e listas de fácil leitura. E conta com um **sistema de logging integrado**, exportando os achados para um arquivo de texto (padrão em `C:\Temp\log_auditoria.txt`) com cabeçalho de sessão contendo data, máquina e usuário em contexto.

## ⚙️ Módulos de Enumeração Disponíveis

O script possui 15 opções de varredura, que podem ser divididas nestes pilares:

* **Situational Awareness & Defesas:** Coleta informações de Hardware, versão do SO (Opção 01), Uptime (Opção 04), perfis de Firewall (Opção 09) e o status atual do Windows Defender (Opção 03).
* **Superfície de Ataque e Exploração:** Lista os 5 Hotfixes mais recentes instalados (Opção 02) para checagem de vulnerabilidades conhecidas de Kernel, além de mapear Processos Ativos (Opção 08) e Compartilhamentos SMB (Opção 06).
* **Vetores Clássicos de PrivEsc:** Automatiza a busca por configurações incorretas que permitem elevação de privilégio, como:
  * *Unquoted Service Paths* (Opção 11).
  * Serviços de terceiros rodando como `LocalSystem` fora da pasta Windows (Opção 12).
  * Tarefas Agendadas ativas de terceiros (Opção 13).
  * Comandos de Inicialização (Run) (Opção 07).
* **Identidade e Acessos:** Enumera Políticas de Senha (Opção 10), GPOs ativas (Opção 05), Usuários Locais ativos (Opção 14) e os membros do cobiçado grupo de Administradores Locais (Opção 15).

## 🚀 Como Usar

1. Baixe o arquivo do script para a máquina alvo.
2. Abra o terminal do PowerShell.
3. Para garantir que o script rode sem ser bloqueado pelas políticas nativas do Windows, execute:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
