# 🛠️ **[Template Base](./Templates/powershell/templatescriptsPS.ps1/)**: Toolkit Interativo em PowerShell

Este arquivo é o motor principal do repositório. Ele não é uma ferramenta de auditoria por si só, mas sim um **esqueleto arquitetural padronizado** para a criação rápida de menus interativos em console.

O código foi desenhado para abstrair toda a complexidade visual e de registro (logging), permitindo que você foque 100% na lógica dos comandos.

## 🧠 Anatomia do Template

O script está dividido em 5 blocos imutáveis (núcleo) e 1 bloco editável (onde as automações entram).

1. **Configurações Gerais:** Define as variáveis de cores (`$CorPrimaria`, etc.) e suprime barras de progresso nativas para manter a tela limpa.
2. **Inicialização de Sessão:** Coleta os dados de *Situational Awareness* (`whoami`, `$env:COMPUTERNAME`, `Get-Date`) e gera o cabeçalho automático no arquivo de log, garantindo que você saiba exatamente em qual alvo o script foi rodado.
3. **Funções Utilitárias:** * `Invoke-SaveLog`: Trata o *prompt* de confirmação ("Deseja salvar o resultado? (s/n)") e injeta a saída no arquivo de texto.
4. **Módulos de Automação (`$cmds`):** Um dicionário (*Hashtable*) onde você irá plugar seus scripts.
5. **Motor do Menu:** Um loop `while ($true)` que lê as chaves do dicionário, renderiza as opções na tela em ordem alfabética/numérica e gerencia a invocação dos blocos de código.
