# Arquitetura inicial — Coduva

**Proposta para validação, não uma implementação concluída.**

## 1. Separação em camadas

```text
┌───────────────────────────────────────────────────────┐
│ Interface Android (mobile-first, claro por padrão)    │
│ Editor • Abas • Mini Explorer • Terminal • Preview    │
└──────────────────────┬────────────────────────────────┘
                       │ APIs internas
┌──────────────────────▼────────────────────────────────┐
│ Núcleo de aplicação                                   │
│ Projetos • Permissões • Arquivos • Sessões • LSP      │
│ Instalações • Configurações • Logs • Segurança        │
└───────────────┬─────────────────┬─────────────────────┘
                │                 │
    ┌───────────▼─────────┐ ┌─────▼─────────────────────┐
    │ Ambiente local      │ │ Ambiente remoto           │
    │ Processos e shell   │ │ SSH / SFTP / encaminh.    │
    │ PHP / SQL / runtimes│ │ Terminal / arquivos       │
    └───────────┬─────────┘ └─────────────┬─────────────┘
                └────────────┬────────────┘
                             │
                     Editor e Preview
```

A interface **não deve conhecer detalhes de PRoot, SQL ou SSH**: ela recebe serviços e estados por contratos estáveis. O app continua editando texto mesmo quando nenhuma runtime estiver instalada.

## 2. Módulos recomendados

| Módulo | Responsabilidades |
| --- | --- |
| `workspace` | Árvore de projeto, abas, URI do documento, alterações pendentes, busca. |
| `editor` | Buffer de texto, cursor, seleção, realce, histórico, teclado Android, sugestões. |
| `language-services` | LSP, diagnósticos, símbolos, autoimports, snippets e servidores por linguagem. |
| `terminal` | Sessões local/remota, PTY quando possível, resizing e gerenciamento de estado. |
| `runtime-manager` | Manifestos de pacotes, versões, dependências, instalação, atualização e remoção. |
| `local-executor` | Processos Linux locais, filesystem de trabalho e controle de recursos. |
| `remote-executor` | SSH/SFTP, chaves do host, reconexão e port forwarding. |
| `web-preview` | WebView, localhost, reload, navegação e mensagens de erros. |
| `php-dev-server` | Inicialização/parada, portas, logs, document root e extensões PHP. |
| `database` | SQLite, conexões MySQL/MariaDB, consulta, esquema, histórico e credenciais. |
| `settings-security` | Preferências, armazenamento seguro e auditoria das permissões. |

Esses nomes representam responsabilidades, **não pastas ou linguagens de implementação já aprovadas**.

## 3. Escolhas técnicas a prototipar

### Camada de interface

**Candidata:** Flutter para UI Android e componentes mobile. Avaliar mecanismo de edição especializado:

- Editor nativo com buffer/seleção/IME corretamente integrados; ou
- Componente editor avançado WebView (ex.: CodeMirror 6) com uma ponte robusta para arquivos, LSP e teclado Android.

**Critério de decisão:** digitação fluida no celular, acentos, seleção por alças, composição IME, arquivos grandes, acessibilidade, estabilidade de cursor, scroll e consumo de memória. A aparência visual **não** deve decidir sozinha.

### Ambientes e Android

- Android possui limites diferentes dos de uma distribuição Linux comum. Não assumir que binários da distro executam diretamente no Android.
- Investigar userland com **PRoot** ou abordagem híbrida com executáveis nativos apropriados, sem root.
- Testar restrições de execução, processos em segundo plano, arquitetura ARM64, armazenamento executável e ciclo de vida do app por versão de Android.
- Trabalhos pesados e serviços não devem bloquear a thread de UI.
- Permitir encerrar/recuperar ambientes com estado consistente.

### Acesso a arquivos

- Integrar **Storage Access Framework (SAF)** para abrir documentos e pastas escolhidos pelo usuário, sem solicitar acesso amplo desnecessário.
- Tratar URIs Android separadamente de caminhos Linux. O SAF não equivale automaticamente a um diretório de filesystem POSIX.
- Para ferramentas Linux, criar uma camada explícita de workspace/sincronização ou espelhamento controlado, com preservação de alterações, conflitos e salvamento seguro.
- Não prometer que PHP, Git e MariaDB executarão diretamente em qualquer URI `content://`.

### PHP, SQL e prévia

- Servidor PHP local escuta **somente em loopback (127.0.0.1)** por padrão.
- Portas livres escolhidas por sessão, estado de processo visível e logs.
- WebView abre o servidor interno; bloquear exposições acidentais de diretórios/arquivos sensíveis.
- A API de banco trata SQLite e MariaDB/MySQL como **drivers distintos**.
- MariaDB local precisa de diretório de dados, bootstrap, configuração, credenciais iniciais, backup, ciclo de vida e verificação de versão. **Executabilidade e desempenho em Android sem root são provas obrigatórias.**
- Distinguir: "conectar ao MySQL remoto" ≠ "rodar MariaDB local".
- SQLite pode operar diretamente no próprio processo conforme a runtime escolhida.

