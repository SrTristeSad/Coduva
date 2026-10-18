# Plano do aplicativo — Coduva

**Documento de produto • Versão 0.1 • 17/10/2026**

> Este documento traduz os requisitos discutidos para um plano de execução. **Planejado não significa implementado.** Itens marcados como "validar" não são promessas de compatibilidade antes de testes reais.

## 1. Objetivo

Criar um editor/IDE **Android-first** para editar projetos, navegar entre arquivos e executar ambientes de desenvolvimento locais ou remotos, com interface pequena, clara e prática em telas de toque. O diferencial inicial é conseguir **criar e testar um site PHP completo com HTML/CSS/JS e SQL no próprio celular**, sem instalar ferramentas de forma obscura.

### Público e casos de uso

- Abrir um projeto existente e mudar rapidamente de `index.php` para `style.css` ou `config.php`.
- Criar um site PHP com banco de dados, iniciá-lo e visualizá-lo numa prévia interna.
- Trabalhar em projetos offline, quando o ambiente local já estiver instalado.
- Conectar a uma VPS Linux para editar, usar o terminal e executar builds mais pesados.
- Instalar ferramentas por projeto ou ambiente, sem sobrecarregar todos os usuários.

## 2. Experiência visual e navegação

### 2.1. Tema e layout

- **Tema claro é o padrão; escuro é configuração opcional.**
- Interface limpa, contraste consistente, poucos ícones visíveis por padrão.
- Editor preenche praticamente toda a tela; cabeçalho pequeno com arquivo ativo e ações essenciais.
- Abas compactas horizontalmente roláveis e menu para listar arquivos abertos.
- Layout responsivo para celular pequeno, dobrável e tablet; considerar teclado externo e orientação horizontal.
- O teclado virtual não deve cobrir o cursor, as sugestões nem ações críticas.

### 2.2. Gestos

| Ação | Resultado | Comportamento |
| --- | --- | --- |
| Puxar da **borda esquerda → direita** | Mini explorador | Gaveta sobreposta, árvore de pastas, busca, arquivo atual destacado. |
| Tocar em arquivo no explorador | Abrir/trocar arquivo | Abre uma aba; fecha a gaveta por padrão, com preferência para mantê-la aberta. |
| Puxar da **borda direita → esquerda** | Terminal | Abre um **painel inferior compacto** com a sessão corrente. |
| Arrastar a borda superior do terminal | Redimensionar | Terminal compacto, médio ou expandido; tamanho lembrado. |
| Gesto inverso / tocar fora / botão fechar | Fechar painel | Volta ao editor sem alterar conteúdo nem perder a sessão. |

**Prevenção de conflito:** gestos devem começar numa zona de borda configurável, respeitar o gesto "Voltar" do Android e não interferir na seleção de texto, rolagem horizontal ou movimentos do cursor. Deve haver um botão alternativo para acessibilidade.

### 2.3. Mini explorador

- Árvore expansível de pastas e arquivos do workspace; arquivos recentes.
- Criar arquivo/pasta, renomear, duplicar, mover e excluir com confirmação quando aplicável.
- Busca por nome e acesso ao explorador completo do dispositivo por uma ação específica.
- Mostrar erros de permissão, alterações externas e caminhos indisponíveis com recuperação clara.

## 3. Editor de código

**Obrigatório para a 1.0:**

- Abrir/salvar arquivos UTF-8, detectar codificação quando possível; avisar sobre arquivos grandes e binários.
- Seleção precisa por toque, linha/coluna, múltiplos desfazer/refazer, indentação, pares automáticos, atalhos de símbolos comuns em código.
- Abas, indicador de arquivo não salvo, restauração de sessão, salvamento atômico ou mecanismo seguro equivalente.
- Busca e substituição no arquivo e no projeto; ir para linha e símbolo.
- Realce de sintaxe para PHP, HTML, CSS, JavaScript, JSON, SQL, Python, Lua e arquivos de configuração comuns.
- Preferências de fonte, tamanho, quebra de linha, tabulação e tema.

### Autocompletar inteligente

