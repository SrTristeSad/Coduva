import 'dart:io';

/// Servidor de arquivos estáticos local: não interpreta PHP nem expõe .php.
/// Só disponibiliza conteúdo dentro do workspace selecionado.
class StaticPreviewServer {
  StaticPreviewServer(this.root);
  final Directory root;
  HttpServer? _server;

  Uri? get url => _server == null
      ? null
      : Uri.parse('http://127.0.0.1:${_server!.port}/index.html');

  Future<Uri> start() async {
    if (_server != null) return url!;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0, shared: false);
    _server!.listen(_handle);
    return url!;
  }

  Future<void> stop() async {
    final current = _server;
    _server = null;
    await current?.close(force: true);
  }

  static String mimeType(String file) {
    switch (file.split('.').last.toLowerCase()) {
      case 'html': case 'htm': return 'text/html; charset=utf-8';
      case 'css': return 'text/css; charset=utf-8';
      case 'js': case 'mjs': return 'text/javascript; charset=utf-8';
      case 'json': return 'application/json; charset=utf-8';
      case 'svg': return 'image/svg+xml';
      case 'png': return 'image/png';
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'webp': return 'image/webp';
      case 'gif': return 'image/gif';
      case 'ico': return 'image/x-icon';
      case 'txt': return 'text/plain; charset=utf-8';
      default: return 'application/octet-stream';
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers.set('Cache-Control', 'no-store');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    try {
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      final segments = request.uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) segments.add('index.html');
      if (segments.any((s) => s == '.' || s == '..' || s.startsWith('.') ||
          s.contains('\\') || s.contains('\x00'))) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      final forbidden = <String>{'php', 'phtml', 'phar', 'sql', 'db', 'sqlite', 'sqlite3', 'env',
        'key', 'pem', 'ini', 'yml', 'yaml', 'lock', 'log', 'sh'};
      if (forbidden.contains(segments.last.split('.').last.toLowerCase())) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      final canonicalRoot = await root.resolveSymbolicLinks();
      final file = File('${root.path}/${segments.join('/')}');
      if (!await file.exists()) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      final canonical = await file.resolveSymbolicLinks();
      if (!canonical.startsWith('$canonicalRoot/')) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      response.headers.set('Content-Type', mimeType(file.path));
      response.contentLength = await file.length();
      if (request.method == 'GET') await response.addStream(file.openRead());
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;
    } finally {
      await response.close();
    }
  }
}
