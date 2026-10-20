import 'dart:async';
import '../domain/code_project.dart';
import '../domain/code_language.dart';

class CodeDocument {
  CodeDocument(this.base, {String? draft, this.conflict = false})
    : text = draft ?? base.text;
  CodeSnapshot base;
  String text;
  bool conflict;
  int version = 1;
  String? draftError;
  String get path => base.path;
  bool get modified => text != base.text;
  void edit(String value) {
    if (value != text) {
      text = value;
      version++;
    }
  }
}

/// File mutations and recovery are isolated from editor rendering.
class CodeProjectSession {
  CodeProjectSession(this.project);
  final CodeProject project;
  final documents = <String, CodeDocument>{};
  final _opening = <String, Future<CodeDocument>>{};
  final _saving = <String>{};
  bool disposed = false;
  Future<CodeDocument> open(String path) async {
    if (disposed) throw const FormatException('Code project is closed.');
    if (documents.containsKey(path)) return documents[path]!;
    if (_opening.containsKey(path)) return _opening[path]!;
    if (documents.length + _opening.length >= 20) {
      throw const FormatException('Keep up to 20 source files open.');
    }
    final future = () async {
      final file = await project.read(path);
      CodeRecoveredDraft? recovered;
      String? warning;
      try {
        recovered = await project.recoverDraft(path);
      } on Object {
        warning =
            'An unsupported recovery draft was left intact. Current source is open; inspect recovery state before discarding it.';
      }
      if (disposed) {
        throw const FormatException(
          'Code project closed while opening source.',
        );
      }
      final doc = CodeDocument(
        file,
        draft: recovered?.text != file.text ? recovered?.text : null,
        conflict:
            recovered != null &&
            recovered.text != file.text &&
            recovered.baseHash != file.hash,
      );
      documents[path] = doc;
      doc.draftError = warning;
      return doc;
    }();
    _opening[path] = future;
    try {
      return await future;
    } finally {
      _opening.remove(path);
    }
  }

  Future<void> protect(CodeDocument doc) async {
    if (disposed || documents[doc.path] != doc) return;
    try {
      if (doc.modified) {
        await project.writeDraft(doc.base, doc.text);
      } else {
        await project.clearDraft(doc.path);
      }
      doc.draftError = null;
    } on Object {
      doc.draftError =
          'Recovery draft could not be written. Save or copy this source before closing.';
      rethrow;
    }
  }

  Future<void> save(CodeDocument doc) async {
    if (disposed || documents[doc.path] != doc || _saving.contains(doc.path)) {
      throw const FormatException(
        'This source is unavailable or already saving.',
      );
    }
    if (doc.conflict) {
      throw const FormatException(
        'Compare the recovered draft with the current file before saving.',
      );
    }
    _saving.add(doc.path);
    final text = doc.text;
    try {
      final saved = await project.save(doc.base, text);
      doc.base = saved;
      await protect(doc);
      // A newer edit can arrive while draft deletion/writing is pending.
      if (doc.text != text) await protect(doc);
    } on Object {
      if (!disposed) {
        try {
          await project.writeDraft(doc.base, doc.text);
        } on Object {
          doc.draftError =
              'Neither source save nor recovery could complete. Copy your draft.';
        }
      }
      rethrow;
    } finally {
      _saving.remove(doc.path);
    }
  }

  Future<void> resolve(
    CodeDocument doc,
    CodeSnapshot current,
    String reviewed,
  ) async {
    if (disposed || documents[doc.path] != doc || current.path != doc.path) {
      throw const FormatException('Source context changed.');
    }
    doc.base = current;
    doc.edit(reviewed);
    doc.conflict = false;
    await protect(doc);
  }

  Future<void> closeDocument(CodeDocument doc) async {
    await protect(doc);
    documents.remove(doc.path);
  }

  Future<void> protectAll() async {
    for (final doc in documents.values.toList()) {
      await protect(doc);
    }
  }

  Future<void> dispose() async {
    await protectAll();
    disposed = true;
  }
}

String sourceStarter(String language) => switch (language) {
  'python' =>
    'def main():\n    print("Hello from Orbit Note")\n\n\nif __name__ == "__main__":\n    main()\n',
  'cpp' =>
    '#include <iostream>\n\nint main() {\n    std::cout << "Hello from Orbit Note\\n";\n    return 0;\n}\n',
  'html' => offlineCodeSuggestions('', 0, 'html').first.edits.single.text,
  _ => '',
};
