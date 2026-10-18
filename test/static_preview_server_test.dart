import 'dart:io';

import 'package:coduva/core/static_preview_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late StaticPreviewServer server;
  late HttpClient client;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('coduva-web-test-');
    await File('${root.path}/index.html').writeAsString('<h1>OK</h1>');
    await File('${root.path}/style.css').writeAsString('body{color:red}');
    await File('${root.path}/secret.php').writeAsString('<?php echo "segredo";');
    server = StaticPreviewServer(root);
    client = HttpClient();
    await server.start();
  });
  tearDown(() async {
    client.close(force: true);
    await server.stop();
    await root.delete(recursive: true);
  });

  Future<HttpClientResponse> request(String path) async {
    final req = await client.getUrl(Uri.parse('${server.url!.origin}$path'));
    return req.close();
  }

  test('HTML e CSS funcionam offline via loopback', () async {
    final html = await request('/index.html');
    expect(html.statusCode, HttpStatus.ok);
    expect(await html.transform(SystemEncoding().decoder).join(), '<h1>OK</h1>');
    final css = await request('/style.css');
    expect(css.statusCode, HttpStatus.ok);
    await css.drain<void>();
  });

  test('nunca publica PHP como arquivo estático', () async {
    final blocked = await request('/secret.php');
    expect(blocked.statusCode, HttpStatus.forbidden);
    await blocked.drain<void>();
  });
}