### Autocompletar

- Um serviço de linguagem por sessão/workspace, iniciado sob demanda.
- Associar LSP a documento, linguagem, versão de buffer e workspace; cancelar resultados obsoletos.
- PHP, JS/TS, HTML e CSS exigem servidores adequados, com verificação de licenças; SQL pode usar indexação de esquema e sugestões.
- Fall back para palavras locais e snippets sem server ativo, mantendo latência baixa.
- Nunca enviar código a IA ou serviço remoto sem escolha explícita do usuário.

### Remoto

- Usar autenticação SSH segura e checagem de fingerprint conhecida; não aceitar chaves arbitrárias silenciosamente.
- Armazenar chaves/senhas com solução de segurança do Android; apagar dados em logout quando solicitado.
- SFTP opera com salvamento protegido e detecção de conflitos de arquivos.
- Execução remota e prévia via encaminhamento de portas devem estar claramente indicadas como "remoto".

## 4. Contratos funcionais a definir antes do código

- `WorkspaceProvider`: `list`, `read`, `write`, `watch`, `create`, `delete`, `rename`, `resolve`.
- `ExecutionSession`: `start`, `stdin`, `stdout`, `stderr`, `resize`, `stop`, `exitCode`.
- `RuntimeCatalog`: `listAvailable`, `checkCompatibility`, `install`, `update`, `remove`.
- `PreviewSession`: `startServer`, `url`, `reload`, `logs`, `stop`.
- `DatabaseConnection`: `connect`, `query`, `schema`, `disconnect`.
- `LanguageService`: `completion`, `diagnostics`, `definition`, `hover`, `symbols`.

São **contratos conceituais**; nomes, formatos de mensagens e linguagens serão definidos após a prova de conceito. Evitar construir uma grande API de plugins antes de validar edição e PHP/SQL.

## 5. Primeiras provas de conceito técnicas (ordem recomendada)

1. **Editor Android:** acentos, teclado virtual, autosave, seleção e mini explorador gestual numa tela real.
2. **PHP + WebView:** executar `index.php` em localhost, renderizar HTML/CSS/JS, iniciar/parar sem root.
3. **PHP + SQLite:** criar tabela e realizar operações CRUD, inclusive com internet desligada.
4. **MariaDB local:** iniciar serviço, persistir dados, conectar via PDO MySQL, parar e retomar após reiniciar app. Testar dispositivos distintos.
5. **Terminal integrado:** criar/retomar sessões sem travar o editor.
6. **SSH/SFTP:** abrir e salvar arquivo remoto, executar comando e confirmar identidade do host.
7. **LSP:** autocompletar PHP, erros e assinaturas de funções mantendo fluidez no teclado Android.
8. **Instalador de runtimes:** instalar/atualizar/remover componente testado e recuperar-se de instalação incompleta.

## 6. Matriz de compatibilidade e riscos

| Risco | Ação |
| --- | --- |
| Android limitar execução de binários | Prova por versão de Android/ABI, execução híbrida e documentação. |
| PRoot incompatível ou lento | Medir e avaliar alternativa nativa; não ocultar restrições. |
| MariaDB local consumir memória ou falhar | Prototipar antes de desenhar o instalador; testar persistência, performance e recuperação. |
| Teclado virtual quebrar seleção/autocomplete | Protótipo IME real antes da escolha final do editor. |
| Pastas SAF não acessíveis a ferramentas POSIX | Workspace com sincronização e detecção de conflitos. |
| Flutter/Android SDK não compilar localmente | Compatibilidade por toolchain; caminho remoto explícito, sem alegar suporte local universal. |
| Dependências e licenças de terceiros | Inventário de licenças e fontes de pacotes, revisão antes de redistribuir. |
| Segurança do servidor e credenciais | Loopback, isolamento, logs redigidos e armazenamento seguro. |

## 7. Distribuição, licença e próximos passos

- **Ainda não foi escolhida uma licença.** Avaliar permissiva (ex.: Apache-2.0) em combinação com obrigações das dependências (ex.: GPL de componentes redistribuídos).
- Não adicionar módulos terceiros sem revisar licenças, arquitetura, atualização e confiança da fonte.
- Não publicar chaves, certificados, credenciais ou bancos de teste com dados reais.
- Definir estrutura definitiva do código apenas depois das provas de conceito prioritárias.
- Consultar o [plano do produto](PLANO_DO_APLICATIVO.md) para escopo e condições de aceite.

**Próxima ação de engenharia recomendada:** demonstrar PHP + WebView + SQLite no Android enquanto se testa, em paralelo, se MariaDB local é viável sem root.
