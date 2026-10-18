# Coduva

**Editor de código para Android, com prévia web integrada e núcleos opcionais.**

> **Etapa de desenvolvimento 0.1.0:** o repositório contém código Flutter inicial, mas **ainda não há APK compilado/testado**, nem um núcleo PHP ou MariaDB executável. A licença também ainda não foi definida.

## Estado das funcionalidades

| Recurso | Estado |
| --- | --- |
| Edição de arquivos em workspace privado | Implementação inicial |
| Tema claro por padrão; escuro opcional | Implementação inicial |
| Explorar arquivos por gesto da borda esquerda | Implementação inicial |
| Terminal compacto por gesto da borda direita | Interface inicial; shell ainda pendente |
| HTML/CSS/JavaScript sem instalação | Servidor local Dart + WebView implementados; testes em Android pendentes |
| PHP instalado via GitHub Releases | Catálogo + download seguro; release e host Android pendentes |
| MariaDB / MySQL via GitHub Releases | Catálogo + download seguro; release e host Android pendentes |
| SQLite integrado e LSP | Planejados, não implementados |

**Importante:** o servidor estático nunca executa nem divulga arquivos PHP. O app não afirma que PHP já funciona só porque conseguiu baixar um ZIP. Android 10+ impõe restrições à execução de binários baixados; consulte a arquitetura antes de distribuir núcleos.

## Rodar o código no Android

Requer Flutter >=3.38.1, Dart >=3.10, Android SDK e Java 17. O scaffold nativo do Android é gerado localmente, sem sobrescrever `lib/`:

**Windows PowerShell**
```powershell
powershell -ExecutionPolicy Bypass -File scripts/preparar_android.ps1
flutter run
```

**Linux/macOS**
```bash
bash scripts/preparar_android.sh
flutter run
```

Testes:
```bash
flutter analyze
flutter test
```

Os testes ainda não foram executados neste ambiente (Flutter SDK indisponível). Nenhum GitHub Actions foi configurado.

## Núcleos e publicação

O arquivo [assets/runtime_catalog.json](assets/runtime_catalog.json) inclui PHP e MariaDB como **em preparo**. Quando tivermos builds nativas compatíveis, disponibilizaremos os arquivos via GitHub Releases, com versão, ABI e SHA-256. O instalador só habilita pacotes que tenham esses metadados válidos; um download validado é diferente de ter um servidor executável.

Leia [Núcleos web e processo de releases](docs/NUCLEOS_WEB.md).

## Documentação do produto

- [Plano do aplicativo 1.0](docs/PLANO_DO_APLICATIVO.md)
- [Arquitetura inicial](docs/ARQUITETURA_INICIAL.md)
- [Núcleos web e limites Android](docs/NUCLEOS_WEB.md)

A versão 1.0 tem como requisito PHP, HTML, CSS, JavaScript e SQL, incluindo integração local; isso ainda demanda compilação nativa, testes e integração ao editor. O objetivo é um app leve e mobile-first, com Linux local/remoto e suporte a ferramentas adicionais ao longo da construção da própria versão 1.0.

## Código aberto

O repositório é público. Há intenção de torná-lo código aberto, porém **a licença ainda não foi selecionada**. Não interpretar um repositório público como permissão irrestrita para redistribuição.
