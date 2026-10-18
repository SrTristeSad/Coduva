import 'dart:async';
import 'dart:io';

/// Gerencia o processo do servidor PHP em ambiente onde o executável já foi
/// provido por um host compatível. NÃO tenta executar o ZIP baixado do GitHub.
class PhpDevServer {
  Process? _process;
  final _logController = StreamController<String>.broadcast();

  Uri? _uri;

  Stream<String> get logs => _logController.stream;
  Uri? get url => _uri;
  bool get isRunning => _process != null;

  Future<Uri> start({
    required String trustedPhpExecutable,
    required Directory documentRoot,
  }) async {
    if (_process != null) return _uri!;
    if (Platform.isAndroid) {
      throw UnsupportedError(
        'Host nativo PHP Android ainda não integrado ao APK. '
        'Um binário baixado não pode ser executado diretamente.',
      );
    }
    if (!await documentRoot.exists()) {
      throw FileSystemException('Pasta do site não existe', documentRoot.path);
    }
    if (!await File(trustedPhpExecutable).exists()) {
      throw FileSystemException('Executável PHP não encontrado', trustedPhpExecutable);
    }

    // Porta dinâmica: evita conflito com outros serviços de desenvolvimento.
    final reservation = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = reservation.port;
    await reservation.close();
    final uri = Uri.parse('http://127.0.0.1:$port/');

    final process = await Process.start(
      trustedPhpExecutable,
      ['-S', '127.0.0.1:$port', '-t', documentRoot.path],
      workingDirectory: documentRoot.path,
      runInShell: false,
    );
    _process = process;
    _uri = uri;
    process.stdout.transform(systemEncoding.decoder).listen(_logController.add);
    process.stderr.transform(systemEncoding.decoder).listen(_logController.add);
    process.exitCode.then((code) {
      _logController.add('PHP finalizado com código $code');
      if (identical(_process, process)) {
        _process = null;
        _uri = null;
      }
    });

    // Somente considera pronto quando o HTTP local responde.
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    try {
      for (var i = 0; i < 24; i++) {
        if (_process == null) break;
        try {
          final request = await http.getUrl(uri).timeout(const Duration(seconds: 1));
          final response = await request.close().timeout(const Duration(seconds: 1));
          await response.drain<void>();
          return uri; // inclui 404/500: processo HTTP de fato respondeu.
        } catch (_) {
          await Future<void>.delayed(const Duration(milliseconds: 125));
        }
      }
      await stop();
      throw StateError('PHP não iniciou corretamente. Consulte os logs.');
    } finally {
      http.close(force: true);
    }
  }

  Future<void> stop() async {
    final current = _process;
    _process = null;
    _uri = null;
    if (current != null) {
      current.kill(ProcessSignal.sigterm);
      await current.exitCode.timeout(
        const Duration(seconds: 3),
        onTimeout: () async {
          current.kill(ProcessSignal.sigkill);
          return current.exitCode;
        },
      );
    }
  }

  Future<void> dispose() async {
    await stop();
    await _logController.close();
  }
}
