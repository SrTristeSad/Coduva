import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Metadados de um pacote publicado em GitHub Releases.
/// As versões sem release permanecem em preparação e não podem ser baixadas.
class RuntimePackage {
  const RuntimePackage({
    required this.id,
    required this.displayName,
    required this.description,
    required this.abi,
    required this.version,
    required this.releaseUrl,
    required this.sha256sum,
  });

  final String id;
  final String displayName;
  final String description;
  final String abi;
  final String? version;
  final Uri? releaseUrl;
  final String? sha256sum;

  bool get isPublished =>
      version != null && version!.isNotEmpty &&
      releaseUrl != null &&
      sha256sum != null &&
      RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(sha256sum!);

  factory RuntimePackage.fromJson(Map<String, dynamic> json) {
    final url = json['releaseUrl'] as String?;
    return RuntimePackage(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      description: json['description'] as String,
      abi: json['abi'] as String,
      version: json['version'] as String?,
      releaseUrl: url == null ? null : Uri.tryParse(url),
      sha256sum: json['sha256'] as String?,
    );
  }
}

class RuntimeCatalog {
  RuntimeCatalog._(this.packages);
  final List<RuntimePackage> packages;

  /// Catálogo incluído no APK, sem rede. Permite mostrar sempre os runtimes.
  static Future<RuntimeCatalog> bundled() async {
    final raw = await rootBundle.loadString('assets/runtime_catalog.json');
    return parse(raw);
  }

  /// Atualiza os metadados do repositório autorizado no GitHub.
  /// Na falha, o app deve continuar com o catálogo incluído no APK.
  static Future<RuntimeCatalog> remote({HttpClient? client}) async {
    final uri = Uri.parse(
      'https://raw.githubusercontent.com/SrTristeSad/Coduva/main/assets/runtime_catalog.json',
    );
    final ownsClient = client == null;
    final http = client ?? HttpClient();
    try {
      http.connectionTimeout = const Duration(seconds: 15);
      final request = await http.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Catálogo indisponível: ${response.statusCode}');
      }
      // Manifesto pequeno: evita aceitar resposta descontrolada.
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > 256 * 1024) {
          throw const FormatException('Catálogo muito grande.');
        }
      }
      return parse(utf8.decode(bytes));
    } finally {
      if (ownsClient) http.close(force: true);
    }
  }

  static RuntimeCatalog parse(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['schema'] != 1) throw const FormatException('Schema incompatível.');
    final list = json['packages'] as List<dynamic>;
    final packages = list
        .map((item) => RuntimePackage.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    if (packages.map((item) => item.id).toSet().length != packages.length) {
      throw const FormatException('Pacotes duplicados.');
    }
    return RuntimeCatalog._(packages);
  }
}

/// Baixa e VALIDA arquivos de runtime. Não executa arquivos baixados.
///
/// Android moderno proíbe execve de binários baixados para diretórios
/// graváveis do app. O host nativo compatível deverá ser embarcado no APK
/// em trabalho posterior. Ter um ZIP verificado não significa PHP funcional.
class RuntimeDownloader {
  RuntimeDownloader({HttpClient? client}) : _client = client ?? HttpClient();
  final HttpClient _client;

  static const maxArchiveBytes = 512 * 1024 * 1024;
  static final _validId = RegExp(r'^[a-z][a-z0-9-]{0,39}$');

  static bool validRelease(RuntimePackage runtime, List<String> deviceAbis) {
    if (!runtime.isPublished || !deviceAbis.contains(runtime.abi)) return false;
    if (!_validId.hasMatch(runtime.id)) return false;
    final uri = runtime.releaseUrl!;
    return uri.scheme == 'https' &&
        uri.host == 'github.com' &&
        uri.path.startsWith('/SrTristeSad/Coduva/releases/download/') &&
        uri.path.endsWith('.zip') &&
        uri.userInfo.isEmpty &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty;
  }

  static Future<Directory> packageDirectory() async {
    final home = await getApplicationSupportDirectory();
    final dir = Directory('${home.path}/runtime-downloads');
    await dir.create(recursive: true);
    return dir;
  }

  static Future<bool> cachedAndVerified(RuntimePackage runtime) async {
    if (!runtime.isPublished || !_validId.hasMatch(runtime.id)) return false;
    final folder = await packageDirectory();
    final file = File('${folder.path}/${runtime.id}-${runtime.abi}.zip');
    if (!await file.exists()) return false;
    final hash = await sha256.bind(file.openRead()).first;
    return hash.toString().toLowerCase() == runtime.sha256sum!.toLowerCase();
  }

  /// Retorna o ZIP validado. 'Preparado' não significa 'executável'.
  Future<File> download(
    RuntimePackage runtime,
    List<String> deviceAbis, {
    void Function(int received, int? total)? onProgress,
  }) async {
    if (!validRelease(runtime, deviceAbis)) {
      throw StateError('Pacote sem release validada ou incompatível com o aparelho.');
    }
    final folder = await packageDirectory();
    final file = File('${folder.path}/${runtime.id}-${runtime.abi}.zip');
    final temporary = File('${file.path}.part');
    if (await cachedAndVerified(runtime)) return file;
    await temporary.delete().catchError((Object _) => temporary);
    IOSink? output;
    try {
      _client.connectionTimeout = const Duration(seconds: 20);
      final request = await _client.getUrl(runtime.releaseUrl!);
      request.headers.set(HttpHeaders.userAgentHeader, 'Coduva/0.1');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Falha no download: HTTP ${response.statusCode}');
      }
      final total = response.contentLength < 0 ? null : response.contentLength;
      if (total != null && total > maxArchiveBytes) {
        throw const FormatException('Pacote ultrapassa o limite de 512 MB.');
      }
      var received = 0;
      output = temporary.openWrite();
      await for (final chunk in response) {
        received += chunk.length;
        if (received > maxArchiveBytes) {
          throw const FormatException('Pacote ultrapassa o limite de 512 MB.');
        }
        output!.add(chunk);
        onProgress?.call(received, total);
      }
      await output!.flush();
      await output!.close();
      output = null;
      final actual = (await sha256.bind(temporary.openRead()).first).toString();
      if (actual.toLowerCase() != runtime.sha256sum!.toLowerCase()) {
        throw const FormatException('SHA-256 inválido; download descartado.');
      }
      if (await file.exists()) await file.delete();
      return await temporary.rename(file.path);
    } catch (_) {
      try { await output?.close(); } catch (_) {}
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  void close() => _client.close(force: true);
}
