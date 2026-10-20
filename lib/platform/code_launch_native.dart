import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../domain/code_launch.dart';
import 'code_tools_native.dart' show codeToolsSupported;
export 'code_tools_native.dart' show openCodeLaunchStore;

Future<CodeWebPreview> startCodeWebPreview(String root, String entry) async {
  if (!codeToolsSupported) {
    throw UnsupportedError('Web preview requires desktop.');
  }
  final base = await Directory(root).resolveSymbolicLinks();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final preview = _LocalWebPreview(base, entry, server);
  try {
    await preview.file(entry);
    preview.start();
    return preview;
  } on Object {
    await server.close(force: true);
    rethrow;
  }
}

class _LocalWebPreview implements CodeWebPreview {
  _LocalWebPreview(this.root, this.entry, this.server);
  final String root, entry;
  final HttpServer server;
  final token = const Uuid().v4();
  final controller = StreamController<String>.broadcast();
  StreamSubscription<FileSystemEvent>? watcher;
  Timer? debounce;
  bool stopped = false;
  int revision = 0, active = 0;
  static const types = {
    'html': 'text/html; charset=utf-8',
    'htm': 'text/html; charset=utf-8',
    'css': 'text/css; charset=utf-8',
    'js': 'text/javascript; charset=utf-8',
    'mjs': 'text/javascript; charset=utf-8',
    'json': 'application/json',
    'txt': 'text/plain; charset=utf-8',
    'svg': 'image/svg+xml',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'ico': 'image/x-icon',
    'avif': 'image/avif',
    'woff': 'font/woff',
    'woff2': 'font/woff2',
    'ttf': 'font/ttf',
    'otf': 'font/otf',
    'wasm': 'application/wasm',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'mp4': 'video/mp4',
    'webm': 'video/webm',
    'pdf': 'application/pdf',
  };
  bool allowed(String path) =>
      path.length <= 4096 &&
      path.isNotEmpty &&
      !path.contains(RegExp(r'[\\:\x00]')) &&
      !path.startsWith('/') &&
      !path
          .split('/')
          .any(
            (s) => s.isEmpty || s == '..' || s == '.' || s.startsWith('.'),
          ) &&
      p.extension(path).isNotEmpty &&
      types.containsKey(p.extension(path).substring(1).toLowerCase());
  Future<File> file(String path) async {
    if (!allowed(path)) {
      throw const FormatException(
        'Choose a supported web file inside the project.',
      );
    }
    if (await Directory(root).resolveSymbolicLinks() != root) {
      throw const FormatException('Project location changed.');
    }
    final candidate = File(p.join(root, path)),
        actual = await candidate.resolveSymbolicLinks();
    if (!p.isWithin(root, actual)) {
      throw const FormatException('Web file is outside the project.');
    }
    if (!allowed(p.relative(actual, from: root).replaceAll('\\', '/'))) {
      throw const FormatException(
        'Web file resolves to hidden or unsupported content.',
      );
    }
    if (await candidate.length() > 64 * 1024 * 1024) {
      throw const FormatException('Preview asset exceeds 64 MiB.');
    }
    return File(actual);
  }

  @override
  Uri get url => Uri(
    scheme: 'http',
    host: '127.0.0.1',
    port: server.port,
    path: '/$entry',
    queryParameters: {'orbitPreview': token},
  );
  @override
  Stream<String> get events => controller.stream;
  String get cookieName => 'orbit_preview_${server.port}';
  void start() {
    server.listen(
      handle,
      onError: (Object _) {
        if (!stopped) controller.add('Preview request failed; retry the page.');
      },
    );
    try {
      watcher = Directory(root)
          .watch(recursive: true)
          .listen(
            (event) {
              final path = p
                  .relative(event.path, from: root)
                  .replaceAll('\\', '/');
              if (!allowed(path)) return;
              debounce?.cancel();
              debounce = Timer(const Duration(milliseconds: 200), refresh);
            },
            onError: (Object _) {
              if (!stopped) {
                controller.add(
                  'External file watching is unavailable. Orbit saves and Refresh still reload pages.',
                );
              }
            },
          );
    } on Object {
      controller.add(
        'External file watching is unavailable. Orbit saves and Refresh still reload pages.',
      );
    }
  }

  @override
  void refresh() {
    if (!stopped) revision++;
  }

  Future<void> handle(HttpRequest request) async {
    if (active >= 16) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      try {
        await request.response.close();
      } on Object {
        /* Client disconnected. */
      }
      return;
    }
    active++;
    final response = request.response;
    try {
      final origin = 'http://127.0.0.1:${server.port}';
      if (request.headers.value(HttpHeaders.hostHeader) !=
              '127.0.0.1:${server.port}' ||
          (request.headers.value('origin') != null &&
              request.headers.value('origin') != origin) ||
          request.headers.value('sec-fetch-site') == 'cross-site') {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      if (!['GET', 'HEAD'].contains(request.method)) {
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      final authorized =
          request.uri.queryParameters['orbitPreview'] == token ||
          request.cookies.any((c) => c.name == cookieName && c.value == token);
      if (!authorized) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      response.headers.set('Cache-Control', 'no-store');
      response.headers.set('X-Content-Type-Options', 'nosniff');
      response.headers.set('Referrer-Policy', 'no-referrer');
      response.headers.add(
        'Set-Cookie',
        '$cookieName=$token; Path=/; HttpOnly; SameSite=Strict',
      );
      if (request.uri.path == '/__orbit_preview/revision') {
        response.headers.contentType = ContentType.json;
        if (request.method == 'GET') {
          response.write(jsonEncode({'revision': revision}));
        }
        return;
      }
      final path = request.uri.path == '/'
          ? 'index.html'
          : request.uri.pathSegments.join('/');
      final source = await file(path);
      response.headers.set(
        'Content-Type',
        types[p.extension(path).substring(1).toLowerCase()]!,
      );
      if (request.method == 'HEAD') return;
      if (['.html', '.htm'].contains(p.extension(path).toLowerCase()) &&
          await source.length() <= 2 * 1024 * 1024) {
        final text = utf8.decode(await source.readAsBytes());
        final script =
            '<script data-orbit-preview>\n'
            '(()=>{let r=$revision;setInterval(async()=>{try{const x=await fetch("$origin/__orbit_preview/revision",{cache:"no-store"});if(!x.ok)return;const n=(await x.json()).revision;if(n!==r)location.reload();}catch(_){}},1000);})();\n</script>';
        // Append after authored markup; a body-closing string inside JavaScript
        // or a comment must not become an insertion point and break that code.
        response.write('$text\n$script');
      } else {
        await response.addStream(source.openRead());
      }
    } on Object {
      try {
        response.statusCode = HttpStatus.notFound;
      } on Object {
        /* Response may already be streaming. */
      }
    } finally {
      active--;
      try {
        await response.close();
      } on Object {
        /* Browser disconnected. */
      }
    }
  }

  @override
  Future<void> stop() async {
    if (stopped) return;
    stopped = true;
    debounce?.cancel();
    await watcher?.cancel();
    await server.close(force: true);
    unawaited(controller.close());
  }
}
