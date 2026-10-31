// Reads only runtime performance/code metadata, never app objects or widgets.
// Do not print or publish the private endpoint file. Saved output excludes
// timeline arguments, user text, point coordinates and account data.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> args) async {
  if (args.length != 3 && args.length != 4) {
    throw ArgumentError('Supply private endpoint file, report and seconds.');
  }
  final connection = jsonDecode(await File(args[0]).readAsString()) as Map;
  final uri = Uri.parse(connection['uri'] as String);
  if (!const {'127.0.0.1', 'localhost', '::1'}.contains(uri.host)) {
    throw StateError('Only local profiling is supported.');
  }
  final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
  final socket = uri.replace(scheme: 'ws', path: '${path}ws');
  final service = await vmServiceConnectUri(socket.toString());
  try {
    final vm = await service.getVM();
    final isolate = vm.isolates!.firstWhere(
      (i) => i.name == 'main',
      orElse: () => vm.isolates!.first,
    );
    try {
      await service.setFlag('profiler', 'true');
    } catch (_) {}
    final recent = args.length == 4 && args[3] == '--recent';
    if (!recent) {
      await service.setVMTimelineFlags(['Dart', 'GC', 'Embedder']);
      await service.clearVMTimeline();
      await service.clearCpuSamples(isolate.id!);
    }
    final memoryBefore = await service.getMemoryUsage(isolate.id!);
    final now = (await service.getVMTimelineMicros()).timestamp!;
    final duration = Duration(seconds: int.parse(args[2]).clamp(5, 60));
    final start = recent ? now - duration.inMicroseconds : now;
    stdout.writeln('Recording local CPU and frame timing metadata.');
    if (!recent) await Future<void>.delayed(duration);
    final end = (await service.getVMTimelineMicros()).timestamp!;
    final cpu = await service.getCpuSamples(isolate.id!, start, end - start);
    final memoryAfter = await service.getMemoryUsage(isolate.id!);
    final functions = [
      for (final f in cpu.functions ?? [])
        {
          'name': _safeFunction(
            (f.toJson()['function'] as Map?)?['name'] as String? ?? '',
          ),
          'owner':
              ((f.toJson()['function'] as Map?)?['owner'] as Map?)?['name'] ??
              '',
          'script': _safeScript(f.resolvedUrl ?? ''),
          'kind': f.kind ?? '',
          'self': f.exclusiveTicks ?? 0,
          'total': f.inclusiveTicks ?? 0,
        },
    ]..sort((a, b) => (b['self'] as int).compareTo(a['self'] as int));
    final inclusive = [...functions]
      ..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
    final timeline = await service.getVMTimeline(
      timeOriginMicros: start,
      timeExtentMicros: end - start,
    );
    final spans = <Map<String, dynamic>>[];
    final stacks = <String, List<Map<String, dynamic>>>{};
    for (final entry in timeline.traceEvents ?? []) {
      final event = entry.json!;
      final ph = event['ph'];
      final thread = '${event['pid']}/${event['tid']}';
      if (ph == 'B') {
        (stacks[thread] ??= []).add(event);
      } else if (ph == 'E' && stacks[thread]?.isNotEmpty == true) {
        final begin = stacks[thread]!.removeLast();
        spans.add({
          'name': begin['name'],
          'category': begin['cat'],
          'us': (event['ts'] as num) - (begin['ts'] as num),
          'thread': event['tid'],
        });
      } else if (ph == 'X' && event['dur'] is num) {
        spans.add({
          'name': event['name'],
          'category': event['cat'],
          'us': event['dur'],
          'thread': event['tid'],
        });
      }
    }
    final gc = spans
        .where(
          (span) => '${span['category']} ${span['name']}'
              .toLowerCase()
              .contains('gc'),
        )
        .toList();
    num gcTotal = 0, gcMax = 0;
    for (final span in gc) {
      final elapsed = span['us'] as num;
      gcTotal += elapsed;
      if (elapsed > gcMax) gcMax = elapsed;
    }
    spans.sort((a, b) => (b['us'] as num).compareTo(a['us'] as num));
    await File(args[1]).writeAsString(
      jsonEncode({
        'memoryBefore': {
          'heapBytes': memoryBefore.heapUsage,
          'capacityBytes': memoryBefore.heapCapacity,
          'externalBytes': memoryBefore.externalUsage,
        },
        'memoryAfter': {
          'heapBytes': memoryAfter.heapUsage,
          'capacityBytes': memoryAfter.heapCapacity,
          'externalBytes': memoryAfter.externalUsage,
        },
        // Nested phases and GC threads overlap; this is not UI pause time.
        'gcEvents': {
          'vmWide': true,
          'nestedOrParallel': true,
          'spanCount': gc.length,
          'overlappingTotalUs': gcTotal,
          'maxSpanUs': gcMax,
        },
        'samples': cpu.sampleCount,
        'samplePeriodUs': cpu.samplePeriod,
        'durationUs': end - start,
        'functions': functions.take(80).toList(),
        'inclusiveFunctions': inclusive.take(120).toList(),
        'longEvents': spans.take(80).toList(),
      }),
    );
    stdout.writeln('Local performance capture finished.');
  } finally {
    try {
      await service.setVMTimelineFlags([]);
      await service.setFlag('profiler', 'false');
    } catch (_) {
      // A closed app must not hide a successfully written timing report.
    }
    await service.dispose();
  }
}

String _safeFunction(String name) => name.startsWith('[Native] ')
    ? '[Native] ${name.substring(9).split(RegExp(r'[/\\]')).last}'
    : name;

String _safeScript(String source) {
  final uri = Uri.tryParse(source);
  if (uri == null) return '';
  if (const {'package', 'dart', 'org-dartlang-sdk'}.contains(uri.scheme)) {
    return uri.replace(query: '', fragment: '').toString();
  }
  if (uri.scheme != 'file') return '';
  final path = uri.path.replaceAll('\\', '/');
  for (final boundary in ['/lib/', '/tool/']) {
    final at = path.lastIndexOf(boundary);
    if (at >= 0) return path.substring(at + 1);
  }
  return '';
}
