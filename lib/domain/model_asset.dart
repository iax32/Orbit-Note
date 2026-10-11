import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

bool isModelAsset(String name) =>
    const ['obj', 'glb'].contains(name.split('.').last.toLowerCase());

class MeshPoint {
  const MeshPoint(this.x, this.y, this.z);
  final double x, y, z;
}

class MeshFace {
  const MeshFace(this.a, this.b, this.c, [this.color = 0xffa8b7d4]);
  final int a, b, c, color;
}

class ModelAsset {
  ModelAsset(this.points, this.faces, this.notes);
  final List<MeshPoint> points;
  final List<MeshFace> faces;
  final List<String> notes;
  static const maxBytes = 32 * 1024 * 1024;
  static const maxVertices = 100000;
  static const maxFaces = 50000;
}

ModelAsset parseModelAsset(Uint8List bytes, String name) {
  if (bytes.length > ModelAsset.maxBytes) {
    throw const FormatException(
      'Preview limit is 32 MB. Open the original in your modelling tool.',
    );
  }
  final points = <MeshPoint>[], faces = <MeshFace>[];
  final notes = <String>[
    'Static geometry preview. Textures, animation, rigging and OBJ material sidecars are not rendered.',
  ];
  void vertex(double x, double y, double z) {
    if (![x, y, z].every((n) => n.isFinite) ||
        points.length >= ModelAsset.maxVertices) {
      throw const FormatException(
        'Invalid coordinates or geometry exceeds 100,000 vertices.',
      );
    }
    points.add(MeshPoint(x, y, z));
  }

  void face(int a, int b, int c, [int color = 0xffa8b7d4]) {
    if ([a, b, c].any((v) => v < 0 || v >= points.length) ||
        faces.length >= ModelAsset.maxFaces) {
      throw const FormatException(
        'Invalid face or geometry exceeds 50,000 triangles.',
      );
    }
    faces.add(MeshFace(a, b, c, color));
  }

  if (name.toLowerCase().endsWith('.obj')) {
    for (final raw in const LineSplitter().convert(utf8.decode(bytes))) {
      final tokens = raw.split('#').first.trim().split(RegExp(r'\s+'));
      if (tokens.first == 'v') {
        if (tokens.length < 4) {
          throw const FormatException('Incomplete OBJ vertex.');
        }
        vertex(
          double.parse(tokens[1]),
          double.parse(tokens[2]),
          double.parse(tokens[3]),
        );
      } else if (tokens.first == 'f') {
        if (tokens.length < 4 || tokens.length > 1002) {
          throw const FormatException('Invalid OBJ polygon.');
        }
        final indices = tokens.skip(1).map((s) {
          final n = int.parse(s.split('/').first);
          return n < 0 ? points.length + n : n - 1;
        }).toList();
        for (var i = 1; i + 1 < indices.length; i++) {
          face(indices[0], indices[i], indices[i + 1]);
        }
      }
    }
    notes.add(
      'OBJ polygons use fan triangulation; export triangulated geometry for concave faces.',
    );
  } else if (name.toLowerCase().endsWith('.glb')) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 20 ||
        data.getUint32(0, Endian.little) != 0x46546c67 ||
        data.getUint32(4, Endian.little) != 2 ||
        data.getUint32(8, Endian.little) != bytes.length) {
      throw const FormatException('Invalid GLB 2 container.');
    }
    Map<String, dynamic>? doc;
    Uint8List? binary;
    for (var offset = 12; offset < bytes.length;) {
      if (offset + 8 > bytes.length) {
        throw const FormatException('Truncated GLB chunk.');
      }
      final length = data.getUint32(offset, Endian.little),
          type = data.getUint32(offset + 4, Endian.little);
      offset += 8;
      if (length % 4 != 0 || offset + length > bytes.length) {
        throw const FormatException('Invalid GLB chunk bounds.');
      }
      if (type == 0x4e4f534a) {
        if (doc != null) {
          throw const FormatException('Duplicate GLB JSON chunk.');
        }
        doc =
            jsonDecode(utf8.decode(bytes.sublist(offset, offset + length)))
                as Map<String, dynamic>;
      } else if (type == 0x004e4942) {
        if (binary != null) {
          throw const FormatException('Duplicate GLB binary chunk.');
        }
        binary = Uint8List.sublistView(bytes, offset, offset + length);
      }
      offset += length;
    }
    if (doc == null || binary == null) {
      throw const FormatException('GLB needs embedded JSON and geometry.');
    }
    final bin = ByteData.sublistView(binary);
    final views = doc['bufferViews'] as List? ?? [],
        accessors = doc['accessors'] as List? ?? [];
    List<List<num>> accessor(int id, bool position) {
      if (id < 0 || id >= accessors.length) {
        throw const FormatException('Invalid GLB accessor.');
      }
      final a = accessors[id] as Map;
      if (a['sparse'] != null || a['bufferView'] is! int) {
        throw const FormatException(
          'Sparse or compressed geometry is unsupported. Export ordinary mesh buffers.',
        );
      }
      final viewId = a['bufferView'] as int;
      if (viewId < 0 || viewId >= views.length) {
        throw const FormatException('Invalid buffer view.');
      }
      final v = views[viewId] as Map;
      if ((v['extensions'] as Map?)?.containsKey('EXT_meshopt_compression') ==
          true) {
        throw const FormatException(
          'Meshopt compression is unsupported. Export uncompressed GLB.',
        );
      }
      final count = a['count'] as int, component = a['componentType'] as int;
      final width = position ? 3 : 1;
      final size = switch (component) {
        5121 => 1,
        5123 => 2,
        5125 || 5126 => 4,
        _ => 0,
      };
      if (count < 0 ||
          count >
              (position ? ModelAsset.maxVertices : ModelAsset.maxFaces * 3) ||
          size == 0 ||
          a['type'] != (position ? 'VEC3' : 'SCALAR') ||
          (position ? component != 5126 : component == 5126) ||
          a['normalized'] == true ||
          (v['buffer'] ?? 0) != 0) {
        throw const FormatException('Unsupported GLB geometry layout.');
      }
      final start = v['byteOffset'] as int? ?? 0,
          length = v['byteLength'] as int;
      final local = a['byteOffset'] as int? ?? 0,
          stride = v['byteStride'] as int? ?? width * size;
      if (start < 0 ||
          length < 0 ||
          start + length > bin.lengthInBytes ||
          local < 0 ||
          stride < width * size ||
          (count > 0 && local + (count - 1) * stride + width * size > length)) {
        throw const FormatException('GLB accessor escapes its buffer view.');
      }
      num number(int p) => switch (component) {
        5121 => bin.getUint8(p),
        5123 => bin.getUint16(p, Endian.little),
        5125 => bin.getUint32(p, Endian.little),
        _ => bin.getFloat32(p, Endian.little),
      };
      return [
        for (var i = 0; i < count; i++)
          [
            for (var j = 0; j < width; j++)
              number(start + local + i * stride + j * size),
          ],
      ];
    }

    List<double> identity() => [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
    List<double> multiply(List<double> a, List<double> b) => [
      for (var column = 0; column < 4; column++)
        for (var row = 0; row < 4; row++)
          List.generate(
            4,
            (k) => a[k * 4 + row] * b[column * 4 + k],
          ).reduce((a, b) => a + b),
    ];
    final meshes = doc['meshes'] as List? ?? [],
        nodes = doc['nodes'] as List? ?? [];
    void mesh(int index, List<double> matrix) {
      if (index < 0 || index >= meshes.length) {
        throw const FormatException('Missing GLB mesh.');
      }
      for (final raw in (meshes[index] as Map)['primitives'] as List) {
        final p = raw as Map;
        if ((p['mode'] ?? 4) != 4) {
          notes.add('Non-triangle primitive omitted.');
          continue;
        }
        if ((p['extensions'] as Map?)?.containsKey(
              'KHR_draco_mesh_compression',
            ) ==
            true) {
          throw const FormatException(
            'Draco compression is unsupported. Export uncompressed GLB.',
          );
        }
        final coordinates = accessor(
          (p['attributes'] as Map)['POSITION'] as int,
          true,
        );
        final base = points.length;
        for (final v in coordinates) {
          final x = v[0].toDouble(), y = v[1].toDouble(), z = v[2].toDouble();
          vertex(
            matrix[0] * x + matrix[4] * y + matrix[8] * z + matrix[12],
            matrix[1] * x + matrix[5] * y + matrix[9] * z + matrix[13],
            matrix[2] * x + matrix[6] * y + matrix[10] * z + matrix[14],
          );
        }
        final indices = p['indices'] is int
            ? accessor(
                p['indices'] as int,
                false,
              ).map((v) => v.first.toInt()).toList()
            : List.generate(coordinates.length, (i) => i);
        if (indices.length % 3 != 0 ||
            indices.any((i) => i < 0 || i >= coordinates.length)) {
          throw const FormatException('Invalid GLB triangle indices.');
        }
        var color = 0xffa8b7d4;
        final materials = doc!['materials'] as List? ?? [];
        if (p['material'] is int &&
            p['material'] >= 0 &&
            p['material'] < materials.length) {
          final factor =
              ((materials[p['material']] as Map)['pbrMetallicRoughness']
                      as Map?)?['baseColorFactor']
                  as List?;
          if (factor != null && factor.length >= 3) {
            final rgb = factor
                .take(3)
                .map((n) => ((n as num).toDouble().clamp(0, 1) * 255).round())
                .toList();
            color = 0xff000000 | rgb[0] << 16 | rgb[1] << 8 | rgb[2];
          }
        }
        for (var i = 0; i < indices.length; i += 3) {
          face(
            base + indices[i],
            base + indices[i + 1],
            base + indices[i + 2],
            color,
          );
        }
      }
    }

    var visits = 0;
    void node(int index, List<double> parent, Set<int> ancestors) {
      if (index < 0 ||
          index >= nodes.length ||
          ancestors.contains(index) ||
          ancestors.length > 100 ||
          ++visits > 10000) {
        throw const FormatException(
          'Invalid or excessive GLB scene hierarchy.',
        );
      }
      final n = nodes[index] as Map;
      var local = identity();
      if (n['matrix'] is List) {
        local = (n['matrix'] as List)
            .map((n) => (n as num).toDouble())
            .toList();
      } else {
        final t = n['translation'] as List? ?? [0, 0, 0],
            s = n['scale'] as List? ?? [1, 1, 1],
            q = n['rotation'] as List? ?? [0, 0, 0, 1];
        final x = (q[0] as num).toDouble(),
            y = (q[1] as num).toDouble(),
            z = (q[2] as num).toDouble(),
            w = (q[3] as num).toDouble();
        local = [
          (1 - 2 * y * y - 2 * z * z) * s[0],
          (2 * x * y + 2 * w * z) * s[0],
          (2 * x * z - 2 * w * y) * s[0],
          0,
          (2 * x * y - 2 * w * z) * s[1],
          (1 - 2 * x * x - 2 * z * z) * s[1],
          (2 * y * z + 2 * w * x) * s[1],
          0,
          (2 * x * z + 2 * w * y) * s[2],
          (2 * y * z - 2 * w * x) * s[2],
          (1 - 2 * x * x - 2 * y * y) * s[2],
          0,
          t[0],
          t[1],
          t[2],
          1,
        ].map((n) => (n as num).toDouble()).toList();
      }
      if (local.length != 16 || local.any((v) => !v.isFinite)) {
        throw const FormatException('Invalid GLB transform.');
      }
      final transform = multiply(parent, local);
      if (n['mesh'] is int) mesh(n['mesh'] as int, transform);
      for (final child in n['children'] as List? ?? []) {
        node(child as int, transform, {...ancestors, index});
      }
    }

    final scenes = doc['scenes'] as List? ?? [];
    if (scenes.isNotEmpty) {
      final scene = doc['scene'] as int? ?? 0;
      if (scene < 0 || scene >= scenes.length) {
        throw const FormatException('Missing GLB scene.');
      }
      for (final root in (scenes[scene] as Map)['nodes'] as List? ?? []) {
        node(root as int, identity(), {});
      }
    } else if (nodes.isNotEmpty) {
      final children = {
        for (final n in nodes)
          for (final c in (n as Map)['children'] as List? ?? []) c,
      };
      for (var i = 0; i < nodes.length; i++) {
        if (!children.contains(i)) node(i, identity(), {});
      }
    } else {
      for (var i = 0; i < meshes.length; i++) {
        mesh(i, identity());
      }
    }
  } else {
    throw const FormatException('Supported previews: OBJ and GLB 2.');
  }
  if (points.isEmpty || faces.isEmpty) {
    throw const FormatException('No supported triangle geometry found.');
  }
  final minX = points.map((p) => p.x).reduce(math.min),
      maxX = points.map((p) => p.x).reduce(math.max);
  final minY = points.map((p) => p.y).reduce(math.min),
      maxY = points.map((p) => p.y).reduce(math.max);
  final minZ = points.map((p) => p.z).reduce(math.min),
      maxZ = points.map((p) => p.z).reduce(math.max);
  final extent = [maxX - minX, maxY - minY, maxZ - minZ].reduce(math.max);
  if (!extent.isFinite || extent <= 0) {
    throw const FormatException('Degenerate model bounds.');
  }
  return ModelAsset(
    [
      for (final p in points)
        MeshPoint(
          (p.x - (minX + (maxX - minX) / 2)) / extent,
          (p.y - (minY + (maxY - minY) / 2)) / extent,
          (p.z - (minZ + (maxZ - minZ) / 2)) / extent,
        ),
    ],
    faces,
    notes.toSet().toList(),
  );
}