- Sugestão por contexto (variáveis, funções, classes, caminhos, imports, membros e parâmetros).
- Diagnósticos com faixa discreta, detalhes e correções rápidas quando o servidor de linguagem permitir.
- Suporte inicial robusto para **PHP, HTML, CSS, JavaScript e SQL**; expansão por servidores de linguagem adicionais.
- LSP onde aplicável; fallback leve de snippets/palavras quando o servidor não existir ou estiver carregando.
- Pop-up pequeno próximo ao cursor, adaptado ao teclado virtual, com seleção por toque.
- IA generativa, se existir no futuro, **opcional** e distinta do IntelliSense local.

## 4. Execução e desenvolvimento web (não adiar para pós-1.0)

### 4.1. PHP local

- Instalar/preparar uma runtime PHP apropriada para a arquitetura do Android, sem exigir root.
- `Executar` inicia o serviço local vinculado apenas a `127.0.0.1`, apresenta estado, logs, parar/reiniciar e porta.
- Prévia em WebView dentro do Coduva, com recarregar, inspecionar erros e abrir URL.
- Suporte essencial a sessões, formulários, uploads em workspace controlado, roteamento básico e extensões `pdo_sqlite`, `pdo_mysql`, `mysqli`, `mbstring`, `openssl` e `curl` conforme disponibilidade.
- Fluxos PHP com Composer devem ser avaliados e testados (Composer e dependências podem exigir rede para instalar).

### 4.2. HTML / CSS / JS

- Prévia de sites estáticos e de sites PHP renderizados pelo servidor.
- Navegação entre editor e prévia em uma ação; modo lado a lado em telas maiores.
- Recarregamento manual obrigatório; atualização automática opcional e configurável.
- Console/erros visíveis, sem exigir abrir um app de navegador externo.

### 4.3. SQL

- **SQLite**: banco local embarcado, editor de consulta SQL, exploração de tabelas e integração com PHP PDO.
- **MySQL/MariaDB**: configurar conexões locais e remotas, executar SQL, visualizar tabelas e erros.
- **Servidor MariaDB local** no micro Linux é uma **meta da 1.0**, sujeita à prova real de inicialização, persistência, PHP↔DB e compatibilidade ARM64/Android sem root. Se inviável, resolver tecnicamente antes de afirmar que o requisito foi entregue; a conexão remota isoladamente não deve ser rotulada como banco local.
- Preservar credenciais no armazenamento seguro do Android e não mostrar senhas em logs.
- Exportar/importar SQL e backups básicos, com avisos para ações destrutivas.

### 4.4. Aceite do fluxo obrigatório

Com o celular offline e os componentes previamente instalados: abrir pasta de um site de teste → editar `index.php` e `style.css` → iniciar PHP → criar/ler registros em SQLite → abrir prévia interna → ler logs → parar servidor. Executar fluxo equivalente de CRUD com MariaDB local antes de declarar esse componente concluído.

## 5. Linux local e remoto

### 5.1. Local

- Experiência tipo userland/micro Linux, sem root, com shell utilizável, filesystem do projeto e gerenciamento de processos.
- Estudar PRoot ou alternativa compatível com restrições modernas do Android; **não assumir que funciona em todas as versões e aparelhos**.
- Instalação guiada por ferramentas/ambientes com indicador de espaço, consumo e compatibilidade.
- Isolar arquivos de runtime do workspace; controle de versão e limpeza de caches.
- Ferramentas candidatas: PHP, Composer, Python/pip, Lua, Node.js/npm, Java/JDK, Git, utilitários de compilação, MariaDB e Dart/Flutter.
- Compilação Flutter/Android **local depende de testes reais**. Fornecer caminho de compilação remota quando houver incompatibilidade das ferramentas no ARM64.

### 5.2. Remoto

- Perfis SSH com verificação explícita de chave do host.
- Terminal remoto e navegação/edição via SFTP; tratamento de perda de conexão e conflito de edição.
- Suporte a prévia de serviços remotos por encaminhamento de portas quando seguro e tecnicamente disponível.
- O usuário escolhe local/remoto por projeto ou sessão, sem alterar involuntariamente seus arquivos.

### 5.3. Gerenciador de ambientes

- Lista clara de ferramentas disponíveis, versão, espaço estimado, dependências e estado.
- Instalar, atualizar, reparar e remover; progresso e logs legíveis.
- Verificação de checksums/assinaturas conforme a fonte; rollback quando aplicável.
- Definir e isolar versões por ambiente/projeto quando viável.

## 6. Qualidade, acessibilidade e segurança

