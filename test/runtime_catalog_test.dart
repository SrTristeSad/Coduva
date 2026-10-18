import 'package:coduva/core/runtime_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('pacotes sem release são indisponíveis', () {
    final catalog = RuntimeCatalog.parse('''
{"schema":1,"packages":[
{"id":"php","displayName":"PHP","description":"PHP","abi":"arm64-v8a",
"version":null,"releaseUrl":null,"sha256":null}
]}
''');
    expect(catalog.packages.single.isPublished, false);
  });

  test('rejeita artefato de host externo e ABI errada', () {
    final runtime = RuntimePackage(
      id: 'php',
      displayName: 'PHP',
      description: 'PHP runtime',
      abi: 'arm64-v8a',
      version: '0.1',
      releaseUrl: Uri.parse('https://example.org/php.zip'),
      sha256sum: sha,
    );
    expect(RuntimeDownloader.validRelease(runtime, ['arm64-v8a']), false);
    final approved = RuntimePackage(
      id: 'php',
      displayName: 'PHP',
      description: 'PHP runtime',
      abi: 'arm64-v8a',
      version: '0.1',
      releaseUrl: Uri.parse(
        'https://github.com/SrTristeSad/Coduva/releases/download/php-v0.1/php-android-arm64.zip',
      ),
      sha256sum: sha,
    );
    expect(RuntimeDownloader.validRelease(approved, ['x86_64']), false);
    expect(RuntimeDownloader.validRelease(approved, ['arm64-v8a']), true);
  });

  test('rejeita schema desconhecido e nomes duplicados', () {
    expect(() => RuntimeCatalog.parse('{"schema":2,"packages":[]}'),
        throwsFormatException);
    expect(() => RuntimeCatalog.parse('''{"schema":1,"packages":[
{"id":"php","displayName":"PHP","description":"","abi":"arm64-v8a","version":null,"releaseUrl":null,"sha256":null},
{"id":"php","displayName":"PHP","description":"","abi":"arm64-v8a","version":null,"releaseUrl":null,"sha256":null}
]}'''), throwsFormatException);
  });
}
