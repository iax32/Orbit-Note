import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/pdf_search.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/infrastructure/storage/native_object_index.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'native PDF cache survives restart and object rebuild and is disposable',
    () async {
      final folder = await Directory.systemTemp.createTemp('orbit-pdf-cache-');
      final index = DriftObjectIndex();
      const text = PdfTextDocument('Attachments/source.pdf', 'checksum', [
        'page one',
        'page two',
      ]);
      try {
        await index.initialize(folder.path);
        await index.writePdfText('pdf', text.toJson());
        await index.replaceAll([]);
        await index.close();
        await index.initialize(folder.path);
        expect(await index.readPdfText('pdf'), text.toJson());
        await index.removePdfText('pdf');
        expect(await index.readPdfText('pdf'), isNull);
        await index.writePdfText('pdf', text.toJson());
        await index.close();
        await File(p.join(folder.path, '.orbit', 'workspace.sqlite')).delete();
        await index.initialize(folder.path);
        expect(await index.readPdfText('pdf'), isNull);
      } finally {
        await index.close();
        await folder.delete(recursive: true);
      }
    },
  );

  test(
    'schema 3 upgrades without altering objects and malformed cache rebuilds',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'orbit-pdf-migrate-',
      );
      final index = DriftObjectIndex();
      try {
        await index.initialize(folder.path);
        final object = UniversalObject(
          id: 'note',
          workspaceId: 'w',
          typeId: 'orbit.note',
          title: 'needle',
          body: 'authored source',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          properties: {
            'unknown': {'keep': true},
          },
        );
        await index.upsert(object);
        await index.close();
        final db = sqlite3.open(
          p.join(folder.path, '.orbit', 'workspace.sqlite'),
        );
        db.execute('DROP TABLE pdf_text');
        db.execute('PRAGMA user_version=3');
        db.close();
        await index.initialize(folder.path);
        expect(await index.search('needle'), ['note']);
        await index.writePdfText(
          'pdf',
          const PdfTextDocument('Attachments/a.pdf', 'v1', ['needle']).toJson(),
        );
        await index.close();
        final corrupt = sqlite3.open(
          p.join(folder.path, '.orbit', 'workspace.sqlite'),
        );
        corrupt.execute("UPDATE pdf_text SET document='not json'");
        expect(
          corrupt
              .select("SELECT body FROM objects WHERE id='note'")
              .single['body'],
          'authored source',
        );
        expect(corrupt.userVersion, 4);
        corrupt.close();
        await index.initialize(folder.path);
        expect(await index.readPdfText('pdf'), isNull);
        expect(await index.search('needle'), ['note']);
      } finally {
        await index.close();
        await folder.delete(recursive: true);
      }
    },
  );

  test(
    'native substring candidates have no pre-filter 100-result cutoff',
    () async {
      final folder = await Directory.systemTemp.createTemp('orbit-search-all-');
      final index = DriftObjectIndex();
      try {
        await index.initialize(folder.path);
        await index.replaceAll([
          for (var i = 0; i < 160; i++)
            UniversalObject(
              id: 'note-$i',
              workspaceId: 'w',
              typeId: 'orbit.note',
              title: 'needle ${i.toString().padLeft(3, '0')}',
              body: 'x% quoted "text" a_b',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
        ]);
        for (final query in ['needle', 'x%', '"text"', 'a_b']) {
          expect(await index.search(query), hasLength(160), reason: query);
        }
        expect((await index.search('needle')).last, 'note-159');
      } finally {
        await index.close();
        await folder.delete(recursive: true);
      }
    },
  );
}
