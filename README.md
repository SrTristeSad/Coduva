# Coduva

**IDE mobile para Android: edite, execute e teste projetos diretamente no celular.**

> Status: **planejamento inicial**. Este repositório ainda não contém um aplicativo funcional. O nome e as decisões técnicas podem evoluir.

## Visão

O Coduva pretende unir um editor de código pensado para toque, gerenciamento fácil de arquivos, autocompletar inteligente e ambientes de desenvolvimento locais e remotos. O objetivo é permitir trabalhar com projetos reais, não apenas visualizar ou colorir textos.

O **tema claro será o padrão**; o tema escuro será opcional. A tela deve priorizar o código e reduzir menus permanentes.

## Compromissos da versão 1.0

- **Editor** com realce de sintaxe, abas, busca/substituição, desfazer/refazer, salvamento seguro e teclado mobile bem atendido.
- **Mini explorador de projeto:** deslizar da **borda esquerda para a direita** abre uma árvore compacta de pastas e arquivos; tocar em um arquivo abre no editor.
- **Terminal compacto:** deslizar da **borda direita para a esquerda** revela o terminal integrado, por padrão em um painel inferior redimensionável.
- **Autocompletar inteligente:** sugestões por contexto, parâmetros, diagnósticos e navegação de símbolos, com arquitetura baseada em LSP quando apropriado.
- **Desenvolvimento web local:** HTML, CSS, JavaScript, **servidor PHP** e visualização integrada em WebView.
- **SQL desde a 1.0:** SQLite e suporte a MySQL/MariaDB, com gerência de conexões, consultas e testes de aplicações PHP. O funcionamento de MariaDB local sem root é um requisito de engenharia sujeito à validação de compatibilidade, não uma capacidade já implementada.
- **Linux local e remoto:** estudar userland Linux leve no Android sem root; conexão a servidores via SSH/SFTP.
- **Gerenciador de ambientes:** permitir instalar e administrar ferramentas como Python, Lua, Java/JDK, Node.js, PHP e, quando tecnicamente compatível, Dart/Flutter. Builds Android com Flutter podem exigir ambiente remoto.
- **Projetos e arquivos:** abrir arquivos e pastas do Android de maneira segura, incluindo projetos existentes.

O Coduva não exigirá a instalação de um Linux completo apenas para editar um arquivo.

## Princípios

1. **Mobile-first:** a interface não será uma cópia em miniatura da UI desktop do VS Code.
2. **Um toque para testar:** projetos PHP deverão poder iniciar servidor e abrir a prévia integrada sem configuração manual extensa.
3. **Offline quando possível:** edição, servidor local e ferramentas instaladas devem funcionar sem internet.
4. **Recursos sob demanda:** dependências e núcleos de desenvolvimento não serão instalados compulsoriamente.
5. **Segurança e controle:** execução local isolada dentro das restrições do Android; confirmação para ações destrutivas; segurança em SSH e conexões SQL.
6. **Transparência:** documentar limitações de plataforma, consumo de armazenamento e compatibilidade de ferramentas.

## Documentação

- [Plano do aplicativo e escopo 1.0](docs/PLANO_DO_APLICATIVO.md)
- [Arquitetura inicial e riscos técnicos](docs/ARQUITETURA_INICIAL.md)

## Situação atual

- [x] Repositório criado
- [x] Visão e requisitos iniciais documentados
- [ ] Protótipo navegável do editor
- [ ] Prova de conceito do servidor PHP + SQL no Android
- [ ] Implementação e testes integrados
- [ ] Versão 1.0 validada

## Código aberto e licença

Existe uma **preferência inicial por código aberto**, com eventuais serviços remotos pagos opcionais. **A licença do repositório ainda não foi escolhida**. Apache-2.0 é uma candidata para o código autoral, mas devemos avaliar dependências, redistribuição de runtimes Linux/PHP/MariaDB, licenças dos componentes e obrigações de publicação antes da decisão. A ausência de um arquivo `LICENSE` não autoriza terceiros a redistribuir o código livremente.
