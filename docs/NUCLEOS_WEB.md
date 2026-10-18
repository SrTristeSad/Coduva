# Núcleos web — implementação inicial

**Status em 17/10/2026:** o código-base de um editor Flutter, workspace, prévia estática e downloader de runtimes está disponível neste repositório. **PHP e MariaDB ainda não estão compilados ou executáveis no Coduva**, e nenhum release de binário foi publicado.

## Qual tecnologia vem no APK?

| Tecnologia | Política do Coduva | Situação do código |
| --- | --- | --- |
| HTML | Sem instalar núcleo | Workspace e prévia em WebView + servidor estático Dart |
| CSS | Sem instalar núcleo | Recursos CSS da pasta do projeto servidos no localhost |
| JavaScript | Sem instalar núcleo | WebView com JavaScript habilitado, código do projeto |
| PHP | Download sob demanda pelo GitHub Releases | Catálogo e downloader SHA-256; runtime nativa pendente |
| MariaDB (compatível com MySQL) | Download sob demanda pelo GitHub Releases | Catálogo e downloader SHA-256; servidor nativo pendente |
| SQLite | Banco leve incluído no app futuramente | Ainda não conectado ao editor/PHP |

HTML/CSS/JS **não são pacotes externos**; o mecanismo de prévia usa a WebView do Android e um servidor local escrito em Dart. O dispositivo precisa possuir Android System WebView compatível.

### Atenção à segurança da prévia

- O servidor estático escuta apenas `127.0.0.1` numa porta dinâmica.
- Não interpreta PHP.
- Arquivos `.php`, `.sql`, `.env`, bancos e chaves privadas são bloqueados para evitar vazamento de código e credenciais na prévia estática.
- O acesso a `http://127.0.0.1` exige configuração de segurança de rede Android, fornecida pelos scripts de preparação.
- O editor não deve abrir automaticamente URLs externas de projetos sem confirmar permissões e intenções do usuário.

## Por que não basta um ZIP do PHP para Android?

O Android 10+ impede aplicativos com target moderno de chamar `execve` em binários baixados para diretórios privados graváveis do app (regra **W^X**). Além disso, um PHP compilado para Linux ARM64 genérico normalmente depende de bibliotecas e carregador não presentes no Android.

**Arquitetura a validar:**

1. **Host nativo compatível com Android**, assinado/instalado junto com o APK, ou interpretador controlado embarcado. Este componente é obrigatório para execução real.
2. **Pacotes versionados de recursos e bibliotecas compatíveis**, disponibilizados no GitHub Releases.
3. **Instalador** que verifica ABI, URL permitida, tamanho e SHA-256 antes de aceitar pacotes.
4. **Servidor local** com gestão de portas, logs, iniciar/parar, document root e isolamento.
5. **Conexão PHP↔SQLite/PDO e PHP↔MariaDB**, depois de testes em aparelhos reais.

Não copiar binários do Termux diretamente e presumir compatibilidade: dependências, prefixos, licença, execução e ABI precisam ser revisados. O PHP integrado `php -S 127.0.0.1:PORT -t PROJETO`, quando disponível, deve ser apenas para desenvolvimento local.

### Contrato do catálogo

Arquivo: [assets/runtime_catalog.json](../assets/runtime_catalog.json). Para cada pacote:

```json
{
  "id": "php",
  "displayName": "PHP",
  "description": "Servidor PHP local...",
  "abi": "arm64-v8a",
  "version": null,
  "releaseUrl": null,
  "sha256": null,
  "state": "awaiting-compatible-build"
}
```

O instalador somente habilita o download quando os campos `version`, `releaseUrl` e `sha256` são válidos e a arquitetura do aparelho é suportada. Endereço permitido: `https://github.com/SrTristeSad/Coduva/releases/download/.../*.zip`. Pacotes podem ser baixados com HTTPS, guardados em pasta privada e verificados, mas **o ZIP não será executado**.

### Como preparar uma release depois de ter um pacote real

1. Compilar o PHP/MariaDB para o host Android definido, respeitando ABI, dependências, assinatura do app e licenças.
2. Testar runtime em dispositivo físico Android sem root. Para PHP: `php -v`, extensões e servidor localhost; para MariaDB: iniciar, persistir dados, SQL CRUD e conexão PDO.
3. Criar pacote ZIP versionado e validar licenças/dependências, sem segredos.
4. Publicar ZIP numa GitHub Release e fixar a tag.
5. Executar `python tools/gerar_catalogo_release.py --id php --abi arm64-v8a --version 8.x.y --tag php-android-v8.x.y --zip php-android-arm64-v8a.zip`.
6. Revisar o hash e fazer commit do catálogo **após** o arquivo existir na Release.

Isso é uma infraestrutura de distribuição; não substitui a engenharia do host nativo.

## Instalação e testes (código inicial)

Requisitos de desenvolvimento: Flutter >=3.38.1, Dart >=3.10, Android SDK, Java 17 e dispositivo Android. Este ambiente de edição não tinha o Flutter SDK para compilar nem executar testes; não declarar APK testado até realizar o procedimento.

**Windows PowerShell:**
```powershell
powershell -ExecutionPolicy Bypass -File scripts/preparar_android.ps1
flutter run
```

**Linux/macOS:**
```bash
bash scripts/preparar_android.sh
flutter run
```

**Testes Dart:**
```bash
flutter analyze
flutter test
```

Os scripts geram a pasta Android padrão com `flutter create` em uma pasta temporária, sem sobrescrever o código Flutter existente, adicionando permissão INTERNET e configuração de HTTP apenas para localhost.

## Próximas tarefas técnicas

- Criar host de PHP realmente executável e compatível com o Android, **antes** de publicar pacote.
- Compilar/integrar MariaDB sem root e testar consumo em aparelhos ARM64.
- Instalar e gerenciar dependências sem extrações inseguras; rollback e logs.
- Integrar operações reais: executar, parar, verificar versão, logs e consultas SQL.
- Melhorar editor de código (LSP, arquivos SAF, histórico de versões e persistência segura).

**Não há GitHub Actions configurado.**