- Nenhuma dependência de conta na nuvem para edição ou testes locais.
- Não expor servidores locais na rede por padrão.
- Travamento do ambiente Linux não deve travar o editor; gerência do ciclo de vida de processos.
- Não perder edição após rotação, suspensão do Android, troca de arquivos ou falha do processo da runtime.
- Pedir apenas permissões necessárias e integrar-se ao seletor de documentos Android.
- Dados de SSH e DB protegidos; nunca registrar segredos em logs.
- Indicadores de memória, espaço e processos, evitando instalações enormes por padrão.
- Compatibilidade com leitor de tela, contraste e tamanho de toque adequado.
- Testar teclado Android (IME), acentos, seleção, copiar/colar, acesso a arquivos externos e uso offline.

## 7. Plano de execução por marcos

Os marcos representam **ordem de trabalho**, não versões comerciais posteriores:

### M0 — Validação técnica crítica

- Prova de conceito de edição confiável com teclado Android e permissões do filesystem.
- Prova de execução local de PHP + WebView + SQLite no Android sem root.
- Prova de execução persistente de MariaDB local com conexões PHP.
- Medir inicialização, armazenamento, memória, consumo de bateria e compatibilidade mínima suportada.
- Prova de sessão SSH/SFTP segura e da integração do terminal.

**Saída:** relatório de viabilidade com decisões documentadas. Não substituir requisitos silenciosamente por promessas.

### M1 — Produto visual e edição

- Editor claro, abas e busca.
- Mini explorador acionado por gesto da borda esquerda.
- Terminal compacto acionado pela borda direita.
- Navegação coerente, teclado confortável, projeto/arquivo, preferências e persistência.

### M2 — Web e SQL integrados

- Gerenciador de projetos web.
- PHP local, prévia WebView, logs e controles de serviço.
- Gerenciamento SQL SQLite + MySQL/MariaDB e integração PHP.
- Fluxo completo HTML/CSS/JS/PHP/SQL, inclusive offline após instalação.

### M3 — Inteligência e ambientes

- LSP e fallback leve; sugestões e diagnósticos para web.
- Linux local, gerenciador de ferramentas e instalações controladas.
- SSH/SFTP e sessões remotas; documentação de capacidades e limitações de cada toolchain.

### M4 — Estabilização para 1.0

- Testes reais em aparelhos Android de diferentes capacidades.
- Corrigir travamentos, perda de dados, problemas de teclado e conflitos de gestos.
- Auditoria de segurança das conexões e do servidor local.
- Documentação de instalação, recuperação, backup e licença/distribuição.

## 8. Critérios de lançamento da 1.0

A 1.0 **não será considerada entregue** apenas por ter uma tela bonita. É necessário demonstrar:

- [ ] Editor funcional, arquivos persistentes, abas e gestos sem conflito com o Android.
- [ ] Tema claro padrão e tema escuro opcional.
- [ ] Terminal compacto local e acesso remoto SSH.
- [ ] HTML/CSS/JS pré-visualizados no app.
- [ ] PHP local de verdade, com logs, iniciar/parar e navegação por URL interna.
- [ ] CRUD PHP + SQLite local.
- [ ] CRUD PHP + MariaDB local, validado no Android sem root.
- [ ] Conexão remota MySQL/MariaDB operante.
- [ ] Autocompletar contextual para linguagens web principais e erros explicativos.
- [ ] Gerenciador de ambientes sem instalações compulsórias.
- [ ] Testes de integridade de arquivos, isolamento de processos e proteção de credenciais.
- [ ] Documentação honesta das toolchains compatíveis (especialmente Flutter/Android local versus remoto).

## 9. Decisões ainda abertas

1. UI/editor engine definitiva: Flutter + componente editor especializado (nativo/WebView) ou outra arquitetura com comportamento IME superior.
2. Userland local: PRoot, runtime nativa isolada ou arquitetura híbrida conforme validação Android.
3. Distribuição dos pacotes e dos servidores de linguagem; versões e espaço em disco.
4. Licença de código aberto e licenças aplicáveis à redistribuição dos executáveis.
5. Estratégia de compatibilidade mínima do Android e suporte ARM32/ARM64.
6. Empacotamento e isolamento do MariaDB local, antes de prometer "um toque" em aparelhos incompatíveis.

**Não decidir automaticamente esses itens sem medição ou alinhamento.**
