import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'core/runtime_downloader.dart';
import 'core/static_preview_server.dart';
import 'core/workspace.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CoduvaApp());
}

class CoduvaApp extends StatefulWidget {
  const CoduvaApp({super.key});

  @override
  State<CoduvaApp> createState() => _CoduvaAppState();
}

class _CoduvaAppState extends State<CoduvaApp> {
  bool dark = false;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coduva',
      debugShowCheckedModeBanner: false,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF306BE8),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFD),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF639BFF),
        useMaterial3: true,
      ),
      home: EditorScreen(
        isDark: dark,
        toggleTheme: () => setState(() => dark = !dark),
      ),
    );
  }
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.isDark,
    required this.toggleTheme,
  });
  final bool isDark;
  final VoidCallback toggleTheme;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  final _runtimeDownloader = RuntimeDownloader();
  final _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);
        if (uri != null && uri.scheme == 'http' &&
            uri.host == '127.0.0.1') {
          return NavigationDecision.navigate;
        }
        return NavigationDecision.prevent;
      },
    ));

  Workspace? _workspace;
  StaticPreviewServer? _server;
  RuntimeCatalog? _catalog;
  List<String> _supportedAbis = [];
  List<String> _files = [];
  final List<String> _opened = [];
  String? _active;
  String? _error;
  bool _preview = false;
  bool _terminal = false;
  bool _busy = false;
  bool _dirty = false;
  double? _rightEdgeStart;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _code.addListener(_onEdited);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final ws = await Workspace.create();
      final catalog = await RuntimeCatalog.bundled();
      final abis = Platform.isAndroid
          ? (await DeviceInfoPlugin().androidInfo).supportedAbis
          : <String>[];
      final files = await ws.files();
      if (!mounted) return;
      setState(() {
        _workspace = ws;
        _server = StaticPreviewServer(ws.root);
        _catalog = catalog;
        _supportedAbis = abis;
        _files = files;
      });
      await _open('index.html');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _onEdited() {
    if (_active == null) return;
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), () {
      _save().catchError((Object e) {
        if (mounted) _notify('Falha ao salvar: $e');
      });
    });
  }

  Future<void> _save() async {
    _saveTimer?.cancel();
    if (!_dirty || _active == null || _workspace == null) return;
    final file = _active!;
    final text = _code.text;
    // Se o usuário trocar de arquivo durante uma gravação, não perder
    // a edição pendente da nova aba.
    _dirty = false;
    try {
      await _workspace!.write(file, text);
    } catch (_) {
      _dirty = true;
      rethrow;
    }
  }

  Future<void> _open(String file) async {
    await _save();
    final value = await _workspace!.read(file);
    _active = null; // impede que a troca do controller crie um autosave falso
    _code.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: 0),
    );
    if (!_opened.contains(file)) _opened.add(file);
    if (!mounted) return;
    setState(() {
      _active = file;
      _preview = false;
      _dirty = false;
    });
  }

  Future<void> _createFile() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo arquivo'),
        content: TextField(
          autofocus: true,
          controller: nameController,
          decoration: const InputDecoration(hintText: 'ex.: contato.php'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || !Workspace.validSegment(name)) {
      if (name != null) _notify('Use apenas um nome de arquivo válido.');
      return;
    }
    try {
      final path = _workspace!.file(name);
      if (await path.exists()) throw StateError('Arquivo já existe.');
      await _workspace!.write(name, '');
      final files = await _workspace!.files();
      if (mounted) setState(() => _files = files);
      await _open(name);
    } catch (e) {
      _notify(e.toString());
    }
  }

  Future<void> _showPreview() async {
    if (_active?.toLowerCase().endsWith('.php') ?? false) {
      _notify('PHP necessita do núcleo nativo. A prévia estática não executa PHP.');
      return;
    }
    try {
      await _save();
      final serverUrl = await _server!.start();
      if (!mounted) return;
      await _controller.loadRequest(serverUrl);
      if (mounted) setState(() => _preview = true);
    } catch (e) {
      _notify('Não foi possível abrir a prévia: $e');
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _showRuntimes() async {
    if (_catalog == null) return;
    try {
      _catalog = await RuntimeCatalog.remote();
    } catch (_) {
      // Offline: catálogo empacotado continua válido.
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Núcleos de desenvolvimento',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                const Text('HTML, CSS e JavaScript já estão disponíveis.'),
                const SizedBox(height: 18),
                for (final runtime in _catalog!.packages)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.extension_outlined),
                    title: Text(runtime.displayName),
                    subtitle: Text(runtime.isPublished
                        ? 'Versão ${runtime.version} • ${runtime.abi}'
                        : 'Aguardando pacote Android compatível no GitHub'),
                    trailing: _busy
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: RuntimeDownloader.validRelease(
                              runtime, _supportedAbis,
                            ) ? () async {
                              setSheetState(() => _busy = true);
                              try {
                                await _runtimeDownloader.download(
                                  runtime, _supportedAbis,
                                );
                                _notify('Download validado. Execução nativa ainda em desenvolvimento.');
                              } catch (e) {
                                _notify('Não foi possível baixar: $e');
                              } finally {
                                if (mounted) setSheetState(() => _busy = false);
                              }
                            } : null,
                            child: Text(runtime.isPublished ? 'Baixar' : 'Em preparo'),
                          ),
                  ),
                const SizedBox(height: 10),
                Text(
                  'Pacotes do GitHub são verificados por SHA-256. '
                  'Baixar não significa que o núcleo já pode executar no Android.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _explorer() {
    return Drawer(
      width: math.min(286, MediaQuery.of(context).size.width * 0.78),
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: const Text('Explorador', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('meu-site'),
              trailing: IconButton(
                tooltip: 'Novo arquivo',
                icon: const Icon(Icons.note_add_outlined),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _createFile();
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  for (final file in _files)
                    ListTile(
                      dense: true,
                      selected: file == _active,
                      title: Text(file, overflow: TextOverflow.ellipsis),
                      leading: Icon(
                        file.endsWith('.html') ? Icons.language :
                        file.endsWith('.css') ? Icons.palette_outlined :
                        file.endsWith('.js') ? Icons.javascript :
                        file.endsWith('.php') ? Icons.code : Icons.description_outlined,
                        size: 20,
                      ),
                      onTap: () async {
                        Navigator.of(context).pop();
                        try {
                          await _open(file);
                        } catch (e) {
                          _notify('Falha ao abrir arquivo: $e');
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editor() {
    if (_preview) return WebViewWidget(controller: _controller);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: _code,
        focusNode: _focus,
        expands: true,
        minLines: null,
        maxLines: null,
        autocorrect: false,
        enableSuggestions: false, // LSP próprio será conectado depois
        keyboardType: TextInputType.multiline,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(fontSize: 14, fontFamily: 'monospace', height: 1.5),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Comece a escrever…',
          contentPadding: EdgeInsets.all(8),
        ),
      ),
    );
  }

  Widget _terminalPanel() {
    return AnimatedContainer(
      height: _terminal ? 166 : 0,
      duration: const Duration(milliseconds: 190),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: _terminal ? Column(
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.terminal, size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('Terminal', style: TextStyle(fontWeight: FontWeight.w600))),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => setState(() => _terminal = false),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  'Ambiente Linux ainda não conectado.\n'
                  'A prévia HTML/CSS/JS já funciona pelo botão ▶.',
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
        ],
      ) : const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Coduva')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Falha na inicialização:\n$_error'),
        )),
      );
    }
    if (_workspace == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      drawerEnableOpenDragGesture: true,
      drawer: _explorer(),
      appBar: AppBar(
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Arquivos',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.folder_open_outlined),
          ),
        ),
        titleSpacing: 0,
        title: const Text('Coduva',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19)),
        actions: [
          IconButton(
            tooltip: 'Núcleos PHP e SQL',
            onPressed: _showRuntimes,
            icon: const Icon(Icons.extension_outlined),
          ),
          IconButton(
            tooltip: widget.isDark ? 'Tema claro' : 'Tema escuro',
            onPressed: widget.toggleTheme,
            icon: Icon(widget.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            _rightEdgeStart = event.localPosition.dx >= constraints.maxWidth - 24
                ? event.localPosition.dx : null;
          },
          onPointerMove: (event) {
            final start = _rightEdgeStart;
            if (start != null && start - event.localPosition.dx > 65) {
              _rightEdgeStart = null;
              setState(() => _terminal = true);
            }
          },
          onPointerCancel: (_) => _rightEdgeStart = null,
          onPointerUp: (_) => _rightEdgeStart = null,
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final file in _opened)
                            TextButton.icon(
                              onPressed: () => _open(file),
                              icon: Icon(file == _active
                                  ? Icons.description : Icons.insert_drive_file_outlined,
                                size: 14),
                              label: Text(file, style: const TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: _preview ? 'Editor' : 'Prévia web',
                      onPressed: _preview
                          ? () => setState(() => _preview = false)
                          : _showPreview,
                      icon: Icon(_preview ? Icons.code : Icons.play_arrow_rounded),
                    ),
                    IconButton(
                      tooltip: 'Terminal compacto',
                      onPressed: () => setState(() => _terminal = !_terminal),
                      icon: const Icon(Icons.terminal, size: 21),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _editor()),
              _terminalPanel(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              const Icon(Icons.folder_outlined, size: 13),
              const SizedBox(width: 5),
              const Expanded(child: Text('meu-site', style: TextStyle(fontSize: 11))),
              Text(_active ?? '', style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 8),
              const Text('UTF-8', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_dirty) {
      _save(); // best-effort; persistência reforçada será tratada na próxima etapa
    }
    _code.dispose();
    _focus.dispose();
    _server?.stop();
    _runtimeDownloader.close();
    super.dispose();
  }
}
