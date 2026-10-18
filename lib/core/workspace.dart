import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Workspace mínimo privado do app. Abrir pastas do SAF virá em uma etapa
/// independente; não se presume que URIs content:// sejam caminhos POSIX.
class Workspace {
  Workspace._(this.root);
  final Directory root;

  static Future<Workspace> create() async {
    final base = await getApplicationDocumentsDirectory();
    final root = Directory('${base.path}/coduva/projetos/meu-site');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    final ws = Workspace._(root);
    if (await root.list(followLinks: false).isEmpty) {
      await ws.write('index.html', '''<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Meu primeiro projeto no Coduva</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <main>
    <h1>Olá, Coduva!</h1>
    <p>HTML, CSS e JavaScript já funcionam sem instalação.</p>
    <button id="teste">Testar JavaScript</button>
    <p id="saida"></p>
  </main>
  <script src="script.js"></script>
</body>
</html>
''');
      await ws.write('style.css', '''body { background: #f7f9fd; color: #18243b; font: 16px system-ui; }
main { margin: 48px auto; max-width: 480px; padding: 28px;
  background: white; border-radius: 18px; box-shadow: 0 12px 45px #dde3ed; }
button { background: #2864ec; color: white; border: 0;
  border-radius: 10px; padding: 12px 16px; }
''');
      await ws.write('script.js', '''document.querySelector('#teste').addEventListener('click', () => {
  document.querySelector('#saida').textContent = 'JavaScript funcionando!';
});
''');
    }
    return ws;
  }

  static bool validSegment(String value) =>
      value.isNotEmpty &&
      value != '.' &&
      value != '..' &&
      !value.contains('/') &&
      !value.contains('\\') &&
      !value.contains(RegExp(r'[\x00-\x1f]'));

  File file(String relative) {
    final segments = relative.split('/');
    if (segments.any((s) => !validSegment(s))) {
      throw const FormatException('Caminho inválido.');
    }
    return File('${root.path}/${segments.join('/')}');
  }

  Future<List<String>> files() async {
    final result = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final rel = entity.path.substring(root.path.length + 1).replaceAll('\\', '/');
        result.add(rel);
      }
    }
    result.sort();
    return result;
  }

  Future<String> read(String relative) => file(relative).readAsString();

  Future<void> write(String relative, String content) async {
    final target = file(relative);
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.coduva-tmp');
    await temporary.writeAsString(content, flush: true);
    // Backups e recuperação contra interrupção serão adicionados ao editor.
    // Em Android/Linux, rename sobre o arquivo existente é atômico.
    await temporary.rename(target.path);
  }
}
